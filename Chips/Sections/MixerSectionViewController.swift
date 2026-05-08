import ChipsCore
import ChipsUIKit
import UIKit

final class MixerSectionViewController: UIViewController {
    private let controller: ProjectController
    private var stripViews: [ChannelStripView] = []
    private var meterDisplayLink: CADisplayLink?

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

        // Cuenta canales reales del MixerModule. R4: paramétrico, ya no 4 fijos.
        let wiredCount = wiredChannelCount()
        let trackFormat = String(localized: "mixer.track_format")
        for i in 0 ..< wiredCount {
            let strip = ChannelStripView(
                label: String(format: trackFormat, i + 1),
                controller: controller,
                channelIndex: i
            )
            row.addArrangedSubview(strip)
            strip.widthAnchor.constraint(equalToConstant: 90).isActive = true
            stripViews.append(strip)
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

    private func wiredChannelCount() -> Int {
        guard let mixerRef = controller.mixerRef,
              let chipsId = controller.chipsNodeId(for: mixerRef)
        else {
            return 0
        }
        // Cada canal del MixerModule expone exactamente 3 specs (gain/pan/mute).
        return controller.host.engine.parameterCount(of: chipsId) / 3
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let link = CADisplayLink(target: self, selector: #selector(updateMeters))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 15, maximum: 30, preferred: 30)
        link.add(to: .main, forMode: .common)
        meterDisplayLink = link
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        meterDisplayLink?.invalidate()
        meterDisplayLink = nil
    }

    @objc private func updateMeters() {
        guard let mixerRef = controller.mixerRef,
              let chipsId = controller.chipsNodeId(for: mixerRef)
        else {
            return
        }
        for (idx, strip) in stripViews.enumerated() {
            let l = controller.host.engine.mixerChannelPeak(chipsId, channel: idx, isLeft: true)
            let r = controller.host.engine.mixerChannelPeak(chipsId, channel: idx, isLeft: false)
            strip.setMeterLevels(left: l, right: r)
        }
    }
}

private final class ChannelStripView: UIView {
    private let strokeRight = CALayer()
    private weak var controller: ProjectController?
    private let channelIndex: Int?
    private let fader = ChipsFader()
    private let panKnob = ChipsKnob()
    private let muteButton = ChipsButton()
    private let meterView = StereoMeterView()

    func setMeterLevels(left: Float, right: Float) {
        meterView.setLevels(left: left, right: right)
    }

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
        // VoiceOver: anuncia "Track 1, gain, 80%" en vez del valor crudo.
        fader.accessibilityLabel = "\(label) gain"
        fader.accessibilityValueFormatter = { value in String(format: "%.0f%%", value * 100) }

        panKnob.label = String(localized: "mixer.label.pan")
        panKnob.minValue = -1
        panKnob.maxValue = 1
        panKnob.value = initialPan()
        panKnob.accessibilityValueFormatter = { value in
            if abs(value) < 0.01 { return "Center" }
            return value < 0
                ? String(format: "Left %.0f%%", -value * 100)
                : String(format: "Right %.0f%%", value * 100)
        }

        let soloButton = makeSmallButton(title: String(localized: "mixer.label.solo"))
        soloButton.accessibilityLabel = "Solo"
        muteButton.title = String(localized: "mixer.label.mute")
        muteButton.accessibilityLabel = "Mute"
        muteButton.titleFont = ChipsTheme.Font.mono(size: 10, weight: .semibold)
        muteButton.contentInsets = .init(top: 2, left: 6, bottom: 2, right: 6)

        let msRow = UIStackView(arrangedSubviews: [muteButton, soloButton])
        msRow.axis = .horizontal
        msRow.spacing = 4
        msRow.distribution = .fillEqually

        // Fader + meter side-by-side (meter izquierda, fader derecha).
        let faderRow = UIStackView(arrangedSubviews: [meterView, fader])
        faderRow.axis = .horizontal
        faderRow.spacing = 4
        faderRow.alignment = .fill
        meterView.widthAnchor.constraint(equalToConstant: 14).isActive = true

        let stack = UIStackView(arrangedSubviews: [
            titleLabel, eqBox, sendsRow, sendsLabel, faderRow, panKnob, msRow,
        ])
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .fill

        eqBox.heightAnchor.constraint(equalToConstant: 36).isActive = true
        sendsRow.heightAnchor.constraint(equalToConstant: 18).isActive = true
        faderRow.heightAnchor.constraint(equalToConstant: 200).isActive = true
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
        eqLabel.text = String(localized: "mixer.label.eq")
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
        label.text = String(localized: "mixer.label.sends")
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

/// Meter stereo. Dos barras verticales L/R con peak indicador.
/// Mapeo amplitud → altura: lineal por simplicidad (peak alcanza top a 1.0).
/// Color: cyan en zona segura, amarillo > 0.7, rojo > 0.95.
private final class StereoMeterView: UIView {
    private let barL = CALayer()
    private let barR = CALayer()
    private let bgL = CALayer()
    private let bgR = CALayer()
    private var levelL: Float = 0
    private var levelR: Float = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        for bg in [bgL, bgR] {
            bg.backgroundColor = ChipsTheme.buttonGray.withAlphaComponent(0.6).cgColor
            layer.addSublayer(bg)
        }
        for bar in [barL, barR] {
            bar.backgroundColor = ChipsTheme.accentCyan.cgColor
            layer.addSublayer(bar)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("StereoMeterView no soporta NSCoder")
    }

    func setLevels(left: Float, right: Float) {
        levelL = max(0, min(1, left))
        levelR = max(0, min(1, right))
        layoutBars()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutBars()
    }

    private func layoutBars() {
        let halfWidth = bounds.width / 2 - 1
        let height = bounds.height
        bgL.frame = CGRect(x: 0, y: 0, width: halfWidth, height: height)
        bgR.frame = CGRect(x: halfWidth + 2, y: 0, width: halfWidth, height: height)

        let hL = CGFloat(levelL) * height
        let hR = CGFloat(levelR) * height
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        barL.frame = CGRect(x: 0, y: height - hL, width: halfWidth, height: hL)
        barR.frame = CGRect(x: halfWidth + 2, y: height - hR, width: halfWidth, height: hR)
        barL.backgroundColor = colorForLevel(levelL).cgColor
        barR.backgroundColor = colorForLevel(levelR).cgColor
        CATransaction.commit()
    }

    private func colorForLevel(_ level: Float) -> UIColor {
        if level > 0.95 { return ChipsTheme.transportRed }
        if level > 0.7 { return ChipsTheme.accentYellow }
        return ChipsTheme.accentCyan
    }
}
