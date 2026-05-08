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
///
/// - Important: `stop()` debe llamarse antes de soltar la última referencia para
///   eliminar los observers de NotificationCenter. El `deinit` no puede hacerlo
///   porque es nonisolated y los observers son no-Sendable.
@MainActor
public final class ChipsAudioHost {
    public static let version = "0.1.0-m1"

    public let engine: ChipsEngine
    public private(set) var isRunning: Bool = false

    private let avEngine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private var renderScratch: UnsafeMutablePointer<Float>?
    private var renderScratchCapacity: Int = 0
    private var interruptionObserver: (any NSObjectProtocol)?
    private var routeChangeObserver: (any NSObjectProtocol)?
    private var configChangeObserver: (any NSObjectProtocol)?

    public init(sampleRate: Double = 48000, maxFrames: Int = 1024) throws {
        engine = try ChipsEngine(sampleRate: sampleRate, maxFrames: maxFrames)
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
        if let scratch = renderScratch {
            scratch.deallocate()
            renderScratch = nil
            renderScratchCapacity = 0
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
        // El graph interno de AVAudioEngine usa float32 non-interleaved (deinterleaved)
        // como formato canónico. Conectar un sourceNode con interleaved=true al
        // mainMixerNode falla con kAudioUnitErr_FormatNotSupported (-10868) en iOS.
        // Adoptamos el sample rate real del mainMixer (fallback al del engine si no
        // hay aún ruta resuelta) y usamos non-interleaved.
        let mixerFormat = avEngine.mainMixerNode.outputFormat(forBus: 0)
        let activeSampleRate = mixerFormat.sampleRate > 0 ? mixerFormat.sampleRate : engine.sampleRate

        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: activeSampleRate,
            channels: 2,
            interleaved: false
        ) else {
            throw ChipsAudioHostError.formatCreationFailed
        }

        // Scratch buffer para deinterleave: el motor C++ produce LRLR..., el
        // sourceNode espera buffers planos L y R. Pre-alocado para evitar
        // allocs en el render block (RT-safe).
        let scratchCapacity = 8192  // hasta 4096 frames * 2 channels
        if renderScratch == nil {
            renderScratch = UnsafeMutablePointer<Float>.allocate(capacity: scratchCapacity)
            renderScratchCapacity = scratchCapacity
        }
        guard let scratch = renderScratch else {
            throw ChipsAudioHostError.formatCreationFailed
        }
        let capacity = renderScratchCapacity
        let engineRef = engine
        let node = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList in
            let frames = Int(frameCount)
            guard frames > 0, frames * 2 <= capacity else {
                return noErr
            }
            engineRef.render(into: scratch, frames: frames)
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            if buffers.count >= 2,
               let lPtr = buffers[0].mData?.assumingMemoryBound(to: Float.self),
               let rPtr = buffers[1].mData?.assumingMemoryBound(to: Float.self) {
                for i in 0 ..< frames {
                    lPtr[i] = scratch[i * 2]
                    rPtr[i] = scratch[i * 2 + 1]
                }
            } else if buffers.count == 1,
                      let mono = buffers[0].mData?.assumingMemoryBound(to: Float.self) {
                // Output mono: mezcla L+R/2.
                for i in 0 ..< frames {
                    mono[i] = (scratch[i * 2] + scratch[i * 2 + 1]) * 0.5
                }
            }
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
            // Extraemos los valores Sendable (UInt) en este thread antes de
            // cruzar el boundary del MainActor. Notification.userInfo no es Sendable.
            let typeRaw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let optionsRaw = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
            MainActor.assumeIsolated {
                self?.handleInterruption(typeRaw: typeRaw, optionsRaw: optionsRaw)
            }
        }

        routeChangeObserver = center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: session,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleRouteChange()
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

    private func handleInterruption(typeRaw: UInt?, optionsRaw: UInt?) {
        guard let typeRaw, let type = AVAudioSession.InterruptionType(rawValue: typeRaw) else {
            return
        }
        switch type {
        case .began:
            // El sistema ya pausó el audio; aquí podríamos guardar estado.
            break
        case .ended:
            if let optionsRaw {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsRaw)
                if options.contains(.shouldResume) {
                    try? AVAudioSession.sharedInstance().setActive(true)
                }
            }
        @unknown default:
            break
        }
    }

    private func handleRouteChange() {
        // M1: stub. Manejo robusto de cambios de ruta llega en M2.
    }

    private func handleConfigurationChange() {
        // El grafo perdió validez (ej. cambio de hardware). Reiniciamos si hace falta.
        if !avEngine.isRunning {
            try? avEngine.start()
        }
    }
}
