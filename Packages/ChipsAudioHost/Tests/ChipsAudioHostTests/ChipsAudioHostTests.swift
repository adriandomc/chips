@testable import ChipsAudioHost
import XCTest

final class ChipsAudioHostTests: XCTestCase {
    func testVersionIsNotEmpty() {
        XCTAssertFalse(ChipsAudioHost.version.isEmpty)
    }
}
