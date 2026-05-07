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
    /// para arrancar fresco desde la UI.
    static func defaultGraph() -> ProjectGraph {
        ProjectMigrator.migrateV1ToV2(ProjectSnapshot())
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

    func exportWav(to url: URL, seconds: Float) throws {
        sequencer.stop()
        host.stop()

        let sampleRate = 48000
        let totalFrames = Int(Float(sampleRate) * seconds)
        var samples = [Float](repeating: 0, count: totalFrames * 2)

        sequencer.play()
        try? host.start()

        samples.withUnsafeMutableBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            var offset = 0
            let blockSize = 1024
            while offset < totalFrames {
                let block = min(blockSize, totalFrames - offset)
                host.engine.render(into: base.advanced(by: offset * 2), frames: block)
                offset += block
            }
        }

        sequencer.stop()
        host.stop()
        try WavWriter.writeStereoPCM16(samples: samples, sampleRate: sampleRate, to: url)
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
