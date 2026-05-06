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

    private let coordinator: AudioCoordinator

    init(coordinator: AudioCoordinator) {
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("AppShellViewController no soporta NSCoder")
    }

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

        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 44),

            sidebar.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            sidebar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sidebar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            sidebar.widthAnchor.constraint(equalToConstant: 56),

            contentContainer.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: sidebar.leadingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])

        sidebar.onSelect = { [weak self] section in
            self?.show(section: section)
        }
        topBar.playButton.addTarget(self, action: #selector(playTapped), for: .touchUpInside)
        topBar.stopButton.addTarget(self, action: #selector(stopTapped), for: .touchUpInside)

        show(section: .sequencer)
        sidebar.setSelected(.sequencer)
    }

    private func show(section: AppSection) {
        currentSection = section
        sidebar.setSelected(section)
        let newChild: UIViewController = switch section {
        case .sequencer: SequencerSectionViewController()
        case .mixer: MixerSectionViewController()
        case .synthesizer: SynthesizerSectionViewController(coordinator: coordinator)
        case .grid: GridSectionViewController()
        case .settings: SettingsSectionViewController()
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
        coordinator.start()
    }

    @objc private func stopTapped() {
        coordinator.stop()
    }
}
