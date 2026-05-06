import AVFoundation
import ChipsEngine
import Foundation

public enum ChipsAudioHostError: Error {
    case formatCreationFailed
    case alreadyRunning
}

/// Host de audio para iOS: configura `AVAudioSession`, monta un `AVAudioSourceNode`
/// que delega en `ChipsEngine.render` y maneja interrupciones básicas.
///
/// La API pública está aislada al MainActor; el render block corre en el audio thread
/// y solo captura `ChipsEngine` (que es `@unchecked Sendable`).
@MainActor
public final class ChipsAudioHost {
    public static let version = "0.1.0-m1"

    public let engine: ChipsEngine
    public private(set) var isRunning: Bool = false

    private let avEngine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?
    private var configChangeObserver: NSObjectProtocol?

    public init(sampleRate: Double = 48000, maxFrames: Int = 1024) throws {
        engine = try ChipsEngine(sampleRate: sampleRate, maxFrames: maxFrames)
    }

    deinit {
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
        if let routeChangeObserver {
            NotificationCenter.default.removeObserver(routeChangeObserver)
        }
        if let configChangeObserver {
            NotificationCenter.default.removeObserver(configChangeObserver)
        }
    }

    /// Configura la session, monta el grafo y arranca AVAudioEngine.
    public func start(mixWithOthers: Bool = true) throws {
        guard !isRunning else { return }
        try configureSession(mixWithOthers: mixWithOthers)
        try installSourceNode()
        try avEngine.start()
        installObservers()
        isRunning = true
    }

    public func stop() {
        guard isRunning else { return }
        avEngine.stop()
        if let node = sourceNode {
            avEngine.detach(node)
            sourceNode = nil
        }
        removeObservers()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        isRunning = false
    }

    public var sampleRate: Double {
        AVAudioSession.sharedInstance().sampleRate
    }

    public var ioBufferDuration: TimeInterval {
        AVAudioSession.sharedInstance().ioBufferDuration
    }

    // MARK: Private

    private func configureSession(mixWithOthers: Bool) throws {
        let session = AVAudioSession.sharedInstance()
        var options: AVAudioSession.CategoryOptions = []
        if mixWithOthers {
            options.insert(.mixWithOthers)
        }
        try session.setCategory(.playback, mode: .default, options: options)
        try session.setPreferredSampleRate(engine.sampleRate)
        try session.setPreferredIOBufferDuration(256.0 / engine.sampleRate)
        try session.setActive(true)
    }

    private func installSourceNode() throws {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: engine.sampleRate,
            channels: 2,
            interleaved: true
        ) else {
            throw ChipsAudioHostError.formatCreationFailed
        }

        let engineRef = engine
        let node = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList in
            let bufferList = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let raw = bufferList[0].mData else {
                return noErr
            }
            let floats = raw.assumingMemoryBound(to: Float.self)
            engineRef.render(into: floats, frames: Int(frameCount))
            return noErr
        }
        sourceNode = node
        avEngine.attach(node)
        avEngine.connect(node, to: avEngine.mainMixerNode, format: format)
    }

    private func installObservers() {
        let center = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()

        interruptionObserver = center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                self?.handleInterruption(notification)
            }
        }

        routeChangeObserver = center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                self?.handleRouteChange(notification)
            }
        }

        configChangeObserver = center.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: avEngine,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleConfigurationChange()
            }
        }
    }

    private func removeObservers() {
        let center = NotificationCenter.default
        if let interruptionObserver {
            center.removeObserver(interruptionObserver)
            self.interruptionObserver = nil
        }
        if let routeChangeObserver {
            center.removeObserver(routeChangeObserver)
            self.routeChangeObserver = nil
        }
        if let configChangeObserver {
            center.removeObserver(configChangeObserver)
            self.configChangeObserver = nil
        }
    }

    private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else {
            return
        }
        switch type {
        case .began:
            // El sistema ya pausó el audio; aquí podríamos guardar estado.
            break
        case .ended:
            if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    try? AVAudioSession.sharedInstance().setActive(true)
                }
            }
        @unknown default:
            break
        }
    }

    private func handleRouteChange(_: Notification) {
        // M1: stub. Manejo robusto de cambios de ruta llega en M2.
    }

    private func handleConfigurationChange() {
        // El grafo perdió validez (ej. cambio de hardware). Reiniciamos si hace falta.
        if !avEngine.isRunning {
            try? avEngine.start()
        }
    }
}
