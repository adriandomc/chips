import ChipsAudioHost
import ChipsCore
import ChipsEngine
import Foundation

/// Coordinador del estado de audio + transport. Construye el grafo:
/// `AdditiveSynth → Mixer (ch0) → Delay → Reverb → output`.
@MainActor
final class AudioCoordinator: SequencerEngineDelegate {
    let host: ChipsAudioHost
    let synthNodeId: ChipsNodeId
    let mixerNodeId: ChipsNodeId
    let delayNodeId: ChipsNodeId
    let reverbNodeId: ChipsNodeId
    let sequencer = SequencerEngine()

    var onTimecodeChange: ((String) -> Void)?
    var onTickChange: ((Int64) -> Void)?

    init() throws {
        host = try ChipsAudioHost(sampleRate: 48000, maxFrames: 1024)
        let engine = host.engine

        guard let synth = engine.addNode(.additiveSynth),
              let mixer = engine.addNode(.mixer),
              let delay = engine.addNode(.delay),
              let reverb = engine.addNode(.reverb)
        else {
            throw NSError(domain: "AudioCoordinator", code: 1)
        }
        synthNodeId = synth
        mixerNodeId = mixer
        delayNodeId = delay
        reverbNodeId = reverb

        // synth (stereo) → mixer ch0 (inputs 0 y 1)
        engine.connect(synth, port: 0, to: mixer, port: 0)
        engine.connect(synth, port: 1, to: mixer, port: 1)

        // mixer master → delay → reverb → output
        engine.connect(mixer, port: 0, to: delay, port: 0)
        engine.connect(mixer, port: 1, to: delay, port: 1)
        engine.connect(delay, port: 0, to: reverb, port: 0)
        engine.connect(delay, port: 1, to: reverb, port: 1)
        engine.setOutputNode(reverb)

        guard engine.compile() else {
            throw NSError(domain: "AudioCoordinator", code: 2)
        }

        // Defaults musicales.
        engine.setParameter(synth, additive: .volume, value: 0.5)
        engine.setParameter(synth, additive: .attack, value: 0.01)
        engine.setParameter(synth, additive: .decay, value: 0.15)
        engine.setParameter(synth, additive: .sustain, value: 0.7)
        engine.setParameter(synth, additive: .release, value: 0.4)
        engine.setParameter(synth, additive: .tilt, value: 0.5)

        engine.setMixerParameter(mixer, channel: 0, kind: .gain, value: 0.8)
        engine.setMixerParameter(mixer, channel: 0, kind: .pan, value: 0.0)

        engine.setParameter(delay, delay: .time, value: 0.35)
        engine.setParameter(delay, delay: .feedback, value: 0.35)
        engine.setParameter(delay, delay: .wet, value: 0.20)

        engine.setParameter(reverb, reverb: .roomSize, value: 0.7)
        engine.setParameter(reverb, reverb: .damping, value: 0.3)
        engine.setParameter(reverb, reverb: .wet, value: 0.20)

        sequencer.delegate = self
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
        sequencer.setTempo(bpm)
    }

    var transport: TransportState {
        sequencer.transport
    }

    // MARK: Synth

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

    // MARK: Mixer

    func setMixerGain(channel: Int, gain: Float) {
        host.engine.setMixerParameter(mixerNodeId, channel: channel, kind: .gain, value: gain)
    }

    func setMixerPan(channel: Int, pan: Float) {
        host.engine.setMixerParameter(mixerNodeId, channel: channel, kind: .pan, value: pan)
    }

    func setMixerMuted(channel: Int, muted: Bool) {
        host.engine.setMixerParameter(mixerNodeId, channel: channel, kind: .mute, value: muted ? 1 : 0)
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
