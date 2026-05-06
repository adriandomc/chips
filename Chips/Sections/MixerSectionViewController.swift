import ChipsUIKit
import UIKit

final class MixerSectionViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ChipsTheme.contentBackground

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.alwaysBounceHorizontal = true
        view.addSubview(scroll)

        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 0
        row.alignment = .top
        row.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(row)

        for i in 0 ..< 10 {
            let strip = ChannelStripView(label: "Track \(i + 1)")
            row.addArrangedSubview(strip)
            strip.widthAnchor.constraint(equalToConstant: 78).isActive = true
        }

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            row.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            row.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            row.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            row.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
        ])
    }
}

private final class ChannelStripView: UIView {
    private let strokeRight = CALayer()

    init(label: String) {
        super.init(frame: .zero)
        backgroundColor = ChipsTheme.contentBackground
        layer.addSublayer(strokeRight)
        strokeRight.backgroundColor = ChipsTheme.panelStroke.cgColor

        let stack = makeContentStack(label: label)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -12),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("ChannelStripView no soporta NSCoder")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        strokeRight.frame = CGRect(x: bounds.width - 1, y: 0, width: 1, height: bounds.height)
    }

    private func makeContentStack(label: String) -> UIStackView {
        let titleLabel = makeTitleLabel(label)
        let eqBox = makeEqBox()
        let sendsRow = makeSendsRow()
        let sendsLabel = makeSendsLabel()
        let fader = ChipsFader()
        let panKnob = makePanKnob()
        let msRow = makeMuteSoloRow()

        let stack = UIStackView(arrangedSubviews: [
            titleLabel, eqBox, sendsRow, sendsLabel, fader, panKnob, msRow,
        ])
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .fill

        eqBox.heightAnchor.constraint(equalToConstant: 36).isActive = true
        sendsRow.heightAnchor.constraint(equalToConstant: 18).isActive = true
        fader.heightAnchor.constraint(equalToConstant: 200).isActive = true
        panKnob.heightAnchor.constraint(equalToConstant: 60).isActive = true
        msRow.heightAnchor.constraint(equalToConstant: 22).isActive = true
        return stack
    }

    private func makeTitleLabel(_ text: String) -> UILabel {
        let titleLabel = UILabel()
        titleLabel.text = text
        titleLabel.font = ChipsTheme.Font.body(size: 12, weight: .semibold)
        titleLabel.textColor = ChipsTheme.textPrimary
        titleLabel.textAlignment = .center
        return titleLabel
    }

    private func makeEqBox() -> UIView {
        let box = UIView()
        box.backgroundColor = ChipsTheme.buttonGray
        let stroke = CALayer()
        stroke.backgroundColor = ChipsTheme.buttonStroke.cgColor
        box.layer.addSublayer(stroke)
        let eqLabel = UILabel()
        eqLabel.text = "EQ"
        eqLabel.font = ChipsTheme.Font.body(size: 11, weight: .medium)
        eqLabel.textAlignment = .center
        box.addSubview(eqLabel)
        eqLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            eqLabel.topAnchor.constraint(equalTo: box.topAnchor, constant: 4),
            eqLabel.centerXAnchor.constraint(equalTo: box.centerXAnchor),
        ])
        return box
    }

    private func makeSendsRow() -> UIStackView {
        let send1 = makeSendDot()
        let send2 = makeSendDot()
        let row = UIStackView(arrangedSubviews: [send1, send2])
        row.axis = .horizontal
        row.spacing = 6
        row.alignment = .center
        return row
    }

    private func makeSendsLabel() -> UILabel {
        let label = UILabel()
        label.text = "Sends"
        label.font = ChipsTheme.Font.body(size: 10)
        label.textAlignment = .center
        label.textColor = ChipsTheme.textSecondary
        return label
    }

    private func makePanKnob() -> ChipsKnob {
        let knob = ChipsKnob()
        knob.label = "Pan"
        knob.minValue = -1
        knob.maxValue = 1
        knob.value = 0
        return knob
    }

    private func makeMuteSoloRow() -> UIStackView {
        let muteButton = makeSmallButton(title: "M")
        let soloButton = makeSmallButton(title: "S")
        let row = UIStackView(arrangedSubviews: [muteButton, soloButton])
        row.axis = .horizontal
        row.spacing = 4
        row.distribution = .fillEqually
        return row
    }

    private func makeSmallButton(title: String) -> ChipsButton {
        let button = ChipsButton()
        button.title = title
        button.titleFont = ChipsTheme.Font.mono(size: 10, weight: .semibold)
        button.contentInsets = .init(top: 2, left: 6, bottom: 2, right: 6)
        return button
    }

    private func makeSendDot() -> UIView {
        let dot = UIView()
        dot.backgroundColor = ChipsTheme.accentYellow
        dot.layer.cornerRadius = 7
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.widthAnchor.constraint(equalToConstant: 14).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 14).isActive = true
        return dot
    }
}
