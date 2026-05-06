import XCTest
@testable import ChipsAudioHost

final class ChipsAudioHostTests: XCTestCase {
    func testVersionIsNotEmpty() {
        XCTAssertFalse(ChipsAudioHost.version.isEmpty)
    }
}
