import ChipsAudioHost
import ChipsCore
import ChipsEngine
import ChipsMIDI
import ChipsModules
import ChipsUIKit
import UIKit

final class HelpSectionViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ChipsTheme.contentBackground

        let title = UILabel()
        title.text = "Chips"
        title.font = ChipsTheme.Font.body(size: 28, weight: .heavy)
        title.textColor = ChipsTheme.textPrimary

        let subtitle = UILabel()
        subtitle.text = "DAW modular para iOS · M3 (UI framework)"
        subtitle.font = ChipsTheme.Font.body(size: 14)
        subtitle.textColor = ChipsTheme.textSecondary

        let versions = UILabel()
        versions.numberOfLines = 0
        versions.font = ChipsTheme.Font.mono(size: 11)
        versions.textColor = ChipsTheme.textSecondary
        versions.text = [
            "Core \(ChipsCore.version)",
            "Engine \(ChipsEngine.version)",
            "AudioHost \(ChipsAudioHost.version)",
            "MIDI \(ChipsMIDI.version)",
            "UIKit \(ChipsUIKit.version)",
            "Modules \(ChipsModules.version)",
        ].joined(separator: "\n")

        let stack = UIStackView(arrangedSubviews: [title, subtitle, versions])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
        ])
    }
}
