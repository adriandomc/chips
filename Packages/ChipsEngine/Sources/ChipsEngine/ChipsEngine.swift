import ChipsEngineCxx
import Foundation

public enum ChipsEngineError: Error {
    case creationFailed
}

/// Facade Swift sobre el motor DSP en C++.
///
/// El handle subyacente es seguro para tocar desde el audio thread (vía `render`)
/// y desde threads de control (vía setters). La sincronización se maneja con
/// atómicos en el código C++. Por eso se marca `@unchecked Sendable`.
public final class ChipsEngine: @unchecked Sendable {
    private let handle: OpaquePointer

    public init(sampleRate: Double, maxFrames: Int) throws {
        guard let raw = chips_engine_create(sampleRate, Int32(maxFrames)) else {
            throw ChipsEngineError.creationFailed
        }
        handle = raw
    }

    deinit {
        chips_engine_destroy(handle)
    }

    /// Renderiza `frames` muestras stereo intercaladas (L,R,L,R,...) en `buffer`.
    /// - Important: invocar **solo desde el audio thread** (render callback).
    public func render(into buffer: UnsafeMutablePointer<Float>, frames: Int) {
        chips_engine_render(handle, buffer, Int32(frames))
    }

    public var sampleRate: Double {
        chips_engine_sample_rate(handle)
    }

    /// Carga DSP suavizada (0.0 = idle, 1.0 = saturado).
    public var dspLoad: Float {
        chips_engine_dsp_load(handle)
    }

    // MARK: Generador de prueba (M1)

    public func setSineFrequency(_ hz: Float) {
        chips_engine_set_sine_frequency(handle, hz)
    }

    public func setSineEnabled(_ enabled: Bool) {
        chips_engine_set_sine_enabled(handle, enabled)
    }

    public var isSineEnabled: Bool {
        chips_engine_is_sine_enabled(handle)
    }

    public static var version: String {
        String(cString: chips_engine_version())
    }
}
