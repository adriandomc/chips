import Foundation

/// Páginas del onboarding mínimo. El copy es deliberadamente corto: una
/// frase identitaria + una explicación de qué hace cada superficie.
/// Todo en inglés por ahora; localizar en la PR de i18n (M11-C).
enum OnboardingPage: Int, CaseIterable {
    case welcome
    case sequencer
    case soundDesign
    case export

    var title: String {
        switch self {
        case .welcome: "Welcome to Chips"
        case .sequencer: "Sequence"
        case .soundDesign: "Sound design"
        case .export: "Ship it"
        }
    }

    var subtitle: String {
        switch self {
        case .welcome:
            "A modular DAW built for iPhone & iPad. Instruments, effects, sequencer, mixer — without slot limits."
        case .sequencer:
            "Tap the grid to draw notes. Patterns chain into songs. Tempo, swing and quantize in one place."
        case .soundDesign:
            "Each instrument exposes its own knobs. The mixer routes everything to stereo with gain, pan and mute per channel."
        case .export:
            "Bounce to WAV, save your project as .chips, share it. Made on your phone, ready to release."
        }
    }
}
