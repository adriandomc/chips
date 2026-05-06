import Foundation

/// Helpers de testing: golden audio, fixtures, comparadores RMS/hash.
/// Se irá poblando a partir de M2 (tests offline determinísticos del grafo).
public enum ChipsTesting {
    public static let version = "0.0.1-m0"

    /// Calcula el RMS de un buffer de audio de un solo canal.
    public static func rms(_ samples: [Float]) -> Float {
        guard samples.isEmpty == false else { return 0 }
        let sumSquares = samples.reduce(Float(0)) { acc, x in acc + x * x }
        return (sumSquares / Float(samples.count)).squareRoot()
    }
}
