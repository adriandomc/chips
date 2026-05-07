import Foundation
import StoreKit

/// Estado de la entitlement del usuario para Chips. v1.0 es paid-up-front:
/// el usuario obtiene la app tras comprarla y no hay IAP. Este manager existe
/// para (1) verificar el `AppTransaction` (recibo de compra) cuando estamos en
/// builds de TestFlight/App Store, (2) ofrecer `restorePurchases()` como
/// requiere Apple, y (3) servir como punto de extensión cuando se añadan IAPs
/// post-1.0 (packs de presets, instrumentos extra, etc.).
@MainActor
final class EntitlementManager {
    static let shared = EntitlementManager()

    /// `true` si el usuario tiene derecho a usar la app. Para v1.0:
    /// - En builds de App Store/TestFlight: `true` si `AppTransaction` valida.
    /// - En builds de DEBUG: siempre `true` (desarrollo local).
    private(set) var isEntitled: Bool = false
    private(set) var lastVerification: Date?

    private init() {
        #if DEBUG
        isEntitled = true
        #endif
    }

    /// Llamar al boot. Verifica el `AppTransaction` (recibo de compra original).
    /// No bloquea — falla silenciosamente y deja `isEntitled = false` si no hay
    /// recibo válido. La UI puede consultar `isEntitled` después.
    func bootstrap() async {
        #if DEBUG
        isEntitled = true
        return
        #else
        await verifyAppTransaction()
        #endif
    }

    /// Restore Purchases. Para paid-up-front efectivamente fuerza una resync
    /// con el App Store y revalida `AppTransaction`. Apple requiere ofrecerlo
    /// en el UI aunque no haya IAPs (Guideline 3.1.1).
    func restorePurchases() async throws {
        try await AppStore.sync()
        await verifyAppTransaction()
    }

    private func verifyAppTransaction() async {
        do {
            let result = try await AppTransaction.shared
            switch result {
            case .verified:
                isEntitled = true
                lastVerification = Date()
            case .unverified:
                isEntitled = false
            }
        } catch {
            isEntitled = false
        }
    }
}
