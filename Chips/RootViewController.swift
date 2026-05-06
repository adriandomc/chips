import ChipsAudioHost
import ChipsCore
import ChipsEngine
import ChipsMIDI
import ChipsModules
import ChipsUIKit
import UIKit

final class RootViewController: UIViewController {
    private let titleLabel = UILabel()
    private let playButton = UIButton(type: .system)
    private let statusLabel = UILabel()
    private let versionLabel = UILabel()

    private var audioHost: ChipsAudioHost?
    private var sineNodeId: ChipsNodeId?
    private var refreshTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1.0)

        titleLabel.text = "Chips"
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 56, weight: .heavy)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        playButton.setTitle("Play 440 Hz", for: .normal)
        playButton.setTitleColor(.white, for: .normal)
        playButton.titleLabel?.font = .monospacedSystemFont(ofSize: 18, weight: .semibold)
        playButton.backgroundColor = UIColor(red: 0.0, green: 0.5, blue: 0.93, alpha: 1.0)
        playButton.layer.cornerRadius = 12
        playButton.contentEdgeInsets = UIEdgeInsets(top: 14, left: 28, bottom: 14, right: 28)
        playButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.addTarget(self, action: #selector(togglePlay), for: .touchUpInside)

        statusLabel.text = "Stopped"
        statusLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        statusLabel.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        let versions = [
            "Core \(ChipsCore.version)",
            "Engine \(ChipsEngine.version)",
            "AudioHost \(ChipsAudioHost.version)",
            "MIDI \(ChipsMIDI.version)",
            "UIKit \(ChipsUIKit.version)",
            "Modules \(ChipsModules.version)",
        ].joined(separator: " · ")

        versionLabel.text = versions
        versionLabel.textColor = UIColor.white.withAlphaComponent(0.35)
        versionLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        versionLabel.textAlignment = .center
        versionLabel.numberOfLines = 0
        versionLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(titleLabel)
        view.addSubview(playButton)
        view.addSubview(statusLabel)
        view.addSubview(versionLabel)

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -80),

            playButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            playButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 36),

            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: playButton.bottomAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            versionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            versionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            versionLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
        ])
    }

    @objc private func togglePlay() {
        if audioHost?.isRunning == true {
            audioHost?.stop()
            stopRefreshTimer()
            playButton.setTitle("Play 440 Hz", for: .normal)
            statusLabel.text = "Stopped"
            return
        }

        do {
            let host = try audioHost ?? ChipsAudioHost(sampleRate: 48000, maxFrames: 1024)
            audioHost = host

            // Construir grafo: sine -> output (si todavía no existe).
            if sineNodeId == nil {
                guard let sine = host.engine.addNode(.sine) else {
                    statusLabel.text = "Error: addNode(.sine) falló"
                    return
                }
                host.engine.setOutputNode(sine)
                guard host.engine.compile() else {
                    statusLabel.text = "Error: compile() falló"
                    return
                }
                sineNodeId = sine
            }

            if let sine = sineNodeId {
                host.engine.setParameter(sine, sine: .frequency, value: 440)
                host.engine.setParameter(sine, sine: .amplitude, value: 0.25)
                host.engine.setParameter(sine, sine: .enabled, value: 1.0)
            }

            try host.start()
            playButton.setTitle("Stop", for: .normal)
            startRefreshTimer()
        } catch {
            statusLabel.text = "Error: \(error)"
        }
    }

    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshStatus()
            }
        }
    }

    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func refreshStatus() {
        guard let host = audioHost, host.isRunning else { return }
        let load = host.engine.dspLoad * 100
        let sampleRate = host.sampleRate
        let bufferMs = host.ioBufferDuration * 1000
        statusLabel.text = String(
            format: "Sine 440 Hz · DSP %.1f%% · %.0f Hz · buffer %.1f ms",
            load, sampleRate, bufferMs
        )
    }
}
