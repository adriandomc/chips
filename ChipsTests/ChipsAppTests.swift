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
    func testDefaultGraphSeedsAudibleTrack() {
        // El default graph trae un track demo con 8 notas (escala C mayor)
        // ruteado al synth. Así al primer launch el usuario puede pulsar Play
        // y oír algo sin tener que dibujar notas.
        let graph = ProjectController.defaultGraph()
        XCTAssertEqual(graph.tracks.count, 1)
        guard let track = graph.tracks.first, let pattern = track.patterns.first else {
            XCTFail("track/pattern")
            return
        }
        XCTAssertEqual(pattern.notes.count, 8)
        let synthRef = graph.nodes.first { $0.typeId == "additive_synth" }?.id
        XCTAssertEqual(track.instrumentRef, synthRef)
        XCTAssertEqual(pattern.notes.map(\.midi), [60, 62, 64, 65, 67, 69, 71, 72])
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

    @MainActor
    func testEntitlementManagerInDebugIsEntitled() {
        // En builds de DEBUG el manager arranca con isEntitled = true, sin
        // depender de StoreKit. Esto garantiza que la app es usable durante
        // desarrollo y CI sin StoreKit configuration files.
        XCTAssertTrue(EntitlementManager.shared.isEntitled)
    }

    func testPrivacyManifestDeclaresSystemBootTimeReason() throws {
        // Verifica que el PrivacyInfo.xcprivacy embebido en el bundle declara
        // SystemBootTime con razón 35F9.1, requerido por App Review por usar
        // CACurrentMediaTime() en SequencerEngine.
        guard let url = Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy") else {
            XCTFail("PrivacyInfo.xcprivacy no está en el bundle")
            return
        }
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        XCTAssertNotNil(plist)
        XCTAssertEqual(plist?["NSPrivacyTracking"] as? Bool, false)
        let apis = plist?["NSPrivacyAccessedAPITypes"] as? [[String: Any]] ?? []
        let hasBootTime = apis.contains { dict in
            (dict["NSPrivacyAccessedAPIType"] as? String) == "NSPrivacyAccessedAPICategorySystemBootTime"
                && (dict["NSPrivacyAccessedAPITypeReasons"] as? [String])?.contains("35F9.1") == true
        }
        XCTAssertTrue(hasBootTime, "Falta declarar SystemBootTime con reason 35F9.1")
    }
}
