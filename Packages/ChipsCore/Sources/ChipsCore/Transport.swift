import Foundation

public let chipsTicksPerQuarter: Int64 = 480

/// Estado del transport: tempo, posición en ticks PPQ, loop.
public struct Transport: Sendable, Codable, Equatable {
    public var tempoBpm: Double
    public var isPlaying: Bool
    public var positionTicks: Int64
    public var loopStart: Int64
    public var loopEnd: Int64
    public var loopEnabled: Bool

    public init(
        tempoBpm: Double = 120,
        isPlaying: Bool = false,
        positionTicks: Int64 = 0,
        loopStart: Int64 = 0,
        loopEnd: Int64 = chipsTicksPerQuarter * 4,
        loopEnabled: Bool = true
    ) {
        self.tempoBpm = tempoBpm
        self.isPlaying = isPlaying
        self.positionTicks = positionTicks
        self.loopStart = loopStart
        self.loopEnd = loopEnd
        self.loopEnabled = loopEnabled
    }
}

public extension Transport {
    /// Bar.beat.tick formateado tipo "1.1.00" como en el mockup.
    func formattedTimecode(stepsPerBar: Int = 16) -> String {
        let totalSteps = positionTicks / (chipsTicksPerQuarter * 4 / Int64(stepsPerBar))
        let bar = Int(totalSteps / Int64(stepsPerBar)) + 1
        let step = Int(totalSteps % Int64(stepsPerBar))
        let beat = step / (stepsPerBar / 4) + 1
        let subStep = step % (stepsPerBar / 4)
        return String(format: "%d.%d.%02d", bar, beat, subStep)
    }
}
