import ChipsEngineCxx
import Foundation

public enum ChipsEngineError: Error {
    case creationFailed
}

/// Tipos de nodo registrados en el motor (string identifier estable).
public enum ChipsNodeType: String, Sendable {
    case sine
    case passthrough
    case testSource = "test_source"
}

public typealias ChipsNodeId = UInt32

public let chipsInvalidNodeId: ChipsNodeId = 0

/// Identificadores de parámetros del módulo `Sine` (ver `SineGenerator::Param`).
public enum SineParam: UInt32 {
    case frequency = 0
    case enabled = 1
    case amplitude = 2
}

/// Facade Swift sobre el motor DSP en C++ con grafo dinámico.
///
/// Sincronización: el grafo es seguro para mutar desde control thread
/// (control plane Swift) y leer desde audio thread (vía `render`). La
/// publicación entre threads es lock-free (atomic pointer swap del Plan).
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
    /// - Important: invocar **solo desde el audio thread**.
    public func render(into buffer: UnsafeMutablePointer<Float>, frames: Int) {
        chips_engine_render(handle, buffer, Int32(frames))
    }

    public var sampleRate: Double {
        chips_engine_sample_rate(handle)
    }

    public var dspLoad: Float {
        chips_engine_dsp_load(handle)
    }

    public static var version: String {
        String(cString: chips_engine_version())
    }

    // MARK: Grafo

    /// Añade un nodo del tipo dado y devuelve su ID. nil si el tipo es desconocido.
    public func addNode(_ type: ChipsNodeType) -> ChipsNodeId? {
        let id = type.rawValue.withCString { chips_engine_add_node(handle, $0) }
        return id == chipsInvalidNodeId ? nil : id
    }

    @discardableResult
    public func removeNode(_ id: ChipsNodeId) -> Bool {
        chips_engine_remove_node(handle, id)
    }

    @discardableResult
    public func connect(
        _ src: ChipsNodeId, port srcPort: Int,
        to dst: ChipsNodeId, port dstPort: Int
    ) -> Bool {
        chips_engine_connect(handle, src, Int32(srcPort), dst, Int32(dstPort))
    }

    @discardableResult
    public func disconnect(
        _ src: ChipsNodeId, port srcPort: Int,
        from dst: ChipsNodeId, port dstPort: Int
    ) -> Bool {
        chips_engine_disconnect(handle, src, Int32(srcPort), dst, Int32(dstPort))
    }

    public func setOutputNode(_ id: ChipsNodeId) {
        chips_engine_set_output_node(handle, id)
    }

    @discardableResult
    public func compile() -> Bool {
        chips_engine_compile(handle)
    }

    /// Encola un cambio de parámetro RT-safe (vía SPSC). Devuelve false si la
    /// cola está llena.
    @discardableResult
    public func setParameter(_ id: ChipsNodeId, paramId: UInt32, value: Float) -> Bool {
        chips_engine_set_parameter(handle, id, paramId, value)
    }

    /// Conveniencia: setParameter usando un enum tipado.
    @discardableResult
    public func setParameter(_ id: ChipsNodeId, sine param: SineParam, value: Float) -> Bool {
        setParameter(id, paramId: param.rawValue, value: value)
    }
}
