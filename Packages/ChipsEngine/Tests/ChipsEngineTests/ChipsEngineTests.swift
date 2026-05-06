import XCTest
@testable import ChipsEngine

final class ChipsEngineTests: XCTestCase {
    func testVersionIsNotEmpty() {
        XCTAssertFalse(ChipsEngine.version.isEmpty)
    }

    func testEngineCreationAndRenderProducesSilenceInM0() throws {
        let engine = try ChipsEngine(sampleRate: 48_000, maxFrames: 256)
        let frames = 256
        let bufferSize = frames * 2
        let buffer = UnsafeMutablePointer<Float>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        for i in 0 ..< bufferSize {
            buffer[i] = 1.0
        }
        engine.render(into: buffer, frames: frames)
        for i in 0 ..< bufferSize {
            XCTAssertEqual(buffer[i], 0.0, accuracy: 0.0)
        }
    }

    func testEngineCreationFailsWithInvalidParameters() {
        XCTAssertThrowsError(try ChipsEngine(sampleRate: 0, maxFrames: 256))
        XCTAssertThrowsError(try ChipsEngine(sampleRate: 48_000, maxFrames: 0))
    }
}
