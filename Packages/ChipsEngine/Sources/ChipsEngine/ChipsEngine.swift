import ChipsEngineCxx
import Foundation

public enum ChipsEngineError: Error {
    case creationFailed
}

/// Facade Swift sobre el motor DSP en C++.
/// El handle subyacente NO es Sendable: solo el audio thread puede tocarlo durante render.
public final class ChipsEngine {
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

    /// Renderiza `frames` muestras en el buffer stereo intercalado.
    /// - Important: solo debe invocarse desde el audio thread (render callback).
    public func render(into buffer: UnsafeMutablePointer<Float>, frames: Int) {
        chips_engine_render(handle, buffer, Int32(frames))
    }

    public static var version: String {
        String(cString: chips_engine_version())
    }
}
