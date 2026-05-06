import Foundation

public enum ChipsCore {
    public static let version = "0.0.1-m0"
}

public struct ProjectIdentifier: Hashable, Sendable, Codable {
    public let uuid: UUID

    public init(uuid: UUID = UUID()) {
        self.uuid = uuid
    }
}
