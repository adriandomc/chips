import ChipsCore
import ChipsUIKit
import UIKit

final class MixerSectionViewController: UIViewController {
    private let controller: ProjectController
    private let visibleStripCount = 10
    /// Solo los primeros 4 strips están cableados al MixerModule (kMaxChannels=4).
    /// Los strips 5–10 son visuales hasta que MixerModule sea paramétrico (R4).
    private let wiredChannelCount = 4

    init(controller: ProjectController) {
        self.controller = controller
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("MixerSectionViewController no soporta NSCoder")
    }

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

        for i in 0 ..< visibleStripCount {
            let isWired = i < wiredChannelCount
            let strip = ChannelStripView(
                label: "Track \(i + 1)",
                controller: isWired ? controller : nil,
                channelIndex: isWired ? i : nil
            )
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
    private weak var controller: ProjectController?
    private let channelIndex: Int?
    private let fader = ChipsFader()
    private let panKnob = ChipsKnob()
    private let muteButton = ChipsButton()

    init(label: String, controller: ProjectController?, channelIndex: Int?) {
        self.controller = controller
        self.channelIndex = channelIndex
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

        if channelIndex != nil {
            fader.addTarget(self, action: #selector(faderChanged), for: .valueChanged)
            panKnob.addTarget(self, action: #selector(panChanged), for: .valueChanged)
            muteButton.addTarget(self, action: #selector(muteTapped), for: .touchUpInside)
        }
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
        fader.value = initialGain()

        panKnob.label = "Pan"
        panKnob.minValue = -1
        panKnob.maxValue = 1
        panKnob.value = initialPan()

        let soloButton = makeSmallButton(title: "S")
        muteButton.title = "M"
        muteButton.titleFont = ChipsTheme.Font.mono(size: 10, weight: .semibold)
        muteButton.contentInsets = .init(top: 2, left: 6, bottom: 2, right: 6)

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

        eqBox.heightAnchor.constraint(equalToConstant: 36).isActive = true
        sendsRow.heightAnchor.constraint(equalToConstant: 18).isActive = true
        fader.heightAnchor.constraint(equalToConstant: 200).isActive = true
        panKnob.heightAnchor.constraint(equalToConstant: 60).isActive = true
        msRow.heightAnchor.constraint(equalToConstant: 22).isActive = true
        return stack
    }

    private func initialGain() -> Float {
        guard let controller, let idx = channelIndex, let mixer = controller.mixerRef else { return 0.8 }
        return controller.parameter(of: mixer, name: "ch\(idx)_gain") ?? 0.8
    }

    private func initialPan() -> Float {
        guard let controller, let idx = channelIndex, let mixer = controller.mixerRef else { return 0 }
        return controller.parameter(of: mixer, name: "ch\(idx)_pan") ?? 0
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
        let row = UIStackView(arrangedSubviews: [makeSendDot(), makeSendDot()])
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

    @objc private func faderChanged() {
        guard let controller, let idx = channelIndex, let mixer = controller.mixerRef else { return }
        controller.setParameter(of: mixer, paramName: "ch\(idx)_gain", value: fader.value)
    }

    @objc private func panChanged() {
        guard let controller, let idx = channelIndex, let mixer = controller.mixerRef else { return }
        controller.setParameter(of: mixer, paramName: "ch\(idx)_pan", value: panKnob.value)
    }

    @objc private func muteTapped() {
        guard let controller, let idx = channelIndex, let mixer = controller.mixerRef else { return }
        muteButton.isSelected.toggle()
        controller.setParameter(of: mixer, paramName: "ch\(idx)_mute", value: muteButton.isSelected ? 1 : 0)
    }
}
