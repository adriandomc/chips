import UIKit

/// Sistema de tema de Chips. Colores y fuentes basados en los mockups del usuario.
public enum ChipsTheme {
    // MARK: Shell

    public static let topBarBackground = UIColor(red: 0.71, green: 0.69, blue: 0.84, alpha: 1.0)
    public static let topBarStroke = UIColor(red: 0.50, green: 0.48, blue: 0.62, alpha: 1.0)
    public static let sidebarBackground = UIColor(red: 0.47, green: 0.47, blue: 0.47, alpha: 1.0)
    public static let sidebarStroke = UIColor(red: 0.32, green: 0.32, blue: 0.32, alpha: 1.0)
    public static let contentBackground = UIColor(red: 0.91, green: 0.91, blue: 0.91, alpha: 1.0)

    // MARK: Paneles

    public static let panelGray = UIColor(red: 0.55, green: 0.55, blue: 0.55, alpha: 1.0)
    public static let panelGrayLight = UIColor(red: 0.78, green: 0.78, blue: 0.78, alpha: 1.0)
    public static let panelStroke = UIColor(red: 0.36, green: 0.36, blue: 0.36, alpha: 1.0)
    public static let panelDivider = UIColor(red: 0.42, green: 0.42, blue: 0.42, alpha: 1.0)

    // MARK: Botones

    public static let buttonGray = UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1.0)
    public static let buttonGrayPressed = UIColor(red: 0.70, green: 0.70, blue: 0.70, alpha: 1.0)
    public static let buttonStroke = UIColor(red: 0.20, green: 0.20, blue: 0.20, alpha: 1.0)
    public static let buttonText = UIColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1.0)

    // MARK: Acento

    public static let accentCyan = UIColor(red: 0.36, green: 0.75, blue: 0.83, alpha: 1.0)
    public static let accentTeal = UIColor(red: 0.30, green: 0.65, blue: 0.65, alpha: 1.0)
    public static let accentYellow = UIColor(red: 0.95, green: 0.92, blue: 0.45, alpha: 1.0)

    // MARK: Transporte

    public static let transportGreen = UIColor(red: 0.42, green: 0.85, blue: 0.42, alpha: 1.0)
    public static let transportGreenStroke = UIColor(red: 0.20, green: 0.55, blue: 0.20, alpha: 1.0)
    public static let transportRed = UIColor(red: 0.95, green: 0.30, blue: 0.30, alpha: 1.0)
    public static let transportRedStroke = UIColor(red: 0.65, green: 0.15, blue: 0.15, alpha: 1.0)

    // MARK: Texto

    public static let textPrimary = UIColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1.0)
    public static let textSecondary = UIColor(red: 0.35, green: 0.35, blue: 0.35, alpha: 1.0)
    public static let textOnDark = UIColor.white
    public static let displayBackground = UIColor.white
    public static let displayBackgroundDark = UIColor(red: 0.92, green: 0.92, blue: 0.92, alpha: 1.0)

    // MARK: Pista (paleta pastel del mockup, secuencial)

    public static let trackPalette: [UIColor] = [
        UIColor(red: 1.00, green: 0.71, blue: 0.71, alpha: 1.0), // pink
        UIColor(red: 1.00, green: 0.99, blue: 0.77, alpha: 1.0), // cream
        UIColor(red: 0.71, green: 1.00, blue: 0.77, alpha: 1.0), // mint
        UIColor(red: 0.71, green: 1.00, blue: 0.98, alpha: 1.0), // cyan
        UIColor(red: 0.71, green: 0.73, blue: 1.00, alpha: 1.0), // lavender
        UIColor(red: 1.00, green: 0.71, blue: 0.85, alpha: 1.0), // hot pink
        UIColor(red: 1.00, green: 0.85, blue: 0.71, alpha: 1.0), // peach
        UIColor(red: 0.85, green: 1.00, blue: 0.71, alpha: 1.0), // chartreuse
        UIColor(red: 0.93, green: 0.78, blue: 1.00, alpha: 1.0), // lilac
        UIColor(red: 0.71, green: 0.92, blue: 1.00, alpha: 1.0), // sky
    ]

    public static func trackColor(at index: Int) -> UIColor {
        trackPalette[((index % trackPalette.count) + trackPalette.count) % trackPalette.count]
    }

    // MARK: Fuentes

    public enum Font {
        public static func display(size: CGFloat) -> UIFont {
            UIFont.monospacedSystemFont(ofSize: size, weight: .semibold)
        }

        public static func mono(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
            UIFont.monospacedSystemFont(ofSize: size, weight: weight)
        }

        public static func body(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
            UIFont.systemFont(ofSize: size, weight: weight)
        }

        public static func label(size: CGFloat) -> UIFont {
            UIFont.systemFont(ofSize: size, weight: .medium)
        }
    }
}
