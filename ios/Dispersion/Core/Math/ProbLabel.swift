// Maps a probability into a human label + palette-aware color. Views should
// pass the active palette from `@Environment(\.palette)`. The legacy
// `of(_:)` overload reads from the standard palette so existing call sites
// stay compiling — migrate them to `of(_:palette:)` when convenient.

import SwiftUI

public struct ProbLabel: Sendable {
    public let label: String
    public let color: Color
}

public enum ProbLabelRegistry {

    /// Palette-aware version — pass the active environment palette so the
    /// returned color reflects the user's chosen color theme.
    public static func of(_ p: Double, palette: Palette) -> ProbLabel {
        switch p {
        case 0.85...:        return ProbLabel(label: "Strong",   color: palette.pStrong)
        case 0.65..<0.85:    return ProbLabel(label: "Favored",  color: palette.pFavored)
        case 0.40..<0.65:    return ProbLabel(label: "Marginal", color: palette.pMarginal)
        default:             return ProbLabel(label: "Poor",     color: palette.pPoor)
        }
    }

    /// Legacy non-palette form — uses the standard palette. Kept so older
    /// call sites keep compiling; new code should pass the environment palette.
    public static func of(_ p: Double) -> ProbLabel {
        of(p, palette: Palettes.standard)
    }
}
