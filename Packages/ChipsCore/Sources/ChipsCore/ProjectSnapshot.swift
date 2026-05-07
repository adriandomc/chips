import Foundation

/// Snapshot serializable de un proyecto Chips. Versionado vía `schemaVersion`
/// para soportar migraciones futuras.
public struct ProjectSnapshot: Codable, Sendable {
    public static let currentSchemaVersion: Int = 1

    public var schemaVersion: Int
    public var name: String
    public var author: String
    public var tempoBpm: Float
    public var tracks: [Track]
    public var synth: SynthSettings
    public var mixerChannels: [MixerChannelSettings]
    public var delay: DelaySettings
    public var reverb: ReverbSettings

    public init(
        schemaVersion: Int = ProjectSnapshot.currentSchemaVersion,
        name: String = "Untitled",
        author: String = "",
        tempoBpm: Float = 120,
        tracks: [Track] = [],
        synth: SynthSettings = .default,
        mixerChannels: [MixerChannelSettings] = .defaultBank,
        delay: DelaySettings = .default,
        reverb: ReverbSettings = .default
    ) {
        self.schemaVersion = schemaVersion
        self.name = name
        self.author = author
        self.tempoBpm = tempoBpm
        self.tracks = tracks
        self.synth = synth
        self.mixerChannels = mixerChannels
        self.delay = delay
        self.reverb = reverb
    }
}

public struct SynthSettings: Codable, Sendable {
    public var volume: Float
    public var attack: Float
    public var decay: Float
    public var sustain: Float
    public var release: Float
    public var tilt: Float

    public init(
        volume: Float = 0.5,
        attack: Float = 0.01,
        decay: Float = 0.15,
        sustain: Float = 0.7,
        release: Float = 0.4,
        tilt: Float = 0.5
    ) {
        self.volume = volume
        self.attack = attack
        self.decay = decay
        self.sustain = sustain
        self.release = release
        self.tilt = tilt
    }

    public static let `default` = SynthSettings()
}

public struct MixerChannelSettings: Codable, Sendable {
    public var gain: Float
    public var pan: Float
    public var muted: Bool

    public init(gain: Float = 0.8, pan: Float = 0, muted: Bool = false) {
        self.gain = gain
        self.pan = pan
        self.muted = muted
    }
}

public extension [MixerChannelSettings] {
    static var defaultBank: [MixerChannelSettings] {
        Array(repeating: MixerChannelSettings(), count: 4)
    }
}

public struct DelaySettings: Codable, Sendable {
    public var timeSeconds: Float
    public var feedback: Float
    public var wet: Float

    public init(timeSeconds: Float = 0.35, feedback: Float = 0.35, wet: Float = 0.20) {
        self.timeSeconds = timeSeconds
        self.feedback = feedback
        self.wet = wet
    }

    public static let `default` = DelaySettings()
}

public struct ReverbSettings: Codable, Sendable {
    public var roomSize: Float
    public var damping: Float
    public var wet: Float

    public init(roomSize: Float = 0.7, damping: Float = 0.3, wet: Float = 0.20) {
        self.roomSize = roomSize
        self.damping = damping
        self.wet = wet
    }

    public static let `default` = ReverbSettings()
}

public enum ProjectStorageError: Error {
    case unsupportedSchemaVersion(Int)
    case invalidData
}

private struct SchemaHeader: Decodable {
    let schemaVersion: Int
}

public enum ProjectStorage {
    public static let fileExtension = "chips"

    // MARK: ProjectGraph (v2) — formato actual

    public static func encode(_ graph: ProjectGraph) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(graph)
    }

    /// Decodifica un proyecto. Auto-detecta la versión: v1 se migra a v2
    /// transparentemente; v2 se decodifica directo. Versiones desconocidas
    /// (futuras o inválidas) lanzan `unsupportedSchemaVersion`.
    public static func decodeProject(_ data: Data) throws -> ProjectGraph {
        let header = try JSONDecoder().decode(SchemaHeader.self, from: data)
        switch header.schemaVersion {
        case 1:
            let v1 = try JSONDecoder().decode(ProjectSnapshot.self, from: data)
            return ProjectMigrator.migrateV1ToV2(v1)
        case 2:
            return try JSONDecoder().decode(ProjectGraph.self, from: data)
        default:
            throw ProjectStorageError.unsupportedSchemaVersion(header.schemaVersion)
        }
    }

    // MARK: ProjectSnapshot (v1) — legacy, usado todavía por AudioCoordinator

    // hasta que R3 lo reemplace por ProjectController.

    public static func encode(_ snapshot: ProjectSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(snapshot)
    }

    public static func decode(_ data: Data) throws -> ProjectSnapshot {
        let decoder = JSONDecoder()
        let snapshot = try decoder.decode(ProjectSnapshot.self, from: data)
        guard snapshot.schemaVersion <= ProjectSnapshot.currentSchemaVersion else {
            throw ProjectStorageError.unsupportedSchemaVersion(snapshot.schemaVersion)
        }
        return snapshot
    }
}
