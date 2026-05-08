import Foundation

/// Páginas del onboarding mínimo. Una frase identitaria + una explicación
/// de qué hace cada superficie. Strings localizadas en `Localizable.xcstrings`
/// (en, es).
enum OnboardingPage: Int, CaseIterable {
    case welcome
    case sequencer
    case soundDesign
    case export

    var title: String {
        switch self {
        case .welcome: String(localized: "onboarding.welcome.title")
        case .sequencer: String(localized: "onboarding.sequencer.title")
        case .soundDesign: String(localized: "onboarding.sound_design.title")
        case .export: String(localized: "onboarding.export.title")
        }
    }

    var subtitle: String {
        switch self {
        case .welcome: String(localized: "onboarding.welcome.subtitle")
        case .sequencer: String(localized: "onboarding.sequencer.subtitle")
        case .soundDesign: String(localized: "onboarding.sound_design.subtitle")
        case .export: String(localized: "onboarding.export.subtitle")
        }
    }
}
