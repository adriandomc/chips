@testable import ChipsAudioHost
import XCTest

final class ChipsAudioHostTests: XCTestCase {
    func testVersionIsNotEmpty() {
        XCTAssertFalse(ChipsAudioHost.version.isEmpty)
    }

    @MainActor
    func testInitProducesEngineWithMatchingSampleRate() throws {
        let host = try ChipsAudioHost(sampleRate: 44100, maxFrames: 256)
        XCTAssertEqual(host.engine.sampleRate, 44100)
        XCTAssertFalse(host.isRunning)
    }
}
