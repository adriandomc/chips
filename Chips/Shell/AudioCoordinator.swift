import ChipsAudioHost
import ChipsCore
import ChipsEngine
import Foundation

/// Coordinador del estado de audio y transport. Mantiene el `ChipsAudioHost`,
/// el `AdditiveSynth` como instrumento principal, y un `SequencerEngine` que
/// dispara notas al synth cuando transport corre.
@MainActor
final class AudioCoordinator: SequencerEngineDelegate {
    let host: ChipsAudioHost
    let synthNodeId: ChipsNodeId
    let sequencer = SequencerEngine()

    /// Notificación de cambios de timecode (formatted "1.1.00").
    var onTimecodeChange: ((String) -> Void)?

    /// Notificación de cambios de tick para resaltado de playhead.
    var onTickChange: ((Int64) -> Void)?

    init() throws {
        host = try ChipsAudioHost(sampleRate: 48000, maxFrames: 1024)
        guard let node = host.engine.addNode(.additiveSynth) else {
            throw NSError(domain: "AudioCoordinator", code: 1)
        }
        host.engine.setOutputNode(node)
        guard host.engine.compile() else {
            throw NSError(domain: "AudioCoordinator", code: 2)
        }
        synthNodeId = node
        host.engine.setParameter(node, additive: .volume, value: 0.5)
        host.engine.setParameter(node, additive: .attack, value: 0.01)
        host.engine.setParameter(node, additive: .decay, value: 0.15)
        host.engine.setParameter(node, additive: .sustain, value: 0.7)
        host.engine.setParameter(node, additive: .release, value: 0.4)
        host.engine.setParameter(node, additive: .tilt, value: 0.5)
        sequencer.delegate = self
    }

    // MARK: Transport

    /// Arranca el host de audio (si no está activo) y el sequencer.
    func play() {
        try? host.start()
        sequencer.play()
    }

    /// Para el sequencer. El host de audio se queda activo (el synth puede sonar
    /// con el teclado en vivo aunque transport esté detenido).
    func stop() {
        sequencer.stop()
    }

    /// Para todo (sequencer + audio host).
    func stopAll() {
        sequencer.stop()
        host.stop()
    }

    func setTempo(_ bpm: Float) {
        sequencer.setTempo(bpm)
    }

    var transport: TransportState { sequencer.transport }

    // MARK: Synth control

    func setVolume(_ value: Float) {
        host.engine.setParameter(synthNodeId, additive: .volume, value: value)
    }

    func setAttack(_ seconds: Float) {
        host.engine.setParameter(synthNodeId, additive: .attack, value: seconds)
    }

    func setDecay(_ seconds: Float) {
        host.engine.setParameter(synthNodeId, additive: .decay, value: seconds)
    }

    func setSustain(_ level: Float) {
        host.engine.setParameter(synthNodeId, additive: .sustain, value: level)
    }

    func setRelease(_ seconds: Float) {
        host.engine.setParameter(synthNodeId, additive: .release, value: seconds)
    }

    func setTilt(_ tilt: Float) {
        host.engine.setParameter(synthNodeId, additive: .tilt, value: tilt)
    }

    func noteOn(_ midi: Int, velocity: Float = 1.0) {
        host.engine.sendNoteOn(synthNodeId, midi: midi, velocity: velocity)
    }

    func noteOff(_ midi: Int) {
        host.engine.sendNoteOff(synthNodeId, midi: midi)
    }

    // MARK: SequencerEngineDelegate

    func sequencer(noteOnFor _: Track, note: PatternNote) {
        noteOn(Int(note.midi), velocity: note.velocity)
    }

    func sequencer(noteOffFor _: Track, note: PatternNote) {
        noteOff(Int(note.midi))
    }

    func sequencer(positionDidChange tick: Int64) {
        onTickChange?(tick)
        onTimecodeChange?(sequencer.transport.formatted)
    }
}
