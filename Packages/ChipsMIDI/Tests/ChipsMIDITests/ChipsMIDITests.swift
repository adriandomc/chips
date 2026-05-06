@testable import ChipsMIDI
import XCTest

final class ChipsMIDITests: XCTestCase {
    func testVersionIsNotEmpty() {
        XCTAssertFalse(ChipsMIDI.version.isEmpty)
    }
}
