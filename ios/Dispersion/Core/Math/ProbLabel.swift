// Port of app/src/lib/probLabel.ts. Maps a probability into a human label +
// the design-token color used to render it.

import SwiftUI

public struct ProbLabel: Sendable {
    public let label: String
    /// Hex string version, kept for debugging/snapshots.
    public let hex: String
    public let color: Color
}

public enum ProbLabelRegistry {
    public static func of(_ p: Double) -> ProbLabel {
        switch p {
        case 0.85...:        return ProbLabel(label: "Strong",   hex: "#62b375", color: DesignTokens.pStrong)
        case 0.65..<0.85:    return ProbLabel(label: "Favored",  hex: "#a9d18e", color: DesignTokens.pFavored)
        case 0.40..<0.65:    return ProbLabel(label: "Marginal", hex: "#e6c068", color: DesignTokens.pMarginal)
        default:             return ProbLabel(label: "Poor",     hex: "#c87060", color: DesignTokens.pPoor)
        }
    }
}
