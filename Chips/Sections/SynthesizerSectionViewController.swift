import ChipsCore
import ChipsUIKit
import UIKit

final class SynthesizerSectionViewController: UIViewController {
    private let controller: ProjectController
    private let synthRef: NodeRef?
    private let panel = UIView()
    private let keyboard = ChipsPianoKeyboard()

    private let attackKnob = ChipsKnob()
    private let decayKnob = ChipsKnob()
    private let sustainKnob = ChipsKnob()
    private let releaseKnob = ChipsKnob()
    private let tiltKnob = ChipsKnob()
    private let volumeKnob = ChipsKnob()
    private let waveKnob = ChipsKnob()
    private let glideKnob = ChipsKnob()
    private let fineTuneKnob = ChipsKnob()
    private let subOscKnob = ChipsKnob()

    init(controller: ProjectController) {
        self.controller = controller
        synthRef = controller.synthRef
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("SynthesizerSectionViewController no soporta NSCoder")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ChipsTheme.contentBackground
        configurePanel()
        configureKeyboard()
        configureKnobBindings()
    }

    private func configurePanel() {
        panel.backgroundColor = ChipsTheme.panelGray
        panel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(panel)

        let envelope = makeKnobsRow([
            (String(localized: "synth.knob.attack"), attackKnob),
            (String(localized: "synth.knob.decay"), decayKnob),
            (String(localized: "synth.knob.sustain"), sustainKnob),
            (String(localized: "synth.knob.release"), releaseKnob),
        ])
        let oscillator = makeKnobsRow([
            (String(localized: "synth.knob.finetune"), fineTuneKnob),
            (String(localized: "synth.knob.tune"), tiltKnob),
            (String(localized: "synth.knob.volume"), volumeKnob),
            (String(localized: "synth.knob.wave"), waveKnob),
            (String(localized: "synth.knob.sub_osc"), subOscKnob),
            (String(localized: "synth.knob.glide"), glideKnob),
        ])

        let panelStack = UIStackView(arrangedSubviews: [envelope, oscillator])
        panelStack.axis = .vertical
        panelStack.spacing = 18
        panelStack.alignment = .fill
        panelStack.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(panelStack)

        NSLayoutConstraint.activate([
            panelStack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 16),
            panelStack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -16),
            panelStack.topAnchor.constraint(equalTo: panel.topAnchor, constant: 16),
            panelStack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -16),

            panel.topAnchor.constraint(equalTo: view.topAnchor),
            panel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            panel.bottomAnchor.constraint(equalTo: keyboard.topAnchor),
        ])
    }

    private func configureKeyboard() {
        keyboard.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(keyboard)
        NSLayoutConstraint.activate([
            keyboard.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboard.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboard.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            keyboard.heightAnchor.constraint(equalToConstant: 140),
        ])
        keyboard.onNoteOn = { [weak self] midi in
            guard let self, let ref = synthRef else { return }
            controller.sendNoteOn(ref, midi: midi, velocity: 1.0)
        }
        keyboard.onNoteOff = { [weak self] midi in
            guard let self, let ref = synthRef else { return }
            controller.sendNoteOff(ref, midi: midi)
        }
    }

    private func configureKnobBindings() {
        volumeKnob.minValue = 0
        volumeKnob.maxValue = 1
        volumeKnob.value = controller.parameter(of: synthRef ?? UUID(), name: "volume") ?? 0.5
        volumeKnob.accessibilityValueFormatter = Self.percentFormatter
        volumeKnob.addTarget(self, action: #selector(volumeChanged), for: .valueChanged)

        attackKnob.minValue = 0.001
        attackKnob.maxValue = 2.0
        attackKnob.value = controller.parameter(of: synthRef ?? UUID(), name: "attack") ?? 0.01
        attackKnob.accessibilityValueFormatter = Self.timeFormatter
        attackKnob.addTarget(self, action: #selector(attackChanged), for: .valueChanged)

        decayKnob.minValue = 0.001
        decayKnob.maxValue = 2.0
        decayKnob.value = controller.parameter(of: synthRef ?? UUID(), name: "decay") ?? 0.15
        decayKnob.accessibilityValueFormatter = Self.timeFormatter
        decayKnob.addTarget(self, action: #selector(decayChanged), for: .valueChanged)

        sustainKnob.minValue = 0
        sustainKnob.maxValue = 1
        sustainKnob.value = controller.parameter(of: synthRef ?? UUID(), name: "sustain") ?? 0.7
        sustainKnob.accessibilityValueFormatter = Self.percentFormatter
        sustainKnob.addTarget(self, action: #selector(sustainChanged), for: .valueChanged)

        releaseKnob.minValue = 0.001
        releaseKnob.maxValue = 4.0
        releaseKnob.value = controller.parameter(of: synthRef ?? UUID(), name: "release") ?? 0.4
        releaseKnob.accessibilityValueFormatter = Self.timeFormatter
        releaseKnob.addTarget(self, action: #selector(releaseChanged), for: .valueChanged)

        tiltKnob.minValue = 0
        tiltKnob.maxValue = 1
        tiltKnob.value = controller.parameter(of: synthRef ?? UUID(), name: "tilt") ?? 0.5
        tiltKnob.accessibilityValueFormatter = Self.percentFormatter
        tiltKnob.addTarget(self, action: #selector(tiltChanged), for: .valueChanged)
    }

    /// Tiempo en ms si <1 s, en s con un decimal si >=1 s. VoiceOver-friendly.
    private static let timeFormatter: (Float) -> String = { value in
        if value < 1.0 {
            return String(format: "%.0f ms", value * 1000)
        }
        return String(format: "%.1f s", value)
    }

    private static let percentFormatter: (Float) -> String = { value in
        String(format: "%.0f%%", value * 100)
    }

    private func makeKnobsRow(_ items: [(String, ChipsKnob)]) -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.alignment = .top
        row.spacing = 8
        for (label, knob) in items {
            knob.label = label
            knob.translatesAutoresizingMaskIntoConstraints = false
            knob.heightAnchor.constraint(equalToConstant: 80).isActive = true
            row.addArrangedSubview(knob)
        }
        return row
    }

    private func setSynthParameter(_ name: String, value: Float) {
        guard let ref = synthRef else { return }
        controller.setParameter(of: ref, paramName: name, value: value)
    }

    @objc private func volumeChanged() {
        setSynthParameter("volume", value: volumeKnob.value)
    }

    @objc private func attackChanged() {
        setSynthParameter("attack", value: attackKnob.value)
    }

    @objc private func decayChanged() {
        setSynthParameter("decay", value: decayKnob.value)
    }

    @objc private func sustainChanged() {
        setSynthParameter("sustain", value: sustainKnob.value)
    }

    @objc private func releaseChanged() {
        setSynthParameter("release", value: releaseKnob.value)
    }

    @objc private func tiltChanged() {
        setSynthParameter("tilt", value: tiltKnob.value)
    }
}
