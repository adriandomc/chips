import ChipsCore
import ChipsUIKit
import UIKit

final class GridSectionViewController: UIViewController {
    private let coordinator: AudioCoordinator
    private let stepCount = 16
    private let trackCount = 6
    private let stepsPerBeat = 4
    private let ticksPerStep: Int64

    private var tracks: [Track] = []
    private var stepButtons: [[UIButton]] = []  // [trackIndex][stepIndex]

    init(coordinator: AudioCoordinator) {
        self.coordinator = coordinator
        ticksPerStep = Int64(ChipsCore.ppq / stepsPerBeat)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("GridSectionViewController no soporta NSCoder")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ChipsTheme.contentBackground

        // Inicializar tracks vacíos con las notas base C3, D3, E3, F3, G3, A3.
        let basePitches: [UInt8] = [60, 62, 64, 65, 67, 69]
        let patternLength = Int64(stepCount) * ticksPerStep
        tracks = (0 ..< trackCount).map { idx in
            let trackName = "T\(idx + 1)"
            let pattern = Pattern(name: trackName, lengthTicks: patternLength)
            return Track(name: "\(trackName) (\(basePitches[idx]))", colorIndex: idx, patterns: [pattern])
        }

        layoutGrid()
        coordinator.sequencer.setTracks(tracks)
        coordinator.onTickChange = { [weak self] tick in
            self?.highlightCurrentStep(tick: tick)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        coordinator.onTickChange = nil
    }

    private func layoutGrid() {
        let outerStack = UIStackView()
        outerStack.axis = .vertical
        outerStack.spacing = 6
        outerStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(outerStack)

        for trackIdx in 0 ..< trackCount {
            outerStack.addArrangedSubview(makeRow(trackIdx: trackIdx))
        }

        NSLayoutConstraint.activate([
            outerStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            outerStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            outerStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
        ])
    }

    private func makeRow(trackIdx: Int) -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 4
        row.alignment = .center
        row.distribution = .fill

        let label = UILabel()
        label.text = tracks[trackIdx].name
        label.font = ChipsTheme.Font.mono(size: 11, weight: .semibold)
        label.textColor = ChipsTheme.textPrimary
        label.textAlignment = .center
        label.backgroundColor = ChipsTheme.trackColor(at: trackIdx)
        label.layer.borderWidth = 1
        label.layer.borderColor = ChipsTheme.buttonStroke.cgColor
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: 80).isActive = true
        label.heightAnchor.constraint(equalToConstant: 28).isActive = true
        row.addArrangedSubview(label)

        var buttons: [UIButton] = []
        for stepIdx in 0 ..< stepCount {
            let button = makeStepButton(trackIdx: trackIdx, stepIdx: stepIdx)
            buttons.append(button)
            row.addArrangedSubview(button)
        }
        stepButtons.append(buttons)
        return row
    }

    private func makeStepButton(trackIdx: Int, stepIdx: Int) -> UIButton {
        let button = UIButton(type: .custom)
        button.tag = trackIdx * 1000 + stepIdx
        button.backgroundColor = ChipsTheme.buttonGray
        button.layer.borderWidth = 1
        button.layer.borderColor = ChipsTheme.buttonStroke.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 28).isActive = true
        button.heightAnchor.constraint(equalToConstant: 28).isActive = true
        button.addTarget(self, action: #selector(stepTapped(_:)), for: .touchUpInside)
        return button
    }

    @objc private func stepTapped(_ sender: UIButton) {
        let trackIdx = sender.tag / 1000
        let stepIdx = sender.tag % 1000
        guard tracks.indices.contains(trackIdx),
              !tracks[trackIdx].patterns.isEmpty
        else { return }

        let basePitches: [UInt8] = [60, 62, 64, 65, 67, 69]
        let pitch = basePitches[trackIdx]
        let startTick = Int64(stepIdx) * ticksPerStep

        var pattern = tracks[trackIdx].patterns[0]
        if let existing = pattern.notes.first(where: { $0.startTick == startTick && $0.midi == pitch }) {
            pattern.removeNote(id: existing.id)
            sender.backgroundColor = ChipsTheme.buttonGray
        } else {
            pattern.addNote(PatternNote(startTick: startTick, lengthTicks: ticksPerStep, midi: pitch))
            sender.backgroundColor = ChipsTheme.trackColor(at: trackIdx)
        }
        tracks[trackIdx].patterns[0] = pattern
        coordinator.sequencer.updateTrack(tracks[trackIdx])
    }

    private func highlightCurrentStep(tick: Int64) {
        let patternLength = Int64(stepCount) * ticksPerStep
        guard patternLength > 0 else { return }
        let currentStep = Int((tick % patternLength) / ticksPerStep)
        for (trackIdx, row) in stepButtons.enumerated() {
            for (stepIdx, button) in row.enumerated() {
                let active = isStepActive(trackIdx: trackIdx, stepIdx: stepIdx)
                if stepIdx == currentStep {
                    button.layer.borderColor = ChipsTheme.accentCyan.cgColor
                    button.layer.borderWidth = 2
                } else {
                    button.layer.borderColor = ChipsTheme.buttonStroke.cgColor
                    button.layer.borderWidth = 1
                }
                button.backgroundColor = active
                    ? ChipsTheme.trackColor(at: trackIdx)
                    : ChipsTheme.buttonGray
            }
        }
    }

    private func isStepActive(trackIdx: Int, stepIdx: Int) -> Bool {
        guard tracks.indices.contains(trackIdx),
              let pattern = tracks[trackIdx].patterns.first
        else { return false }
        let basePitches: [UInt8] = [60, 62, 64, 65, 67, 69]
        let startTick = Int64(stepIdx) * ticksPerStep
        return pattern.notes.contains { $0.startTick == startTick && $0.midi == basePitches[trackIdx] }
    }
}
