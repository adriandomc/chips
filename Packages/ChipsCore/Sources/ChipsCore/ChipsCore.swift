import Foundation

public enum ChipsCore {
    public static let version = "0.5.0-m5"

    /// Pulses per quarter note. Estándar PPQ=480 — usado por Cubase, Logic, etc.
    public static let ppq: Int = 480
}

public struct ProjectIdentifier: Hashable, Sendable, Codable {
    public let uuid: UUID

    public init(uuid: UUID = UUID()) {
        self.uuid = uuid
    }
}
