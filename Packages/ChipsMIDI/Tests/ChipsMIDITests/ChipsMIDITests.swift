import XCTest
@testable import ChipsMIDI

final class ChipsMIDITests: XCTestCase {
    func testVersionIsNotEmpty() {
        XCTAssertFalse(ChipsMIDI.version.isEmpty)
    }
}
