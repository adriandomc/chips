import Foundation

/// Escritor de WAV PCM 16-bit interleaved stereo. Suficiente para M7
/// (export Master Track). PCM 24-bit y otras tasas vienen después.
public enum WavWriter {
    public enum WriterError: Error {
        case invalidParameters
        case writeFailed
    }

    /// Escribe `samples` (interleaved stereo, formato float [-1..1]) a `url`
    /// como WAV PCM 16-bit. La conversión a 16-bit hace clamping antes.
    public static func writeStereoPCM16(
        samples: [Float],
        sampleRate: Int,
        to url: URL
    ) throws {
        try writeStereoPCM16(samples: samples.withUnsafeBufferPointer { $0 }, sampleRate: sampleRate, to: url)
    }

    public static func writeStereoPCM16(
        samples: UnsafeBufferPointer<Float>,
        sampleRate: Int,
        to url: URL
    ) throws {
        guard sampleRate > 0, !samples.isEmpty, samples.count % 2 == 0 else {
            throw WriterError.invalidParameters
        }
        let frameCount = samples.count / 2
        let bitsPerSample = 16
        let bytesPerSample = bitsPerSample / 8
        let channels = 2
        let dataSize = frameCount * channels * bytesPerSample
        let fileSize = 36 + dataSize // RIFF header + fmt + data header

        var data = Data()
        data.reserveCapacity(8 + fileSize)

        data.append(contentsOf: "RIFF".utf8)
        data.append(uint32LE: UInt32(fileSize))
        data.append(contentsOf: "WAVE".utf8)

        data.append(contentsOf: "fmt ".utf8)
        data.append(uint32LE: 16) // chunk size
        data.append(uint16LE: 1) // format code: PCM
        data.append(uint16LE: UInt16(channels))
        data.append(uint32LE: UInt32(sampleRate))
        data.append(uint32LE: UInt32(sampleRate * channels * bytesPerSample))
        data.append(uint16LE: UInt16(channels * bytesPerSample))
        data.append(uint16LE: UInt16(bitsPerSample))

        data.append(contentsOf: "data".utf8)
        data.append(uint32LE: UInt32(dataSize))

        for i in 0 ..< samples.count {
            let clamped = max(-1.0, min(1.0, samples[i]))
            let pcm = Int16(clamped * 32767)
            data.append(int16LE: pcm)
        }

        try data.write(to: url)
    }
}

private extension Data {
    mutating func append(uint16LE value: UInt16) {
        var encoded = value.littleEndian
        Swift.withUnsafeBytes(of: &encoded) { append(contentsOf: $0) }
    }

    mutating func append(uint32LE value: UInt32) {
        var encoded = value.littleEndian
        Swift.withUnsafeBytes(of: &encoded) { append(contentsOf: $0) }
    }

    mutating func append(int16LE value: Int16) {
        var encoded = value.littleEndian
        Swift.withUnsafeBytes(of: &encoded) { append(contentsOf: $0) }
    }
}
