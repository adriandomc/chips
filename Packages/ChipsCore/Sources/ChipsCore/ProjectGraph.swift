import Foundation

/// Identificador estable de un nodo en `ProjectGraph`. Sobrevive al rebuild
/// del grafo C++ (los `ChipsNodeId` UInt32 son efímeros, asignados al `addNode`).
public typealias NodeRef = UUID

/// Instancia de un módulo en el grafo del proyecto. Type identifier coincide
/// con el registrado en `ModuleRegistry` (ej. "additive_synth", "delay").
/// Los parámetros se serializan por nombre del `ParamSpec` (no por paramId)
/// para que cambios de paramId interno no rompan el round-trip.
public struct NodeInstance: Codable, Sendable, Identifiable, Hashable {
    public let id: NodeRef
    public var typeId: String
    public var displayName: String
    public var parameters: [String: Float]

    public init(
        id: NodeRef = UUID(),
        typeId: String,
        displayName: String? = nil,
        parameters: [String: Float] = [:]
    ) {
        self.id = id
        self.typeId = typeId
        self.displayName = displayName ?? typeId
        self.parameters = parameters
    }
}

/// Conexión audio dirigida en el grafo: `src.outPort → dst.inPort`.
public struct ConnectionDescriptor: Codable, Sendable, Hashable {
    public var src: NodeRef
    public var srcPort: Int
    public var dst: NodeRef
    public var dstPort: Int

    public init(src: NodeRef, srcPort: Int, dst: NodeRef, dstPort: Int) {
        self.src = src
        self.srcPort = srcPort
        self.dst = dst
        self.dstPort = dstPort
    }
}

/// Representación serializable y editable del grafo del proyecto. Schema v2
/// reemplaza a `ProjectSnapshotV1` (campos rígidos por instrumento). El
/// motor C++ se reconstruye desde este modelo en cada apertura/edición
/// estructural — los settings de cada módulo viven en `node.parameters`.
public struct ProjectGraph: Codable, Sendable {
    public static let currentSchemaVersion: Int = 2

    public var schemaVersion: Int
    public var name: String
    public var author: String
    public var tempoBpm: Float

    public var nodes: [NodeInstance]
    public var connections: [ConnectionDescriptor]
    public var outputNodeRef: NodeRef?

    public var tracks: [Track]

    public init(
        schemaVersion: Int = ProjectGraph.currentSchemaVersion,
        name: String = "Untitled",
        author: String = "",
        tempoBpm: Float = 120,
        nodes: [NodeInstance] = [],
        connections: [ConnectionDescriptor] = [],
        outputNodeRef: NodeRef? = nil,
        tracks: [Track] = []
    ) {
        self.schemaVersion = schemaVersion
        self.name = name
        self.author = author
        self.tempoBpm = tempoBpm
        self.nodes = nodes
        self.connections = connections
        self.outputNodeRef = outputNodeRef
        self.tracks = tracks
    }

    /// Búsqueda lineal — los grafos típicos tienen pocos nodos. Si pasamos
    /// de cientos, optimizamos a un dict cached.
    public func node(withRef ref: NodeRef) -> NodeInstance? {
        nodes.first { $0.id == ref }
    }

    public func node(matching typeId: String) -> NodeInstance? {
        nodes.first { $0.typeId == typeId }
    }
}
