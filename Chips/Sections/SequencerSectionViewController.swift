import ChipsUIKit
import UIKit

final class SequencerSectionViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ChipsTheme.contentBackground

        let trackCount = 6
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 1
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        for i in 0 ..< trackCount {
            let row = TrackRowView(index: i, color: ChipsTheme.trackColor(at: i))
            stack.addArrangedSubview(row)
        }
    }
}

private final class TrackRowView: UIView {
    init(index: Int, color: UIColor) {
        super.init(frame: .zero)
        backgroundColor = color

        let labelContainer = UIView()
        labelContainer.backgroundColor = ChipsTheme.buttonGray
        labelContainer.translatesAutoresizingMaskIntoConstraints = false
        let stroke = CALayer()
        stroke.backgroundColor = ChipsTheme.buttonStroke.cgColor
        labelContainer.layer.addSublayer(stroke)
        addSubview(labelContainer)

        let label = UILabel()
        label.text = String(format: String(localized: "track.default_name_format"), index + 1)
        label.font = ChipsTheme.Font.body(size: 13, weight: .semibold)
        label.textColor = ChipsTheme.textPrimary
        label.translatesAutoresizingMaskIntoConstraints = false
        labelContainer.addSubview(label)

        NSLayoutConstraint.activate([
            labelContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            labelContainer.topAnchor.constraint(equalTo: topAnchor),
            labelContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
            labelContainer.widthAnchor.constraint(equalToConstant: 80),

            label.centerYAnchor.constraint(equalTo: labelContainer.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: labelContainer.leadingAnchor, constant: 8),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("TrackRowView no soporta NSCoder")
    }
}
