import XCTest
@testable import ChipsUIKit

final class ChipsUIKitTests: XCTestCase {
    func testVersionIsNotEmpty() {
        XCTAssertFalse(ChipsUIKit.version.isEmpty)
    }

    @MainActor
    func testControlBaseConstructs() {
        let control = ChipsControl(frame: .zero)
        XCTAssertNotNil(control)
        XCTAssertEqual(control.backgroundColor, .clear)
    }
}
