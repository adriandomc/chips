import XCTest
@testable import Chips

final class ChipsAppTests: XCTestCase {
    @MainActor
    func testRootViewControllerLoads() {
        let viewController = RootViewController()
        viewController.loadViewIfNeeded()
        XCTAssertNotNil(viewController.view)
    }
}
