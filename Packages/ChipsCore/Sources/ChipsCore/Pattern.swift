import Foundation

/// Una nota dentro de un Pattern.
public struct PatternNote: Hashable, Codable, Sendable {
    public let id: UUID
    public var startTick: Int64
    public var lengthTicks: Int64
    public var midi: UInt8
    public var velocity: Float

    public init(
        id: UUID = UUID(),
        startTick: Int64,
        lengthTicks: Int64,
        midi: UInt8,
        velocity: Float = 1.0
    ) {
        self.id = id
        self.startTick = startTick
        self.lengthTicks = max(1, lengthTicks)
        self.midi = midi
        self.velocity = max(0, min(1, velocity))
    }

    public var endTick: Int64 { startTick + lengthTicks }
}

/// Un pattern es una secuencia de notas con longitud total fija.
public struct Pattern: Codable, Sendable, Identifiable {
    public let id: UUID
    public var name: String
    public var lengthTicks: Int64
    public var notes: [PatternNote]

    public init(
        id: UUID = UUID(),
        name: String,
        lengthTicks: Int64,
        notes: [PatternNote] = []
    ) {
        self.id = id
        self.name = name
        self.lengthTicks = max(1, lengthTicks)
        self.notes = notes
    }

    /// Notas con inicio en `[fromTick, toTick)` (rango semi-abierto).
    public func notesStarting(in fromTick: Int64, to toTick: Int64) -> [PatternNote] {
        notes.filter { $0.startTick >= fromTick && $0.startTick < toTick }
    }

    /// Notas que deberían terminar en `[fromTick, toTick)`.
    public func notesEnding(in fromTick: Int64, to toTick: Int64) -> [PatternNote] {
        notes.filter { $0.endTick > fromTick && $0.endTick <= toTick }
    }

    public mutating func addNote(_ note: PatternNote) {
        notes.append(note)
    }

    public mutating func removeNote(id: UUID) {
        notes.removeAll { $0.id == id }
    }
}

/// Un track tiene un nombre, color, y una lista de patterns (M5: 1 pattern por track).
public struct Track: Codable, Sendable, Identifiable {
    public let id: UUID
    public var name: String
    public var colorIndex: Int
    public var patterns: [Pattern]

    public init(
        id: UUID = UUID(),
        name: String,
        colorIndex: Int,
        patterns: [Pattern] = []
    ) {
        self.id = id
        self.name = name
        self.colorIndex = colorIndex
        self.patterns = patterns
    }
}
