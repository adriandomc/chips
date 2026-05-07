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
        let apis = try Self.privacyManifestAPIs()
        let hasBootTime = apis.contains { dict in
            (dict["NSPrivacyAccessedAPIType"] as? String) == "NSPrivacyAccessedAPICategorySystemBootTime"
                && (dict["NSPrivacyAccessedAPITypeReasons"] as? [String])?.contains("35F9.1") == true
        }
        XCTAssertTrue(hasBootTime, "Falta declarar SystemBootTime con reason 35F9.1")
    }

    func testPrivacyManifestDeclaresUserDefaultsReason() throws {
        // Verifica que el PrivacyInfo.xcprivacy declara UserDefaults con razón
        // CA92.1, requerido por App Review por persistir el flag del onboarding.
        let apis = try Self.privacyManifestAPIs()
        let hasUserDefaults = apis.contains { dict in
            (dict["NSPrivacyAccessedAPIType"] as? String) == "NSPrivacyAccessedAPICategoryUserDefaults"
                && (dict["NSPrivacyAccessedAPITypeReasons"] as? [String])?.contains("CA92.1") == true
        }
        XCTAssertTrue(hasUserDefaults, "Falta declarar UserDefaults con reason CA92.1")
    }

    @MainActor
    func testOnboardingStateRoundTrip() {
        OnboardingState.reset()
        XCTAssertFalse(OnboardingState.hasCompleted)
        OnboardingState.markCompleted()
        XCTAssertTrue(OnboardingState.hasCompleted)
        OnboardingState.reset()
        XCTAssertFalse(OnboardingState.hasCompleted)
    }

    func testOnboardingPagesHaveContent() {
        let pages = OnboardingPage.allCases
        XCTAssertEqual(pages.count, 4)
        for page in pages {
            XCTAssertFalse(page.title.isEmpty, "Page \(page) sin title")
            XCTAssertFalse(page.subtitle.isEmpty, "Page \(page) sin subtitle")
        }
    }

    @MainActor
    func testOnboardingViewControllerCompletesOnLastPage() {
        OnboardingState.reset()
        let onboarding = OnboardingViewController()
        onboarding.loadViewIfNeeded()

        var completed = false
        onboarding.onComplete = { completed = true }

        // Tap NEXT 3 veces (welcome → sequencer → soundDesign → export).
        for _ in 0 ..< 3 {
            onboarding.perform(NSSelectorFromString("nextTapped"))
        }
        XCTAssertEqual(onboarding.currentIndex, 3)
        XCTAssertFalse(completed)

        // Cuarto tap = GET STARTED → completa.
        onboarding.perform(NSSelectorFromString("nextTapped"))
        XCTAssertTrue(completed)
        XCTAssertTrue(OnboardingState.hasCompleted)
        OnboardingState.reset()
    }

    @MainActor
    func testOnboardingSkipMarksCompleted() {
        OnboardingState.reset()
        let onboarding = OnboardingViewController()
        onboarding.loadViewIfNeeded()

        var completed = false
        onboarding.onComplete = { completed = true }
        onboarding.perform(NSSelectorFromString("skipTapped"))

        XCTAssertTrue(completed)
        XCTAssertTrue(OnboardingState.hasCompleted)
        OnboardingState.reset()
    }

    private static func privacyManifestAPIs() throws -> [[String: Any]] {
        guard let url = Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy") else {
            throw NSError(
                domain: "Test",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "PrivacyInfo no en bundle"]
            )
        }
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        return plist?["NSPrivacyAccessedAPITypes"] as? [[String: Any]] ?? []
    }
}
