@testable import ChipsEngine
import XCTest

final class ChipsEngineTests: XCTestCase {
    private let sampleRate: Double = 48000
    private let frames = 256

    func testVersionIsNotEmpty() {
        XCTAssertFalse(ChipsEngine.version.isEmpty)
    }

    func testEngineProducesSilenceWhenSineDisabled() throws {
        let engine = try ChipsEngine(sampleRate: sampleRate, maxFrames: frames)
        let buffer = UnsafeMutablePointer<Float>.allocate(capacity: frames * 2)
        defer { buffer.deallocate() }

        engine.setSineEnabled(false)
        engine.setSineFrequency(440)

        for i in 0 ..< frames * 2 {
            buffer[i] = 1.0
        }
        engine.render(into: buffer, frames: frames)

        for i in 0 ..< frames * 2 {
            XCTAssertEqual(buffer[i], 0.0)
        }
    }

    func testEngineProducesNonZeroOutputWhenSineEnabled() throws {
        let engine = try ChipsEngine(sampleRate: sampleRate, maxFrames: frames)
        let buffer = UnsafeMutablePointer<Float>.allocate(capacity: frames * 2)
        defer { buffer.deallocate() }

        engine.setSineFrequency(440)
        engine.setSineEnabled(true)
        engine.render(into: buffer, frames: frames)

        var sumSquares: Double = 0
        for i in 0 ..< frames * 2 {
            sumSquares += Double(buffer[i] * buffer[i])
        }
        let rms = (sumSquares / Double(frames * 2)).squareRoot()
        XCTAssertGreaterThan(rms, 0.05, "El RMS de un seno a -12dBFS deberia rondar 0.177")
    }

    func testEngineCreationFailsWithInvalidParameters() {
        XCTAssertThrowsError(try ChipsEngine(sampleRate: 0, maxFrames: 256))
        XCTAssertThrowsError(try ChipsEngine(sampleRate: 48000, maxFrames: 0))
    }

    func testSampleRateMatchesInit() throws {
        let engine = try ChipsEngine(sampleRate: 44100, maxFrames: 128)
        XCTAssertEqual(engine.sampleRate, 44100)
    }

    func testIsSineEnabledReflectsToggle() throws {
        let engine = try ChipsEngine(sampleRate: sampleRate, maxFrames: frames)
        XCTAssertFalse(engine.isSineEnabled)
        engine.setSineEnabled(true)
        XCTAssertTrue(engine.isSineEnabled)
        engine.setSineEnabled(false)
        XCTAssertFalse(engine.isSineEnabled)
    }
}
