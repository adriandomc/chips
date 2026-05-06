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
    init(label: String) {
        super.init(frame: .zero)
        backgroundColor = ChipsTheme.contentBackground

        let strokeRight = CALayer()
        strokeRight.backgroundColor = ChipsTheme.panelStroke.cgColor
        layer.addSublayer(strokeRight)

        let titleLabel = UILabel()
        titleLabel.text = label
        titleLabel.font = ChipsTheme.Font.body(size: 12, weight: .semibold)
        titleLabel.textColor = ChipsTheme.textPrimary
        titleLabel.textAlignment = .center

        let eqBox = UIView()
        eqBox.backgroundColor = ChipsTheme.buttonGray
        let eqStroke = CALayer()
        eqStroke.backgroundColor = ChipsTheme.buttonStroke.cgColor
        eqBox.layer.addSublayer(eqStroke)
        let eqLabel = UILabel()
        eqLabel.text = "EQ"
        eqLabel.font = ChipsTheme.Font.body(size: 11, weight: .medium)
        eqLabel.textAlignment = .center
        eqBox.addSubview(eqLabel)
        eqLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            eqLabel.topAnchor.constraint(equalTo: eqBox.topAnchor, constant: 4),
            eqLabel.centerXAnchor.constraint(equalTo: eqBox.centerXAnchor),
        ])

        let send1 = makeSendDot()
        let send2 = makeSendDot()
        let sendsRow = UIStackView(arrangedSubviews: [send1, send2])
        sendsRow.axis = .horizontal
        sendsRow.spacing = 6
        sendsRow.alignment = .center

        let sendsLabel = UILabel()
        sendsLabel.text = "Sends"
        sendsLabel.font = ChipsTheme.Font.body(size: 10)
        sendsLabel.textAlignment = .center
        sendsLabel.textColor = ChipsTheme.textSecondary

        let fader = ChipsFader()

        let panKnob = ChipsKnob()
        panKnob.label = "Pan"
        panKnob.minValue = -1
        panKnob.maxValue = 1
        panKnob.value = 0

        let muteButton = ChipsButton()
        muteButton.title = "M"
        muteButton.titleFont = ChipsTheme.Font.mono(size: 10, weight: .semibold)
        muteButton.contentInsets = .init(top: 2, left: 6, bottom: 2, right: 6)

        let soloButton = ChipsButton()
        soloButton.title = "S"
        soloButton.titleFont = ChipsTheme.Font.mono(size: 10, weight: .semibold)
        soloButton.contentInsets = .init(top: 2, left: 6, bottom: 2, right: 6)

        let msRow = UIStackView(arrangedSubviews: [muteButton, soloButton])
        msRow.axis = .horizontal
        msRow.spacing = 4
        msRow.distribution = .fillEqually

        let stack = UIStackView(arrangedSubviews: [
            titleLabel, eqBox, sendsRow, sendsLabel, fader, panKnob, msRow,
        ])
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -12),
            eqBox.heightAnchor.constraint(equalToConstant: 36),
            sendsRow.heightAnchor.constraint(equalToConstant: 18),
            fader.heightAnchor.constraint(equalToConstant: 200),
            panKnob.heightAnchor.constraint(equalToConstant: 60),
            msRow.heightAnchor.constraint(equalToConstant: 22),
        ])

        // Layout sublayers manualmente.
        layoutIfNeeded()
        eqStroke.frame = CGRect(x: 0, y: 0, width: eqBox.bounds.width, height: eqBox.bounds.height)
        strokeRight.frame = CGRect(x: bounds.width - 1, y: 0, width: 1, height: bounds.height)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("ChannelStripView no soporta NSCoder")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if let stroke = layer.sublayers?.first(where: { $0.backgroundColor == ChipsTheme.panelStroke.cgColor }) {
            stroke.frame = CGRect(x: bounds.width - 1, y: 0, width: 1, height: bounds.height)
        }
    }

    private func makeSendDot() -> UIView {
        let v = UIView()
        v.backgroundColor = ChipsTheme.accentYellow
        v.layer.cornerRadius = 7
        v.translatesAutoresizingMaskIntoConstraints = false
        v.widthAnchor.constraint(equalToConstant: 14).isActive = true
        v.heightAnchor.constraint(equalToConstant: 14).isActive = true
        return v
    }
}
