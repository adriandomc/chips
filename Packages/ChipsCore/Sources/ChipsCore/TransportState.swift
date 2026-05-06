import Foundation

/// Estado de transport: tempo, position, isPlaying. Inmutable; las APIs
/// devuelven copias modificadas.
public struct TransportState: Hashable, Sendable {
    public var isPlaying: Bool
    public var tempoBpm: Float
    public var currentTick: Int64
    public var ppq: Int

    public init(
        isPlaying: Bool = false,
        tempoBpm: Float = 120.0,
        currentTick: Int64 = 0,
        ppq: Int = ChipsCore.ppq
    ) {
        self.isPlaying = isPlaying
        self.tempoBpm = max(20, min(999, tempoBpm))
        self.currentTick = max(0, currentTick)
        self.ppq = max(24, ppq)
    }

    /// Duración de un tick en segundos para el tempo actual.
    public var tickSeconds: Double {
        let secondsPerBeat = 60.0 / Double(tempoBpm)
        return secondsPerBeat / Double(ppq)
    }

    /// Posición en barras.beats.ticks (1.1.00 = compás 1, beat 1, tick 0).
    public var formatted: String {
        let beatsPerBar = 4
        let ticksPerBar = Int64(beatsPerBar * ppq)
        let bar = currentTick / ticksPerBar + 1
        let beatTick = currentTick % ticksPerBar
        let beat = beatTick / Int64(ppq) + 1
        let tickInBeat = beatTick % Int64(ppq)
        // Mostramos los ticks como 0..99 (escalado) para evitar 3 dígitos.
        let displayTick = (tickInBeat * 100) / Int64(ppq)
        return String(format: "%lld.%lld.%02lld", bar, beat, displayTick)
    }
}
