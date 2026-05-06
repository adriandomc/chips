import ChipsUIKit
import UIKit

final class SynthesizerSectionViewController: UIViewController {
    private let coordinator: AudioCoordinator
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

    init(coordinator: AudioCoordinator) {
        self.coordinator = coordinator
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
            ("ATTACK", attackKnob),
            ("DECAY", decayKnob),
            ("SUSTAIN", sustainKnob),
            ("RELEASE", releaseKnob),
        ])
        let oscillator = makeKnobsRow([
            ("FINETUNE", fineTuneKnob),
            ("TUNE", tiltKnob),
            ("VOLUME", volumeKnob),
            ("WAVE", waveKnob),
            ("SUB OSC", subOscKnob),
            ("GLIDE", glideKnob),
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
            self?.coordinator.noteOn(midi)
        }
        keyboard.onNoteOff = { [weak self] midi in
            self?.coordinator.noteOff(midi)
        }
    }

    private func configureKnobBindings() {
        // Volumen (0..1, default 0.5).
        volumeKnob.minValue = 0
        volumeKnob.maxValue = 1
        volumeKnob.value = 0.5
        volumeKnob.addTarget(self, action: #selector(volumeChanged), for: .valueChanged)

        // Envelope ADSR.
        attackKnob.minValue = 0.001
        attackKnob.maxValue = 2.0
        attackKnob.value = 0.01
        attackKnob.addTarget(self, action: #selector(attackChanged), for: .valueChanged)

        decayKnob.minValue = 0.001
        decayKnob.maxValue = 2.0
        decayKnob.value = 0.15
        decayKnob.addTarget(self, action: #selector(decayChanged), for: .valueChanged)

        sustainKnob.minValue = 0
        sustainKnob.maxValue = 1
        sustainKnob.value = 0.7
        sustainKnob.addTarget(self, action: #selector(sustainChanged), for: .valueChanged)

        releaseKnob.minValue = 0.001
        releaseKnob.maxValue = 4.0
        releaseKnob.value = 0.4
        releaseKnob.addTarget(self, action: #selector(releaseChanged), for: .valueChanged)

        // Tilt (controla la riqueza armónica del banco aditivo).
        tiltKnob.minValue = 0
        tiltKnob.maxValue = 1
        tiltKnob.value = 0.5
        tiltKnob.addTarget(self, action: #selector(tiltChanged), for: .valueChanged)
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

    @objc private func volumeChanged() { coordinator.setVolume(volumeKnob.value) }
    @objc private func attackChanged() { coordinator.setAttack(attackKnob.value) }
    @objc private func decayChanged() { coordinator.setDecay(decayKnob.value) }
    @objc private func sustainChanged() { coordinator.setSustain(sustainKnob.value) }
    @objc private func releaseChanged() { coordinator.setRelease(releaseKnob.value) }
    @objc private func tiltChanged() { coordinator.setTilt(tiltKnob.value) }
}
