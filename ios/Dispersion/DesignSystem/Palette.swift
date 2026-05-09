// Mode-aware semantic color palette. The four sets of colors below all
// convey the same information (probability "good → bad", status "ok / warn",
// heat-mapped probability contours), but use hue/lightness combinations that
// remain distinguishable under different forms of color-vision deficiency.
//
// The active palette is injected via `\.palette` environment, set at
// RootShell from `SettingsStore.colorBlindMode`. Views that paint
// status-significant color (probability labels, score deltas, contour heat)
// should read from the environment rather than `DesignTokens.X` directly.
//
// Why we don't try to be clever inside DesignTokens: those statics resolve
// once and don't propagate SwiftUI dependency. Going through the environment
// keeps the dependency graph honest.

import SwiftUI

public struct Palette: Sendable {
    // Probability label gradient — best to worst
    public let pStrong: Color
    public let pFavored: Color
    public let pMarginal: Color
    public let pPoor: Color
    public let danger: Color

    // Status accents
    public let primary: Color       // "good" / accent of the moment
    public let destructive: Color   // "bad" / error
    public let flag: Color          // golf flag pin color

    // Heat-mapped contour palette, outermost → innermost
    public let heat0: Color
    public let heat1: Color
    public let heat2: Color
    public let heat3: Color
    public let heat4: Color
    public let heat5: Color

    /// Convenience array for the heat palette, indexed by ring (0 = outermost).
    public var heatRamp: [Color] {
        [heat0, heat1, heat2, heat3, heat4, heat5]
    }
}

public enum Palettes {

    /// Default green/red traffic-light palette. Looks great, fails for the
    /// ~8% of men who are red-green deficient.
    public static let standard = Palette(
        pStrong:     hex("#62b375"),
        pFavored:    hex("#a9d18e"),
        pMarginal:   hex("#e6c068"),
        pPoor:       hex("#c87060"),
        danger:      hex("#a23939"),
        primary:     DesignTokens.primary,
        destructive: DesignTokens.destructive,
        flag:        hex("#e85d4d"),
        heat0:       hex("#0b3d2e"),
        heat1:       hex("#16624a"),
        heat2:       hex("#2c8a5e"),
        heat3:       hex("#62b375"),
        heat4:       hex("#a9d18e"),
        heat5:       hex("#f0e7b8")
    )

    /// Red-green safe — works for deuteranopia and protanopia. Uses an
    /// Okabe-Ito-inspired blue → cyan → yellow → orange → vermillion gradient
    /// that stays distinguishable across red-green deficiencies. The flag
    /// shifts from red to vermillion (still hot, still readable) and primary
    /// shifts to a high-contrast blue.
    public static let redGreenSafe = Palette(
        pStrong:     hex("#0072b2"),  // deep blue
        pFavored:    hex("#56b4e9"),  // sky blue
        pMarginal:   hex("#f0e442"),  // yellow
        pPoor:       hex("#e69f00"),  // orange
        danger:      hex("#d55e00"),  // vermillion
        primary:     hex("#0072b2"),
        destructive: hex("#d55e00"),
        flag:        hex("#d55e00"),
        heat0:       hex("#003049"),  // navy
        heat1:       hex("#005f87"),
        heat2:       hex("#0098c8"),  // cyan
        heat3:       hex("#90b8d9"),
        heat4:       hex("#f0c878"),
        heat5:       hex("#f0e442")   // yellow
    )

    /// Blue-yellow safe — for tritanopia. Avoids blue/yellow contrasts.
    /// Uses red → pink → gray → teal → dark teal for the probability axis.
    public static let blueYellowSafe = Palette(
        pStrong:     hex("#13855c"),  // teal-green (still a hot key but no yellow alongside)
        pFavored:    hex("#7fb069"),
        pMarginal:   hex("#9c9b91"),  // neutral gray
        pPoor:       hex("#d6604d"),  // pink-red
        danger:      hex("#a50026"),  // deep crimson
        primary:     hex("#13855c"),
        destructive: hex("#a50026"),
        flag:        hex("#a50026"),
        heat0:       hex("#0f3b3b"),
        heat1:       hex("#1f655a"),
        heat2:       hex("#2c8a5e"),
        heat3:       hex("#9c9b91"),  // neutral midpoint
        heat4:       hex("#d6604d"),
        heat5:       hex("#fbe1cd")
    )

    @MainActor
    public static func resolve(_ mode: PaletteMode) -> Palette {
        switch mode {
        case .standard:        return standard
        case .redGreenSafe:    return redGreenSafe
        case .blueYellowSafe:  return blueYellowSafe
        case .custom:          return CustomPaletteStore.shared.resolved()
        }
    }
}

// MARK: - Environment

private struct PaletteKey: EnvironmentKey {
    static let defaultValue: Palette = Palettes.standard
}

public extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

public extension View {
    /// Inject a palette into the environment. RootShell calls this with
    /// the user's preferred palette from SettingsStore.
    func palette(_ palette: Palette) -> some View {
        environment(\.palette, palette)
    }
}
