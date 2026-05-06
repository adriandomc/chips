import ChipsUIKit
import UIKit

final class SynthesizerSectionViewController: UIViewController {
    private let coordinator: AudioCoordinator
    private let panel = UIView()
    private let keyboard = ChipsPianoKeyboard()
    private var heldNotes: [Int] = []

    private let attackKnob = ChipsKnob()
    private let decayKnob = ChipsKnob()
    private let sustainKnob = ChipsKnob()
    private let releaseKnob = ChipsKnob()
    private let tuneKnob = ChipsKnob()
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

        panel.backgroundColor = ChipsTheme.panelGray
        panel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(panel)

        keyboard.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(keyboard)

        // Top row: envelope + tuning.
        let envelope = makeKnobsRow([
            ("ATTACK", attackKnob),
            ("DECAY", decayKnob),
            ("SUSTAIN", sustainKnob),
            ("RELEASE", releaseKnob),
        ])

        // Bottom row del panel: oscilador.
        let oscillator = makeKnobsRow([
            ("FINETUNE", fineTuneKnob),
            ("TUNE", tuneKnob),
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
        ])

        NSLayoutConstraint.activate([
            panel.topAnchor.constraint(equalTo: view.topAnchor),
            panel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            panel.bottomAnchor.constraint(equalTo: keyboard.topAnchor),

            keyboard.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboard.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboard.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            keyboard.heightAnchor.constraint(equalToConstant: 140),
        ])

        // Volume knob → amplitude del coordinator.
        volumeKnob.value = 0.25
        volumeKnob.minValue = 0
        volumeKnob.maxValue = 1
        volumeKnob.addTarget(self, action: #selector(volumeChanged), for: .valueChanged)

        keyboard.onNoteOn = { [weak self] midi in
            self?.handleNoteOn(midi)
        }
        keyboard.onNoteOff = { [weak self] midi in
            self?.handleNoteOff(midi)
        }
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

    @objc private func volumeChanged() {
        coordinator.setSineAmplitude(volumeKnob.value)
    }

    private func handleNoteOn(_ midi: Int) {
        heldNotes.append(midi)
        let freq = AudioCoordinator.frequency(forMidi: midi)
        coordinator.setSineFrequency(freq)
        coordinator.setSineEnabled(true)
    }

    private func handleNoteOff(_ midi: Int) {
        if let idx = heldNotes.lastIndex(of: midi) {
            heldNotes.remove(at: idx)
        }
        if let last = heldNotes.last {
            let freq = AudioCoordinator.frequency(forMidi: last)
            coordinator.setSineFrequency(freq)
        } else {
            coordinator.setSineEnabled(false)
        }
    }
}
