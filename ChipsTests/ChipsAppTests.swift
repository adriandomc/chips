@testable import Chips
import XCTest

final class ChipsAppTests: XCTestCase {
    @MainActor
    func testAudioCoordinatorInitializes() throws {
        let coord = try AudioCoordinator()
        XCTAssertNotEqual(coord.sineNodeId, 0)
    }

    @MainActor
    func testAppShellLoads() throws {
        let coord = try AudioCoordinator()
        let shell = AppShellViewController(coordinator: coord)
        shell.loadViewIfNeeded()
        XCTAssertNotNil(shell.view)
    }
}
