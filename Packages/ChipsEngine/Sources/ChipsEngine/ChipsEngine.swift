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
    case additiveSynth = "additive_synth"
    case mixer
    case delay
    case reverb
}

public typealias ChipsNodeId = UInt32

public let chipsInvalidNodeId: ChipsNodeId = 0

/// Identificadores de parámetros del módulo `Sine` (ver `SineGenerator::Param`).
public enum SineParam: UInt32 {
    case frequency = 0
    case enabled = 1
    case amplitude = 2
}

/// Parámetros del `AdditiveSynth` (ver `AdditiveSynth::Param`).
public enum AdditiveSynthParam: UInt32 {
    case volume = 0
    case attack = 1
    case decay = 2
    case sustain = 3
    case release = 4
    case tilt = 5
}

/// Parámetros del `Delay`.
public enum DelayParam: UInt32 {
    case time = 0
    case feedback = 1
    case wet = 2
}

/// Parámetros del `Reverb`.
public enum ReverbParam: UInt32 {
    case roomSize = 0
    case damping = 1
    case wet = 2
}

/// Parámetros del `Mixer`. El paramId combina canal y kind:
/// `(channel << 8) | kind`. Helpers en `ChipsEngine.setMixer*`.
public enum MixerParamKind: UInt32 {
    case gain = 0
    case pan = 1
    case mute = 2
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

    /// Conveniencia: setParameter para el AdditiveSynth.
    @discardableResult
    public func setParameter(_ id: ChipsNodeId, additive param: AdditiveSynthParam, value: Float) -> Bool {
        setParameter(id, paramId: param.rawValue, value: value)
    }

    @discardableResult
    public func setParameter(_ id: ChipsNodeId, delay param: DelayParam, value: Float) -> Bool {
        setParameter(id, paramId: param.rawValue, value: value)
    }

    @discardableResult
    public func setParameter(_ id: ChipsNodeId, reverb param: ReverbParam, value: Float) -> Bool {
        setParameter(id, paramId: param.rawValue, value: value)
    }

    /// Mixer: setParameter dirigido a un canal específico.
    @discardableResult
    public func setMixerParameter(
        _ id: ChipsNodeId,
        channel: Int,
        kind: MixerParamKind,
        value: Float
    ) -> Bool {
        let paramId = (UInt32(channel) << 8) | kind.rawValue
        return setParameter(id, paramId: paramId, value: value)
    }

    @discardableResult
    public func sendNoteOn(_ id: ChipsNodeId, midi: Int, velocity: Float) -> Bool {
        chips_engine_send_note_on(handle, id, Int32(midi), velocity)
    }

    @discardableResult
    public func sendNoteOff(_ id: ChipsNodeId, midi: Int) -> Bool {
        chips_engine_send_note_off(handle, id, Int32(midi))
    }

    // MARK: Introspección

    /// Lista de typeIds registrados en el motor en el momento de creación.
    /// Capturada al construir el `ChipsEngine`; estable durante su vida.
    public var registeredTypes: [String] {
        let count = chips_engine_registered_type_count(handle)
        var result: [String] = []
        result.reserveCapacity(Int(count))
        for index in 0 ..< count {
            if let raw = chips_engine_registered_type_at(handle, index) {
                result.append(String(cString: raw))
            }
        }
        return result
    }

    /// Devuelve el typeId del nodo (igual al usado al crearlo). nil si no existe.
    public func nodeTypeId(_ id: ChipsNodeId) -> String? {
        guard let raw = chips_engine_node_type_id(handle, id) else {
            return nil
        }
        return String(cString: raw)
    }

    public func parameterCount(of id: ChipsNodeId) -> Int {
        Int(chips_engine_node_param_count(handle, id))
    }

    public func parameterSpec(of id: ChipsNodeId, at index: Int) -> ParameterSpec? {
        var raw = ChipsParamSpec()
        guard chips_engine_node_param_at(handle, id, Int32(index), &raw) else {
            return nil
        }
        return ParameterSpec(
            paramId: raw.param_id,
            name: raw.name.map { String(cString: $0) } ?? "",
            unit: raw.unit.map { String(cString: $0) } ?? "",
            minValue: raw.min_value,
            maxValue: raw.max_value,
            defaultValue: raw.default_value
        )
    }

    /// Recoge la spec de todos los parámetros del nodo en orden de declaración.
    public func parameterSpecs(of id: ChipsNodeId) -> [ParameterSpec] {
        let count = parameterCount(of: id)
        var specs: [ParameterSpec] = []
        specs.reserveCapacity(count)
        for index in 0 ..< count {
            if let spec = parameterSpec(of: id, at: index) {
                specs.append(spec)
            }
        }
        return specs
    }
}

/// Metadata de un parámetro expuesto por un módulo. Espejo Swift de
/// `ChipsParamSpec` (la struct C ABI).
public struct ParameterSpec: Hashable, Sendable {
    public let paramId: UInt32
    public let name: String
    public let unit: String
    public let minValue: Float
    public let maxValue: Float
    public let defaultValue: Float

    public init(
        paramId: UInt32,
        name: String,
        unit: String,
        minValue: Float,
        maxValue: Float,
        defaultValue: Float
    ) {
        self.paramId = paramId
        self.name = name
        self.unit = unit
        self.minValue = minValue
        self.maxValue = maxValue
        self.defaultValue = defaultValue
    }
}
