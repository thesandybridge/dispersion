// Mirror of the Tailwind @theme tokens in app/src/index.css. Stays in pure
// Swift so the design system is reachable from previews and tests without an
// asset catalog.

import SwiftUI

public enum DesignTokens {
    // Brand palette
    public static let fairway50      = hex("#f4efe3")
    public static let bentgrass      = hex("#62b375")
    public static let fairwayShadow  = hex("#2c8a5e")
    public static let rough          = hex("#16624a")
    public static let pine           = hex("#0b3d2e")
    public static let soil900        = hex("#1a2419")
    public static let sand           = hex("#f0e7b8")
    public static let flag           = hex("#e85d4d")
    public static let water          = hex("#1f3a5f")
    public static let ink            = hex("#0e1a13")
    public static let cream          = hex("#f6f1e1")

    // Probability heatmap
    public static let heat0 = hex("#0b3d2e")
    public static let heat1 = hex("#16624a")
    public static let heat2 = hex("#2c8a5e")
    public static let heat3 = hex("#62b375")
    public static let heat4 = hex("#a9d18e")
    public static let heat5 = hex("#f0e7b8")

    // Probability label palette
    public static let pStrong   = hex("#62b375")
    public static let pFavored  = hex("#a9d18e")
    public static let pMarginal = hex("#e6c068")
    public static let pPoor     = hex("#c87060")
    public static let danger    = hex("#a23939")

    // Semantic (dark default)
    public static let background          = hex("#0e1a13")
    public static let backgroundDeep      = hex("#070d0a")
    public static let foreground          = hex("#f6f1e1")
    public static let card                = hex("#16201a")
    public static let cardForeground      = hex("#f6f1e1")
    public static let popover             = hex("#1a2419")
    public static let primary             = hex("#a9d18e")
    public static let primaryForeground   = hex("#0a1410")
    public static let secondary           = hex("#1f2a23")
    public static let secondaryForeground = hex("#f6f1e1")
    public static let muted               = hex("#1a2419")
    public static let accent              = hex("#62b375")
    public static let accentForeground    = hex("#0a1410")
    public static let destructive         = hex("#e85d4d")

    // Translucent system used for hairlines, surface tiers
    public static let border               = Color.white.opacity(0.10)
    public static let borderStrong         = Color.white.opacity(0.18)
    public static let surface              = Color.white.opacity(0.04)
    public static let surfaceStrong        = Color.white.opacity(0.07)
    public static let mutedForeground      = Color.white.opacity(0.55)
    public static let subtleForeground     = Color.white.opacity(0.40)

    public enum Radius {
        public static let sm: CGFloat = 6
        public static let md: CGFloat = 10
        public static let lg: CGFloat = 14
        public static let xl: CGFloat = 20
        public static let xxl: CGFloat = 28
    }
}

// MARK: Theme accent environment

private struct ThemeAccentKey: EnvironmentKey {
    static let defaultValue: Color = DesignTokens.primary
}

public extension EnvironmentValues {
    var themeAccent: Color {
        get { self[ThemeAccentKey.self] }
        set { self[ThemeAccentKey.self] = newValue }
    }
}

public extension View {
    func themeAccent(_ color: Color) -> some View {
        environment(\.themeAccent, color)
            .tint(color)
    }
}

// MARK: Themed card background

public struct ThemedCardFill: View {
    @Environment(\.themeAccent) private var accent
    var cornerRadius: CGFloat
    var opacity: Double

    public init(cornerRadius: CGFloat = 16, opacity: Double = 1) {
        self.cornerRadius = cornerRadius
        self.opacity = opacity
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        accent.opacity(0.12 * opacity),
                        DesignTokens.card.opacity(opacity)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(accent.opacity(0.08), lineWidth: 1)
            )
    }
}

// MARK: Hex helper

func hex(_ s: String) -> Color {
    var trimmed = s
    if trimmed.hasPrefix("#") { trimmed.removeFirst() }
    let scanner = Scanner(string: trimmed)
    var rgb: UInt64 = 0
    scanner.scanHexInt64(&rgb)
    let r = Double((rgb & 0xFF0000) >> 16) / 255.0
    let g = Double((rgb & 0x00FF00) >> 8) / 255.0
    let b = Double(rgb & 0x0000FF) / 255.0
    return Color(red: r, green: g, blue: b)
}
