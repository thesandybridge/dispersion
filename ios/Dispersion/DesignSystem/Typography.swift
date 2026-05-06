// Type system. The Tauri build uses Fraunces (display), Inter (sans),
// JetBrains Mono. iOS ships with system fonts that get us 90% there:
//
//   - `.serif` design + heavy weight + tight tracking ≈ Fraunces vibe.
//   - `.default` (San Francisco) replaces Inter.
//   - `.monospaced` (SF Mono) replaces JetBrains Mono.
//
// If the team wants the literal Fraunces face, drop the .ttf into Resources/
// and register it via Info.plist (see README); switch DispersionType.display
// to `.custom("Fraunces", ...)`.

import SwiftUI

public enum DispersionType {
    /// Editorial display face. Use for hero numbers and screen titles.
    public static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight, design: .serif)
    }

    /// UI sans. Default body text, controls, labels.
    public static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight, design: .default)
    }

    /// Monospace. Use for tabular numbers, eyebrows, metrics.
    public static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: Editorial helpers — port of the .eyebrow / .headline utilities.

public struct EyebrowStyle: ViewModifier {
    public var color: Color = DesignTokens.mutedForeground

    public func body(content: Content) -> some View {
        content
            .font(DispersionType.mono(10, weight: .medium))
            .tracking(2.2)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

public struct HeadlineStyle: ViewModifier {
    public var size: CGFloat
    public var weight: Font.Weight

    public func body(content: Content) -> some View {
        content
            .font(DispersionType.display(size, weight: weight))
            .tracking(-size * 0.025) // approximate -0.025em
            .lineSpacing(0)
    }
}

public extension View {
    func eyebrow(color: Color = DesignTokens.mutedForeground) -> some View {
        modifier(EyebrowStyle(color: color))
    }

    func headline(_ size: CGFloat, weight: Font.Weight = .regular) -> some View {
        modifier(HeadlineStyle(size: size, weight: weight))
    }

    /// Tabular figures.
    func tabularNumbers() -> some View {
        monospacedDigit()
    }
}
