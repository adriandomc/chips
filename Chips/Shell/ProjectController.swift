import ChipsAudioHost
import ChipsCore
import ChipsEngine
import Foundation

enum ProjectControllerError: Error {
    case unknownNodeType(String)
    case compileFailed
}

/// `ProjectController` reemplaza al `AudioCoordinator` rígido de M0-M7.
///
/// Mantiene un `ProjectGraph` como single source of truth y reconstruye el
/// motor C++ desde él. Los `NodeRef` (UUID estables, parte del grafo) se
/// mapean a `ChipsNodeId` (UInt32 efímeros, asignados por `Graph::addNode`).
///
/// API plug-and-play:
/// - Para añadir un instrumento: `addNode(typeId: "beatbox")`. Sin tocar el
///   coordinator ni el snapshot.
/// - Para enrutar un track a un instrumento: `track.instrumentRef = ref`.
/// - Persistencia: `currentGraph()` produce un snapshot serializable;
///   `apply(graph:)` reconstruye todo desde uno cargado (incluida migración v1).
@MainActor
final class ProjectController: SequencerEngineDelegate {
    let host: ChipsAudioHost
    let sequencer = SequencerEngine()
    private(set) var graph: ProjectGraph
    private var nodeIds: [NodeRef: ChipsNodeId] = [:]

    var onTimecodeChange: ((String) -> Void)?
    var onTickChange: ((Int64) -> Void)?

    init(graph: ProjectGraph) throws {
        host = try ChipsAudioHost(sampleRate: 48000, maxFrames: 1024)
        self.graph = graph
        try rebuildEngineFromGraph()
        sequencer.delegate = self
        sequencer.setTracks(graph.tracks)
        sequencer.setTempo(graph.tempoBpm)
    }

    /// Default graph: la cadena heredada synth → mixer → delay → reverb. Útil
    /// para arrancar fresco desde la UI. Incluye un track con un pattern
    /// seed (una escala de C mayor en 8 notas) ruteado al synth — así, al
    /// pulsar Play en el primer launch, el usuario oye algo de inmediato.
    static func defaultGraph() -> ProjectGraph {
        var graph = ProjectMigrator.migrateV1ToV2(ProjectSnapshot())
        if graph.tracks.isEmpty, let synthRef = graph.nodes.first(where: { $0.typeId == "additive_synth" })?.id {
            graph.tracks = [Self.makeSeedTrack(instrumentRef: synthRef)]
        }
        return graph
    }

    /// Track de demostración: 1 bar (1920 ticks @ PPQ=480) con C mayor
    /// ascendente en 8 corcheas. Velocity 1.0. La idea: dar al usuario algo
    /// audible al pulsar Play sin obligarle a dibujar notas primero.
    private static func makeSeedTrack(instrumentRef: NodeRef) -> Track {
        let ppq = Int64(ChipsCore.ppq)
        let stepTicks = ppq / 2 // corchea
        let lengthTicks = stepTicks - (stepTicks / 12) // pequeño gap rítmico
        let scale: [UInt8] = [60, 62, 64, 65, 67, 69, 71, 72]
        let notes: [PatternNote] = scale.enumerated().map { index, midi in
            PatternNote(
                startTick: Int64(index) * stepTicks,
                lengthTicks: lengthTicks,
                midi: midi,
                velocity: 0.85
            )
        }
        let pattern = Pattern(name: "Demo", lengthTicks: ppq * 4, notes: notes)
        return Track(name: "Lead", colorIndex: 0, patterns: [pattern], instrumentRef: instrumentRef)
    }

    // MARK: Reconstrucción del motor

    private func rebuildEngineFromGraph() throws {
        for (_, chipsId) in nodeIds {
            host.engine.removeNode(chipsId)
        }
        nodeIds.removeAll(keepingCapacity: true)

        for node in graph.nodes {
            guard let chipsId = host.engine.addNode(typeId: node.typeId) else {
                throw ProjectControllerError.unknownNodeType(node.typeId)
            }
            nodeIds[node.id] = chipsId
        }

        for connection in graph.connections {
            guard let src = nodeIds[connection.src], let dst = nodeIds[connection.dst] else {
                continue
            }
            host.engine.connect(src, port: connection.srcPort, to: dst, port: connection.dstPort)
        }

        if let outputRef = graph.outputNodeRef, let outputId = nodeIds[outputRef] {
            host.engine.setOutputNode(outputId)
        }

        guard host.engine.compile() else {
            throw ProjectControllerError.compileFailed
        }

        for node in graph.nodes {
            guard let chipsId = nodeIds[node.id] else { continue }
            applyParameters(of: node, to: chipsId)
        }
    }

    private func applyParameters(of node: NodeInstance, to chipsId: ChipsNodeId) {
        let specs = host.engine.parameterSpecs(of: chipsId)
        let specByName: [String: ParameterSpec] = Dictionary(uniqueKeysWithValues: specs.map { ($0.name, $0) })
        for (name, value) in node.parameters {
            if let spec = specByName[name] {
                host.engine.setParameter(chipsId, paramId: spec.paramId, value: value)
            }
        }
    }

    // MARK: Edición del grafo

    @discardableResult
    func addNode(typeId: String, displayName: String? = nil) throws -> NodeRef {
        let ref = UUID()
        graph.nodes.append(NodeInstance(id: ref, typeId: typeId, displayName: displayName ?? typeId))
        try rebuildEngineFromGraph()
        return ref
    }

    func removeNode(_ ref: NodeRef) throws {
        graph.nodes.removeAll { $0.id == ref }
        graph.connections.removeAll { $0.src == ref || $0.dst == ref }
        if graph.outputNodeRef == ref {
            graph.outputNodeRef = nil
        }
        try rebuildEngineFromGraph()
    }

    func chipsNodeId(for ref: NodeRef) -> ChipsNodeId? {
        nodeIds[ref]
    }

    /// Cambia un parámetro por nombre (busca el `ParamSpec`), actualiza el
    /// engine y persiste el cambio en el `graph` para futuros snapshots.
    func setParameter(of ref: NodeRef, paramName: String, value: Float) {
        guard let chipsId = nodeIds[ref] else { return }
        let specs = host.engine.parameterSpecs(of: chipsId)
        guard let spec = specs.first(where: { $0.name == paramName }) else { return }
        host.engine.setParameter(chipsId, paramId: spec.paramId, value: value)
        if let nodeIdx = graph.nodes.firstIndex(where: { $0.id == ref }) {
            graph.nodes[nodeIdx].parameters[paramName] = value
        }
    }

    func sendNoteOn(_ ref: NodeRef, midi: Int, velocity: Float = 1.0) {
        guard let chipsId = nodeIds[ref] else { return }
        host.engine.sendNoteOn(chipsId, midi: midi, velocity: velocity)
    }

    func sendNoteOff(_ ref: NodeRef, midi: Int) {
        guard let chipsId = nodeIds[ref] else { return }
        host.engine.sendNoteOff(chipsId, midi: midi)
    }

    // MARK: Conveniencia (R3 — la UI todavía mira nodos por tipo conocido;

    // R4 introduce browser/registry-driven UI que no necesita estos accessors)

    var synthRef: NodeRef? {
        graph.nodes.first { $0.typeId == "additive_synth" }?.id
    }

    var mixerRef: NodeRef? {
        graph.nodes.first { $0.typeId == "mixer" }?.id
    }

    var delayRef: NodeRef? {
        graph.nodes.first { $0.typeId == "delay" }?.id
    }

    var reverbRef: NodeRef? {
        graph.nodes.first { $0.typeId == "reverb" }?.id
    }

    func parameter(of ref: NodeRef, name: String) -> Float? {
        graph.node(withRef: ref)?.parameters[name]
    }

    // MARK: Tracks (sequencer)

    func setTracks(_ tracks: [Track]) {
        graph.tracks = tracks
        sequencer.setTracks(tracks)
    }

    func updateTrack(_ track: Track) {
        if let index = graph.tracks.firstIndex(where: { $0.id == track.id }) {
            graph.tracks[index] = track
        }
        sequencer.updateTrack(track)
    }

    // MARK: Transport

    func play() {
        try? host.start()
        sequencer.play()
    }

    func stop() {
        sequencer.stop()
    }

    func stopAll() {
        sequencer.stop()
        host.stop()
    }

    func setTempo(_ bpm: Float) {
        graph.tempoBpm = bpm
        sequencer.setTempo(bpm)
    }

    var transport: TransportState {
        sequencer.transport
    }

    // MARK: Persistencia

    /// Snapshot serializable del estado actual.
    func currentGraph(name: String? = nil, author: String? = nil) -> ProjectGraph {
        var snapshot = graph
        if let name { snapshot.name = name }
        if let author { snapshot.author = author }
        snapshot.tracks = sequencer.tracks
        snapshot.tempoBpm = sequencer.transport.tempoBpm
        return snapshot
    }

    /// Aplica un grafo cargado de disco (auto-migración v1 → v2 vía
    /// `ProjectStorage.decodeProject`).
    func apply(graph: ProjectGraph) throws {
        self.graph = graph
        try rebuildEngineFromGraph()
        sequencer.setTracks(graph.tracks)
        sequencer.setTempo(graph.tempoBpm)
    }

    // MARK: Export WAV

    /// Render offline (faster-than-realtime). Construye un `ChipsEngine` propio
    /// que replica `graph`, pre-genera todos los eventos del sequencer en el
    /// rango y los despacha con `frameOffset` sample-accurate. No toca el host
    /// live — el usuario puede seguir reproduciendo en paralelo si quisiera.
    func exportWav(to url: URL, seconds: Float) throws {
        let samples = renderOffline(seconds: seconds, includeTrackId: nil)
        try WavWriter.writeStereoPCM16(samples: samples, sampleRate: 48000, to: url)
    }

    /// M7.5: stems. Renderiza una WAV por track (cada una con todos los efectos
    /// del proyecto aplicados). Devuelve la lista de URLs creadas.
    @discardableResult
    func exportStems(directoryURL: URL, baseName: String, seconds: Float) throws -> [URL] {
        var urls: [URL] = []
        for (index, track) in sequencer.tracks.enumerated() {
            let safeTrackName = track.name.replacingOccurrences(of: "/", with: "_")
            let fileName = "\(baseName) - \(index + 1) \(safeTrackName).wav"
            let stemURL = directoryURL.appendingPathComponent(fileName)
            let samples = renderOffline(seconds: seconds, includeTrackId: track.id)
            try WavWriter.writeStereoPCM16(samples: samples, sampleRate: 48000, to: stemURL)
            urls.append(stemURL)
        }
        return urls
    }

    private func renderOffline(seconds: Float, includeTrackId: UUID?) -> [Float] {
        let sampleRate = 48000
        let totalFrames = Int(Float(sampleRate) * seconds)
        let blockSize = 1024
        let ppq = ChipsCore.ppq
        let tempoBpm = max(20, sequencer.transport.tempoBpm)
        let secondsPerTick = 60.0 / Double(tempoBpm) / Double(ppq)
        let samplesPerTick = Double(sampleRate) * secondsPerTick

        guard let offlineEngine = try? ChipsEngine(sampleRate: Double(sampleRate), maxFrames: blockSize) else {
            return [Float](repeating: 0, count: totalFrames * 2)
        }
        var localIds: [NodeRef: ChipsNodeId] = [:]
        for node in graph.nodes {
            if let id = offlineEngine.addNode(typeId: node.typeId) {
                localIds[node.id] = id
            }
        }
        for connection in graph.connections {
            guard let src = localIds[connection.src], let dst = localIds[connection.dst] else { continue }
            offlineEngine.connect(src, port: connection.srcPort, to: dst, port: connection.dstPort)
        }
        if let outRef = graph.outputNodeRef, let outId = localIds[outRef] {
            offlineEngine.setOutputNode(outId)
        }
        guard offlineEngine.compile() else {
            return [Float](repeating: 0, count: totalFrames * 2)
        }
        for node in graph.nodes {
            guard let chipsId = localIds[node.id] else { continue }
            let specs = offlineEngine.parameterSpecs(of: chipsId)
            let byName = Dictionary(uniqueKeysWithValues: specs.map { ($0.name, $0) })
            for (paramName, value) in node.parameters {
                if let spec = byName[paramName] {
                    offlineEngine.setParameter(chipsId, paramId: spec.paramId, value: value)
                }
            }
        }

        let activeTracks: [Track] = {
            if let id = includeTrackId {
                return sequencer.tracks.filter { $0.id == id }
            } else {
                return sequencer.tracks
            }
        }()

        struct OfflineEvent {
            let absTick: Int64
            let isOn: Bool
            let chipsId: ChipsNodeId
            let midi: Int
            let velocity: Float
        }
        let maxTicks = Int64(ceil(Double(totalFrames) / samplesPerTick)) + 1
        var events: [OfflineEvent] = []
        for track in activeTracks {
            guard let ref = track.instrumentRef, let chipsId = localIds[ref] else { continue }
            for pattern in track.patterns where pattern.lengthTicks > 0 {
                var loopBase: Int64 = 0
                while loopBase < maxTicks {
                    for note in pattern.notes {
                        let absStart = loopBase + note.startTick
                        if absStart < maxTicks {
                            events.append(OfflineEvent(absTick: absStart, isOn: true,
                                                       chipsId: chipsId, midi: Int(note.midi), velocity: note.velocity))
                        }
                        let absEnd = absStart + note.lengthTicks
                        if absEnd < maxTicks {
                            events.append(OfflineEvent(absTick: absEnd, isOn: false,
                                                       chipsId: chipsId, midi: Int(note.midi), velocity: 0))
                        }
                    }
                    loopBase += pattern.lengthTicks
                }
            }
        }
        // Note-off antes de note-on en el mismo tick para clean voice stealing.
        events.sort { lhs, rhs in
            if lhs.absTick != rhs.absTick { return lhs.absTick < rhs.absTick }
            return (lhs.isOn ? 1 : 0) < (rhs.isOn ? 1 : 0)
        }

        var samples = [Float](repeating: 0, count: totalFrames * 2)
        samples.withUnsafeMutableBufferPointer { buf in
            guard let base = buf.baseAddress else { return }
            var sampleCursor = 0
            var eventIdx = 0
            while sampleCursor < totalFrames {
                let block = min(blockSize, totalFrames - sampleCursor)
                let blockEnd = sampleCursor + block
                while eventIdx < events.count {
                    let event = events[eventIdx]
                    let eventSample = Int(Double(event.absTick) * samplesPerTick)
                    if eventSample >= blockEnd { break }
                    let frameOffset = UInt32(max(0, eventSample - sampleCursor))
                    if event.isOn {
                        offlineEngine.sendNoteOn(event.chipsId, midi: event.midi, velocity: event.velocity,
                                                 frameOffset: frameOffset)
                    } else {
                        offlineEngine.sendNoteOff(event.chipsId, midi: event.midi, frameOffset: frameOffset)
                    }
                    eventIdx += 1
                }
                offlineEngine.render(into: base.advanced(by: sampleCursor * 2), frames: block)
                sampleCursor = blockEnd
            }
        }
        return samples
    }

    // MARK: SequencerEngineDelegate

    func sequencer(noteOnFor track: Track, note: PatternNote) {
        guard let ref = track.instrumentRef, let chipsId = nodeIds[ref] else { return }
        host.engine.sendNoteOn(chipsId, midi: Int(note.midi), velocity: note.velocity)
    }

    func sequencer(noteOffFor track: Track, note: PatternNote) {
        guard let ref = track.instrumentRef, let chipsId = nodeIds[ref] else { return }
        host.engine.sendNoteOff(chipsId, midi: Int(note.midi))
    }

    func sequencer(positionDidChange tick: Int64) {
        onTickChange?(tick)
        onTimecodeChange?(sequencer.transport.formatted)
    }
}
