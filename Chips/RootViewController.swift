import ChipsAudioHost
import ChipsCore
import ChipsEngine
import ChipsMIDI
import ChipsModules
import ChipsUIKit
import UIKit

final class RootViewController: UIViewController {
    private let titleLabel = UILabel()
    private let versionLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1.0)

        titleLabel.text = "Chips"
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 56, weight: .heavy)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let versions = [
            "Core \(ChipsCore.version)",
            "Engine \(ChipsEngine.version)",
            "AudioHost \(ChipsAudioHost.version)",
            "MIDI \(ChipsMIDI.version)",
            "UIKit \(ChipsUIKit.version)",
            "Modules \(ChipsModules.version)",
        ].joined(separator: " · ")

        versionLabel.text = versions
        versionLabel.textColor = UIColor.white.withAlphaComponent(0.45)
        versionLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        versionLabel.textAlignment = .center
        versionLabel.numberOfLines = 0
        versionLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(titleLabel)
        view.addSubview(versionLabel)

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            versionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            versionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            versionLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
        ])
    }
}
