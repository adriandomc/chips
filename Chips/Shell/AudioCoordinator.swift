import ChipsAudioHost
import ChipsEngine
import Foundation

/// Coordinador del estado de audio compartido entre secciones.
/// Mantiene el `ChipsAudioHost` y el nodo `AdditiveSynth` que en M4 actúa
/// como instrumento principal.
@MainActor
final class AudioCoordinator {
    let host: ChipsAudioHost
    let synthNodeId: ChipsNodeId

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
    }

    func start() {
        try? host.start()
    }

    func stop() {
        host.stop()
    }

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
}
