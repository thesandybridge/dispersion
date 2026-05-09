// Port of `LIE_TYPES`, `lieMultiplier`, `effectiveDistance` from
// app/src/lib/scenarioStore.ts. These are pure functions; the *state* part of
// scenarioStore lives under Core/Stores/ScenarioStore.swift.

import Foundation

public enum LieType: String, CaseIterable, Sendable {
    case tee
    case fairway
    case lightRough = "light-rough"
    case rough
    case sand
    case hardpan

    public var label: String {
        switch self {
        case .tee: return "Tee"
        case .fairway: return "Fairway"
        case .lightRough: return "Light rough"
        case .rough: return "Rough"
        case .sand: return "Sand"
        case .hardpan: return "Hardpan"
        }
    }

    /// Hand-tuned default σ multiplier — applied to a club's stored
    /// carrySd / lateralSd to model looser dispersion from worse lies.
    ///
    /// These are not from a published study. The ordering is defensible
    /// (rough > light rough > hardpan ≥ fairway, sand widest), but the
    /// exact magnitudes are estimates. The player can override them in
    /// Settings; `LieMultiplierStore.shared.multiplier(for:)` is the
    /// runtime source of truth for the calculator.
    public var defaultSigmaMultiplier: Double {
        switch self {
        case .tee:        return 1.00
        case .fairway:    return 1.00
        case .lightRough: return 1.25
        case .rough:      return 1.55
        case .sand:       return 1.85
        case .hardpan:    return 1.20
        }
    }

    /// Reasonable bounds for user overrides — keeps a slider sensible.
    public static let multiplierRange: ClosedRange<Double> = 0.7...3.0
}

public enum Conditions {
    /// Adjust target distance for wind & elevation (linear approximations).
    /// - Tailwind (positive `windMph`) shortens the *playing* distance.
    /// - Uphill (positive `elevationFt`) lengthens the playing distance.
    ///
    /// Defaults are 1 yard per mph and 1 yard per foot — common rules of
    /// thumb that roughly fit a mid-iron. The view layer can pass the
    /// user's tuned values from `CalculatorTuningStore` to override.
    public static func effectiveDistance(
        target: Double,
        windMph: Double,
        elevationFt: Double,
        windYardsPerMph: Double = 1.0,
        elevYardsPerFoot: Double = 1.0
    ) -> Double {
        let windAdj = -windMph * windYardsPerMph
        let elevAdj = elevationFt * elevYardsPerFoot
        return max(0, target + windAdj + elevAdj)
    }

    /// Default σ multiplier — does NOT consult the user override store.
    /// Use `LieMultiplierStore.shared.multiplier(for:)` from view code.
    public static func defaultSigmaMultiplier(for lie: LieType) -> Double {
        lie.defaultSigmaMultiplier
    }
}
