import ChipsAudioHost
import ChipsUIKit
import UIKit

// HUD overlay diminuto que muestra DSP load, sample rate y buffer size.
// Solo se compila en builds DEBUG — en Release no existe la clase.
//
// Polling: lee `engine.dspLoad` cada 200 ms (5 Hz suficiente para sentir
// picos sin gastar CPU). El cálculo es lock-free, devuelve un float que
// el audio thread escribió.
//
// Tap → toggles ocultar/mostrar (por si molesta durante una grabación).
#if DEBUG
@MainActor
final class DebugHUDView: UIView {
    private let host: ChipsAudioHost
    private let label = UILabel()
    private var timer: Timer?
    private var isCollapsed = false

    init(host: ChipsAudioHost) {
        self.host = host
        super.init(frame: .zero)
        backgroundColor = ChipsTheme.textPrimary.withAlphaComponent(0.78)
        layer.cornerRadius = 4
        translatesAutoresizingMaskIntoConstraints = false

        label.font = ChipsTheme.Font.mono(size: 10, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),
        ])
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
        isAccessibilityElement = true
        accessibilityLabel = "Debug HUD"
        accessibilityHint = "DSP load, sample rate and buffer size"
        update()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("DebugHUDView no soporta NSCoder")
    }

    func startPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.update() }
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        // Timer se invalida cuando se libera la vista (el closure tiene weak self).
    }

    @objc private func tapped() {
        isCollapsed.toggle()
        label.isHidden = isCollapsed
        update()
    }

    private func update() {
        if isCollapsed {
            label.text = "•"
            return
        }
        let load = host.engine.dspLoad * 100
        let sr = Int(host.sampleRate / 1000)
        let bufFrames = Int((host.ioBufferDuration * host.sampleRate).rounded())
        label.text = String(format: "DSP %4.1f%%  %dkHz  %d", load, sr, bufFrames)
    }
}
#endif
