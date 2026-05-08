import ChipsAudioHost
import ChipsEngine
import ChipsUIKit
import UIKit

final class AppShellViewController: UIViewController {
    private let topBar = TopBarView()
    private let sidebar = SidebarView()
    private let contentContainer = UIView()
    private var currentChild: UIViewController?
    private var currentSection: AppSection = .sequencer
    #if DEBUG
    private var debugHUD: DebugHUDView?
    #endif

    private let coordinator: ProjectController

    init(controller: ProjectController) {
        coordinator = controller
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("AppShellViewController no soporta NSCoder")
    }

    private var sidebarWidthConstraint: NSLayoutConstraint?
    private var topBarHeightConstraint: NSLayoutConstraint?

    /// iPad usa size class regular en horizontal — aumentamos sidebar y topBar.
    /// iPhone (compact) mantiene los valores originales.
    private var compactSidebarWidth: CGFloat { 56 }
    private var regularSidebarWidth: CGFloat { 88 }
    private var compactTopBarHeight: CGFloat { 44 }
    private var regularTopBarHeight: CGFloat { 56 }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ChipsTheme.contentBackground

        topBar.translatesAutoresizingMaskIntoConstraints = false
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.backgroundColor = ChipsTheme.contentBackground

        view.addSubview(topBar)
        view.addSubview(sidebar)
        view.addSubview(contentContainer)

        let sidebarWidth = sidebar.widthAnchor.constraint(equalToConstant: compactSidebarWidth)
        sidebarWidthConstraint = sidebarWidth
        let topBarHeight = topBar.heightAnchor.constraint(equalToConstant: compactTopBarHeight)
        topBarHeightConstraint = topBarHeight

        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBarHeight,

            sidebar.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            sidebar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sidebar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            sidebarWidth,

            contentContainer.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: sidebar.leadingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])

        applyTraitBasedLayout()

        sidebar.onSelect = { [weak self] section in
            self?.show(section: section)
        }
        topBar.playButton.addTarget(self, action: #selector(playTapped), for: .touchUpInside)
        topBar.stopButton.addTarget(self, action: #selector(stopTapped), for: .touchUpInside)

        // Reflejar transport en el timecode label.
        coordinator.onTimecodeChange = { [weak self] formatted in
            self?.topBar.timecode.text = formatted
        }
        topBar.timecode.text = coordinator.transport.formatted

        show(section: .sequencer)
        sidebar.setSelected(.sequencer)

        #if DEBUG
        let hud = DebugHUDView(host: coordinator.host)
        view.addSubview(hud)
        NSLayoutConstraint.activate([
            hud.trailingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: -8),
            hud.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 8),
        ])
        hud.startPolling()
        debugHUD = hud
        #endif
    }

    private func show(section: AppSection) {
        currentSection = section
        sidebar.setSelected(section)
        let newChild: UIViewController = switch section {
        case .sequencer: SequencerSectionViewController()
        case .mixer: MixerSectionViewController(controller: coordinator)
        case .synthesizer: SynthesizerSectionViewController(controller: coordinator)
        case .grid: GridSectionViewController(controller: coordinator)
        case .settings: SettingsSectionViewController(controller: coordinator)
        case .help: HelpSectionViewController()
        }
        replaceContent(with: newChild)
    }

    private func replaceContent(with newChild: UIViewController) {
        if let current = currentChild {
            current.willMove(toParent: nil)
            current.view.removeFromSuperview()
            current.removeFromParent()
        }
        addChild(newChild)
        contentContainer.addSubview(newChild.view)
        newChild.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            newChild.view.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            newChild.view.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            newChild.view.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            newChild.view.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
        ])
        newChild.didMove(toParent: self)
        currentChild = newChild
    }

    @objc private func playTapped() {
        coordinator.play()
    }

    @objc private func stopTapped() {
        coordinator.stop()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.horizontalSizeClass != traitCollection.horizontalSizeClass {
            applyTraitBasedLayout()
        }
    }

    private func applyTraitBasedLayout() {
        let isRegular = traitCollection.horizontalSizeClass == .regular
        sidebarWidthConstraint?.constant = isRegular ? regularSidebarWidth : compactSidebarWidth
        topBarHeightConstraint?.constant = isRegular ? regularTopBarHeight : compactTopBarHeight
    }
}
