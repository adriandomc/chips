import ChipsAudioHost
import ChipsEngine
import Foundation

/// Coordinador del estado de audio compartido entre secciones.
/// Mantiene el `ChipsAudioHost`, expone el `sineNodeId` (M3 placeholder hasta
/// que tengamos el AdditiveSynth en M4) y maneja transport.
@MainActor
final class AudioCoordinator {
    let host: ChipsAudioHost
    let sineNodeId: ChipsNodeId

    init() throws {
        host = try ChipsAudioHost(sampleRate: 48000, maxFrames: 1024)
        guard let node = host.engine.addNode(.sine) else {
            throw NSError(domain: "AudioCoordinator", code: 1)
        }
        host.engine.setOutputNode(node)
        guard host.engine.compile() else {
            throw NSError(domain: "AudioCoordinator", code: 2)
        }
        sineNodeId = node
        host.engine.setParameter(node, sine: .frequency, value: 440)
        host.engine.setParameter(node, sine: .amplitude, value: 0.25)
        host.engine.setParameter(node, sine: .enabled, value: 0)
    }

    func start() {
        try? host.start()
    }

    func stop() {
        host.stop()
    }

    func setSineEnabled(_ enabled: Bool) {
        host.engine.setParameter(sineNodeId, sine: .enabled, value: enabled ? 1 : 0)
    }

    func setSineFrequency(_ hz: Float) {
        host.engine.setParameter(sineNodeId, sine: .frequency, value: hz)
    }

    func setSineAmplitude(_ a: Float) {
        host.engine.setParameter(sineNodeId, sine: .amplitude, value: a)
    }

    /// Convierte una nota MIDI a frecuencia (A4 = 69 = 440 Hz).
    static func frequency(forMidi midi: Int) -> Float {
        Float(440.0 * pow(2.0, Double(midi - 69) / 12.0))
    }
}
