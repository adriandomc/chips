@testable import ChipsModules
import XCTest

final class ChipsModulesTests: XCTestCase {
    func testVersionIsNotEmpty() {
        XCTAssertFalse(ChipsModules.version.isEmpty)
    }
}
