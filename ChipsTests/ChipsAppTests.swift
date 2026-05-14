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

    #if DEBUG
    @MainActor
    func testDebugHUDInstalledOnAppShellLoad() throws {
        // En DEBUG, el AppShell instancia un DebugHUDView y lo añade al árbol
        // de vistas. Sirve para verificar que el HUD no se rompe el layout
        // y la lógica de polling no leak-ea.
        let controller = try ProjectController(graph: ProjectController.defaultGraph())
        let shell = AppShellViewController(controller: controller)
        shell.loadViewIfNeeded()
        let hud = shell.view.subviews.first { $0 is DebugHUDView }
        XCTAssertNotNil(hud)
    }
    #endif

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

    func testLocalizableCatalogHasEnAndEs() throws {
        // Verifica que el catálogo Localizable.xcstrings está embebido y trae
        // tanto en como es para todas las claves user-facing. Bloquea regresiones
        // donde se añade una clave en código pero se olvida traducir.
        let strings = try Self.localizationCatalogStrings()
        guard !strings.isEmpty else {
            // El .xcstrings puede no estar como recurso plano (Xcode lo procesa).
            // En ese caso confiamos en `testLocalizedKeysResolveAtRuntime`.
            return
        }
        let requiredKeys = [
            "common.ok", "common.cancel", "common.error",
            "section.sequencer", "section.mixer", "section.synthesizer",
            "section.grid", "section.settings", "section.help",
            "settings.button.new", "settings.button.save", "settings.button.about",
            "settings.label.tempo", "settings.label.export",
            "about.title", "about.privacy_policy", "about.terms",
            "about.restore_button", "about.copyright",
            "onboarding.button.skip", "onboarding.button.next", "onboarding.button.get_started",
            "onboarding.welcome.title", "onboarding.welcome.subtitle",
            "onboarding.export.title", "onboarding.export.subtitle",
            "mixer.label.pan", "mixer.label.eq", "mixer.track_format",
            "generic_panel.empty",
        ]
        for key in requiredKeys {
            guard let entry = strings[key] as? [String: Any] else {
                XCTFail("Falta clave en el catálogo: \(key)")
                continue
            }
            let locs = entry["localizations"] as? [String: Any] ?? [:]
            XCTAssertNotNil(locs["en"], "[\(key)] sin traducción en")
            XCTAssertNotNil(locs["es"], "[\(key)] sin traducción es")
        }
    }

    func testLocalizedKeysResolveAtRuntime() {
        // Verifica que String(localized:) devuelve un valor distinto de la
        // clave — lo que pasaría si el catálogo no estuviera embebido o tuviera
        // mal el formato y cayera al "key as fallback".
        XCTAssertNotEqual(String(localized: "section.sequencer"), "section.sequencer")
        XCTAssertNotEqual(String(localized: "settings.button.new"), "settings.button.new")
        XCTAssertNotEqual(String(localized: "onboarding.welcome.title"), "onboarding.welcome.title")
        XCTAssertNotEqual(String(localized: "about.title"), "about.title")
    }

    private static func localizationCatalogStrings() throws -> [String: Any] {
        // El .xcstrings puede aparecer como recurso plano si Xcode no lo
        // procesa (en ciertos build phases). Si está, parseamos el JSON;
        // si no, devolvemos vacío y confiamos en el test de runtime.
        guard let url = Bundle.main.url(forResource: "Localizable", withExtension: "xcstrings"),
              let data = try? Data(contentsOf: url)
        else {
            return [:]
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json?["strings"] as? [String: Any] ?? [:]
    }

    @MainActor
    func testAutoSaveRoundTripsGraph() throws {
        AutoSave.clear()
        defer { AutoSave.clear() }

        let original = ProjectController.defaultGraph()
        AutoSave.save(original)

        guard let restored = AutoSave.load() else {
            XCTFail("AutoSave.load returned nil después de save")
            return
        }
        XCTAssertEqual(restored.nodes.count, original.nodes.count)
        XCTAssertEqual(restored.tracks.count, original.tracks.count)
        XCTAssertEqual(restored.tempoBpm, original.tempoBpm)
    }

    @MainActor
    func testAutoSaveLoadReturnsNilWhenEmpty() {
        AutoSave.clear()
        XCTAssertNil(AutoSave.load())
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
