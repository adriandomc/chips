import XCTest
@testable import ChipsModules

final class ChipsModulesTests: XCTestCase {
    func testVersionIsNotEmpty() {
        XCTAssertFalse(ChipsModules.version.isEmpty)
    }
}
