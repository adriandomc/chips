import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var controller: ProjectController?

    func scene(
        _ scene: UIScene,
        willConnectTo _: UISceneSession,
        options _: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        InstrumentUIRegistry.registerBuiltins()
        Task { await EntitlementManager.shared.bootstrap() }
        let window = UIWindow(windowScene: windowScene)
        do {
            // Restaurar autosave si existe — el usuario no pierde cambios entre sesiones.
            let initialGraph = AutoSave.load() ?? ProjectController.defaultGraph()
            let projectController = try ProjectController(graph: initialGraph)
            controller = projectController
            if OnboardingState.hasCompleted {
                window.rootViewController = AppShellViewController(controller: projectController)
            } else {
                let onboarding = OnboardingViewController()
                onboarding.onComplete = { [weak window, weak self] in
                    guard let window, let self else { return }
                    let shell = AppShellViewController(controller: projectController)
                    self.crossFade(window: window, to: shell)
                }
                window.rootViewController = onboarding
            }
        } catch {
            window.rootViewController = ErrorViewController(message: "Audio engine init failed: \(error)")
        }
        window.makeKeyAndVisible()
        self.window = window
    }

    private func crossFade(window: UIWindow, to viewController: UIViewController) {
        UIView.transition(
            with: window,
            duration: 0.3,
            options: .transitionCrossDissolve,
            animations: {
                window.rootViewController = viewController
            }
        )
    }

    /// Auto-save al ir a background. Estándar de DAWs comerciales: el
    /// usuario no pierde cambios entre sesiones aunque cierre la app.
    func sceneDidEnterBackground(_: UIScene) {
        guard let controller else { return }
        AutoSave.save(controller.currentGraph())
    }
}

private final class ErrorViewController: UIViewController {
    private let message: String
    init(message: String) {
        self.message = message
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("ErrorViewController no soporta NSCoder")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1.0)
        let label = UILabel()
        label.text = message
        label.numberOfLines = 0
        label.textColor = .white
        label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
        ])
    }
}
