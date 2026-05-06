import ChipsUIKit
import UIKit

final class SidebarView: UIView {
    let buttons: [ChipsIconButton]
    var onSelect: ((AppSection) -> Void)?

    private let leftStroke = CALayer()

    init() {
        buttons = AppSection.allCases.map { section in
            let b = ChipsIconButton()
            b.systemImageName = section.iconName
            b.iconSize = 22
            b.tintForeground = ChipsTheme.textOnDark
            return b
        }
        super.init(frame: .zero)
        backgroundColor = ChipsTheme.sidebarBackground
        layer.addSublayer(leftStroke)
        leftStroke.backgroundColor = ChipsTheme.sidebarStroke.cgColor

        for (index, button) in buttons.enumerated() {
            button.translatesAutoresizingMaskIntoConstraints = false
            button.tag = index
            button.addTarget(self, action: #selector(tapped(_:)), for: .touchUpInside)
            addSubview(button)
        }

        // Distribución vertical centrada con espaciado uniforme.
        let stack = UIStackView(arrangedSubviews: buttons)
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        for b in buttons {
            stack.addArrangedSubview(b)
        }
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        for b in buttons {
            NSLayoutConstraint.activate([
                b.widthAnchor.constraint(equalToConstant: 40),
                b.heightAnchor.constraint(equalToConstant: 40),
            ])
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("SidebarView no soporta NSCoder")
    }

    func setSelected(_ section: AppSection) {
        for (i, b) in buttons.enumerated() {
            b.isSelected = i == section.rawValue
        }
    }

    @objc private func tapped(_ sender: ChipsIconButton) {
        guard let section = AppSection(rawValue: sender.tag) else { return }
        onSelect?(section)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        leftStroke.frame = CGRect(x: 0, y: 0, width: 1, height: bounds.height)
    }
}
