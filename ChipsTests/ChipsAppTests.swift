@testable import Chips
@testable import ChipsCore
import XCTest

final class ChipsAppTests: XCTestCase {
    @MainActor
    func testProjectControllerInitializesWithDefaultGraph() throws {
        let controller = try ProjectController(graph: ProjectController.defaultGraph())
        XCTAssertNotNil(controller.synthRef)
        XCTAssertNotNil(controller.mixerRef)
        XCTAssertNotNil(controller.delayRef)
        XCTAssertNotNil(controller.reverbRef)
    }

    @MainActor
    func testAppShellLoads() throws {
        let controller = try ProjectController(graph: ProjectController.defaultGraph())
        let shell = AppShellViewController(controller: controller)
        shell.loadViewIfNeeded()
        XCTAssertNotNil(shell.view)
    }

    @MainActor
    func testProjectControllerAppliesParameterByName() throws {
        let controller = try ProjectController(graph: ProjectController.defaultGraph())
        guard let synthRef = controller.synthRef else {
            XCTFail("synthRef")
            return
        }
        controller.setParameter(of: synthRef, paramName: "attack", value: 0.123)
        XCTAssertEqual(controller.parameter(of: synthRef, name: "attack"), 0.123)
    }

    @MainActor
    func testProjectControllerCurrentGraphReflectsEdits() throws {
        let controller = try ProjectController(graph: ProjectController.defaultGraph())
        controller.setTempo(140)
        guard let synthRef = controller.synthRef else {
            XCTFail("synthRef")
            return
        }
        controller.setParameter(of: synthRef, paramName: "volume", value: 0.9)
        let snapshot = controller.currentGraph(name: "myproj", author: "me")
        XCTAssertEqual(snapshot.name, "myproj")
        XCTAssertEqual(snapshot.tempoBpm, 140)
        XCTAssertEqual(snapshot.node(matching: "additive_synth")?.parameters["volume"], 0.9)
    }
}
