import Foundation

/// Estado del onboarding (mostrar / no mostrar al primer launch). Persiste
/// un flag en `UserDefaults`; si el usuario reinstala o resetea, vuelve a
/// salir el onboarding.
@MainActor
enum OnboardingState {
    private static let completedKey = "com.adriandomc.chips.onboarding.completedVersion"
    /// Bumpear cuando el onboarding cambie sustancialmente y queramos re-mostrarlo
    /// a usuarios existentes (por ejemplo nuevas pantallas que enseñen features
    /// post-1.0).
    static let currentVersion: Int = 1

    static var hasCompleted: Bool {
        UserDefaults.standard.integer(forKey: completedKey) >= currentVersion
    }

    static func markCompleted() {
        UserDefaults.standard.set(currentVersion, forKey: completedKey)
    }

    /// Para tests y reset desde ajustes (post-1.0 quizá).
    static func reset() {
        UserDefaults.standard.removeObject(forKey: completedKey)
    }
}
