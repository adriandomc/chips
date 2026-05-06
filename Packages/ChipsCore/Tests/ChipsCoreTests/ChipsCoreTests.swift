import XCTest
@testable import ChipsCore

final class ChipsCoreTests: XCTestCase {
    func testVersionIsNotEmpty() {
        XCTAssertFalse(ChipsCore.version.isEmpty)
    }

    func testProjectIdentifierIsUnique() {
        let a = ProjectIdentifier()
        let b = ProjectIdentifier()
        XCTAssertNotEqual(a, b)
    }
}
