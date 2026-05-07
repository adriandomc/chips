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

    /// Estado serializable del coordinator. Se actualiza en cada setter para
    /// poder snapshot-ear sin necesidad de leer del engine C++.
    private(set) var lastSynthSettings = SynthSettings()
    private(set) var lastMixerSettings: [MixerChannelSettings] = .defaultBank
    private(set) var lastDelaySettings = DelaySettings()
    private(set) var lastReverbSettings = ReverbSettings()

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

    // MARK: Persistencia

    /// Captura el estado actual del coordinator como un `ProjectSnapshot`.
    func captureSnapshot(name: String, author: String) -> ProjectSnapshot {
        let synth = SynthSettings(
            volume: lastSynthSettings.volume,
            attack: lastSynthSettings.attack,
            decay: lastSynthSettings.decay,
            sustain: lastSynthSettings.sustain,
            release: lastSynthSettings.release,
            tilt: lastSynthSettings.tilt
        )
        return ProjectSnapshot(
            name: name,
            author: author,
            tempoBpm: sequencer.transport.tempoBpm,
            tracks: sequencer.tracks,
            synth: synth,
            mixerChannels: lastMixerSettings,
            delay: lastDelaySettings,
            reverb: lastReverbSettings
        )
    }

    /// Aplica un snapshot al estado del engine y al sequencer.
    func apply(snapshot: ProjectSnapshot) {
        setTempo(snapshot.tempoBpm)
        sequencer.setTracks(snapshot.tracks)

        setVolume(snapshot.synth.volume)
        setAttack(snapshot.synth.attack)
        setDecay(snapshot.synth.decay)
        setSustain(snapshot.synth.sustain)
        setRelease(snapshot.synth.release)
        setTilt(snapshot.synth.tilt)

        for (index, channel) in snapshot.mixerChannels.enumerated() {
            setMixerGain(channel: index, gain: channel.gain)
            setMixerPan(channel: index, pan: channel.pan)
            setMixerMuted(channel: index, muted: channel.muted)
        }

        host.engine.setParameter(delayNodeId, delay: .time, value: snapshot.delay.timeSeconds)
        host.engine.setParameter(delayNodeId, delay: .feedback, value: snapshot.delay.feedback)
        host.engine.setParameter(delayNodeId, delay: .wet, value: snapshot.delay.wet)

        host.engine.setParameter(reverbNodeId, reverb: .roomSize, value: snapshot.reverb.roomSize)
        host.engine.setParameter(reverbNodeId, reverb: .damping, value: snapshot.reverb.damping)
        host.engine.setParameter(reverbNodeId, reverb: .wet, value: snapshot.reverb.wet)
    }

    /// Render offline a WAV. Detiene cualquier reproducción activa, renderiza
    /// `seconds` de audio (con el sequencer corriendo silenciosamente para
    /// disparar las notas), y escribe el resultado al `url` indicado.
    func exportWav(to url: URL, seconds: Float) throws {
        sequencer.stop()
        host.stop()

        let sampleRate = 48000
        let totalFrames = Int(Float(sampleRate) * seconds)
        var samples = [Float](repeating: 0, count: totalFrames * 2)
        let blockSize = 1024

        // Para offline render necesitamos avanzar el sequencer manualmente
        // porque su timer real-time está parado. M7 limitación: solo exportamos
        // el output silencioso del engine sin disparar notas. Una cadena de
        // bounce con timeline real llega en M7.5+.
        // Por ahora, dejamos al sequencer correr en tiempo real y muestreamos
        // el engine — lo que se obtiene es lo que esté produciendo "ahora mismo".
        sequencer.play()
        try? host.start()

        samples.withUnsafeMutableBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            var offset = 0
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

    // MARK: Synth

    func setVolume(_ value: Float) {
        lastSynthSettings.volume = value
        host.engine.setParameter(synthNodeId, additive: .volume, value: value)
    }

    func setAttack(_ seconds: Float) {
        lastSynthSettings.attack = seconds
        host.engine.setParameter(synthNodeId, additive: .attack, value: seconds)
    }

    func setDecay(_ seconds: Float) {
        lastSynthSettings.decay = seconds
        host.engine.setParameter(synthNodeId, additive: .decay, value: seconds)
    }

    func setSustain(_ level: Float) {
        lastSynthSettings.sustain = level
        host.engine.setParameter(synthNodeId, additive: .sustain, value: level)
    }

    func setRelease(_ seconds: Float) {
        lastSynthSettings.release = seconds
        host.engine.setParameter(synthNodeId, additive: .release, value: seconds)
    }

    func setTilt(_ tilt: Float) {
        lastSynthSettings.tilt = tilt
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
        ensureMixerSettings(forChannel: channel)
        lastMixerSettings[channel].gain = gain
        host.engine.setMixerParameter(mixerNodeId, channel: channel, kind: .gain, value: gain)
    }

    func setMixerPan(channel: Int, pan: Float) {
        ensureMixerSettings(forChannel: channel)
        lastMixerSettings[channel].pan = pan
        host.engine.setMixerParameter(mixerNodeId, channel: channel, kind: .pan, value: pan)
    }

    func setMixerMuted(channel: Int, muted: Bool) {
        ensureMixerSettings(forChannel: channel)
        lastMixerSettings[channel].muted = muted
        host.engine.setMixerParameter(mixerNodeId, channel: channel, kind: .mute, value: muted ? 1 : 0)
    }

    private func ensureMixerSettings(forChannel channel: Int) {
        while lastMixerSettings.count <= channel {
            lastMixerSettings.append(MixerChannelSettings())
        }
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
