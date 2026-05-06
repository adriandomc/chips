import Foundation

/// Recibe eventos del sequencer. Las llamadas vienen del MainActor.
@MainActor
public protocol SequencerEngineDelegate: AnyObject {
    func sequencer(noteOnFor track: Track, note: PatternNote)
    func sequencer(noteOffFor track: Track, note: PatternNote)
    func sequencer(positionDidChange tick: Int64)
}

/// Motor de secuencia que avanza el transport en tiempo real (control thread,
/// no sample-accurate). Para M5 este nivel de precisión basta; M2.5/M5.5 puede
/// migrar el scheduling al audio thread vía SPSC.
@MainActor
public final class SequencerEngine {
    public private(set) var transport = TransportState()
    public private(set) var tracks: [Track] = []

    public weak var delegate: (any SequencerEngineDelegate)?

    private var timer: Timer?
    private var lastTickTime: TimeInterval = 0
    private var fractionalTicks: Double = 0
    private var heldNotes: [(Track, PatternNote)] = []

    public init() {}

    public func setTracks(_ tracks: [Track]) {
        self.tracks = tracks
    }

    public func updateTrack(_ track: Track) {
        if let idx = tracks.firstIndex(where: { $0.id == track.id }) {
            tracks[idx] = track
        }
    }

    public func setTempo(_ bpm: Float) {
        transport.tempoBpm = max(20, min(999, bpm))
    }

    public func play() {
        guard !transport.isPlaying else { return }
        transport.isPlaying = true
        lastTickTime = CACurrentMediaTime()
        fractionalTicks = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 100.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        transport.isPlaying = false
        // Apagar notas colgadas.
        for (track, note) in heldNotes {
            delegate?.sequencer(noteOffFor: track, note: note)
        }
        heldNotes.removeAll()
        transport.currentTick = 0
        delegate?.sequencer(positionDidChange: 0)
    }

    public func pause() {
        timer?.invalidate()
        timer = nil
        transport.isPlaying = false
    }

    private func tick() {
        let now = CACurrentMediaTime()
        let elapsed = now - lastTickTime
        lastTickTime = now

        let ticksAdvanced = elapsed / transport.tickSeconds + fractionalTicks
        let wholeTicks = Int64(ticksAdvanced.rounded(.down))
        fractionalTicks = ticksAdvanced - Double(wholeTicks)

        guard wholeTicks > 0 else { return }
        let prevTick = transport.currentTick
        let newTick = prevTick + wholeTicks

        // Para cada track, dispatch notas que iniciaron o terminaron en este intervalo.
        for track in tracks {
            for pattern in track.patterns {
                dispatchPattern(pattern: pattern, track: track, fromTick: prevTick, toTick: newTick)
            }
        }

        transport.currentTick = newTick
        delegate?.sequencer(positionDidChange: newTick)
    }

    private func dispatchPattern(pattern: Pattern, track: Track, fromTick: Int64, toTick: Int64) {
        let length = pattern.lengthTicks
        guard length > 0 else { return }
        // Ventana en coordenadas locales del pattern (loop infinito).
        let localFrom = fromTick % length
        let localTo = (toTick - 1) % length + 1

        if localTo > localFrom {
            applyWindow(pattern: pattern, track: track, from: localFrom, to: localTo)
        } else {
            // Wrap: dispatch hasta fin y luego desde 0.
            applyWindow(pattern: pattern, track: track, from: localFrom, to: length)
            applyWindow(pattern: pattern, track: track, from: 0, to: localTo)
        }
    }

    private func applyWindow(pattern: Pattern, track: Track, from: Int64, to: Int64) {
        for note in pattern.notesStarting(in: from, to: to) {
            heldNotes.append((track, note))
            delegate?.sequencer(noteOnFor: track, note: note)
        }
        for note in pattern.notesEnding(in: from, to: to) {
            heldNotes.removeAll { $0.1.id == note.id }
            delegate?.sequencer(noteOffFor: track, note: note)
        }
    }
}
