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

    /// σ multiplier — applied to a club's stored carrySd / lateralSd to model
    /// looser dispersion from worse lies.
    public var sigmaMultiplier: Double {
        switch self {
        case .tee:        return 1.00
        case .fairway:    return 1.00
        case .lightRough: return 1.25
        case .rough:      return 1.55
        case .sand:       return 1.85
        case .hardpan:    return 1.20
        }
    }
}

public enum Conditions {
    /// Adjust target distance for wind & elevation (linear approximations
    /// matching the JS implementation).
    /// - Tailwind (positive `windMph`) shortens the *playing* distance.
    /// - Uphill (positive `elevationFt`) lengthens the playing distance.
    public static func effectiveDistance(
        target: Double,
        windMph: Double,
        elevationFt: Double
    ) -> Double {
        // Linear: ~1y per mph wind, ~1y per ft elevation.
        let windAdj = -windMph
        let elevAdj = elevationFt
        return max(0, target + windAdj + elevAdj)
    }

    public static func sigmaMultiplier(for lie: LieType) -> Double { lie.sigmaMultiplier }
}
