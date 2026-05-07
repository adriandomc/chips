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

    @MainActor
    func testInstrumentUIRegistryFallsBackToGenericPanel() throws {
        let controller = try ProjectController(graph: ProjectController.defaultGraph())
        guard let delayRef = controller.delayRef else {
            XCTFail("delayRef")
            return
        }
        // No hay builder registrado para "delay" — el registry devuelve genérico.
        let panel = InstrumentUIRegistry.makePanel(typeId: "delay", ref: delayRef, controller: controller)
        XCTAssertTrue(panel is GenericInstrumentPanelViewController)
    }

    @MainActor
    func testInstrumentUIRegistryUsesRegisteredBuilder() throws {
        let controller = try ProjectController(graph: ProjectController.defaultGraph())
        InstrumentUIRegistry.unregister(typeId: "test_type_xyz")
        InstrumentUIRegistry.register(typeId: "test_type_xyz") { _, _ in
            UIViewController()
        }
        defer { InstrumentUIRegistry.unregister(typeId: "test_type_xyz") }
        XCTAssertTrue(InstrumentUIRegistry.hasBuilder(typeId: "test_type_xyz"))
        let panel = InstrumentUIRegistry.makePanel(
            typeId: "test_type_xyz",
            ref: UUID(),
            controller: controller
        )
        XCTAssertFalse(panel is GenericInstrumentPanelViewController)
    }

    @MainActor
    func testMixerExposesEightChannelsByDefaultViaController() throws {
        let controller = try ProjectController(graph: ProjectController.defaultGraph())
        guard let mixerRef = controller.mixerRef,
              let chipsId = controller.chipsNodeId(for: mixerRef)
        else {
            XCTFail("mixerRef")
            return
        }
        XCTAssertEqual(controller.host.engine.parameterCount(of: chipsId), 24)
    }
}
