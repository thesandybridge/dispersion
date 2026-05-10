// User-tunable knobs for the calculator's probability + distance math.
// Defaults are the values currently hardcoded in the math layer; the player
// can override them in Settings.
//
// Why a separate store from `SettingsStore`: these are *mathematical* tunings
// (wind multiplier, short-side penalty, etc.) that the calculator passes
// into pure functions in `Probability` and `Conditions`. Keeping them out
// of the general app-settings store makes the surface explicit and
// self-documenting.

import Foundation
import Observation

@MainActor
@Observable
public final class CalculatorTuningStore {
    public static let shared = CalculatorTuningStore()

    /// Yards of playing-distance change per mph of wind. Tailwind shortens,
    /// headwind lengthens. The clubhouse rule of thumb is 1 yard per mph
    /// for a mid-iron; players who play primarily in coastal wind tune
    /// higher, players in mountain altitude usually tune lower.
    public var windYardsPerMph: Double = 1.0
    public static let windRange: ClosedRange<Double> = 0.5...2.0

    /// Yards of playing-distance change per foot of elevation. Uphill plays
    /// longer, downhill plays shorter. Same caveat — depends on club.
    public var elevYardsPerFoot: Double = 1.0
    public static let elevRange: ClosedRange<Double> = 0.5...2.0

    /// Coefficient in the short-side penalty: a club whose expected carry
    /// is short of the target gets a multiplier of `exp(-bias × shortness)`
    /// applied to its probability. 0 disables the bias entirely; higher
    /// values aggressively prefer clubs that carry to or past the target.
    public var shortSideBias: Double = 0.08
    public static let biasRange: ClosedRange<Double> = 0.0...0.20

    /// Beyond this delta a shot is treated as bad data and filtered before
    /// any σ / SG calculation. Default matches `AppConfig.shotOutlierYards`.
    public var shotOutlierYards: Double = 100
    public static let outlierRange: ClosedRange<Double> = 50...200

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let wind = "tuning.windYardsPerMph"
        static let elev = "tuning.elevYardsPerFoot"
        static let bias = "tuning.shortSideBias"
        static let outlier = "tuning.shotOutlierYards"
    }

    public init() { load() }

    private func load() {
        if let v = numberValue(Keys.wind) { windYardsPerMph = v }
        if let v = numberValue(Keys.elev) { elevYardsPerFoot = v }
        if let v = numberValue(Keys.bias) { shortSideBias = v }
        if let v = numberValue(Keys.outlier) { shotOutlierYards = v }
    }

    private func numberValue(_ key: String) -> Double? {
        guard defaults.object(forKey: key) != nil else { return nil }
        return defaults.double(forKey: key)
    }

    public func setWindYardsPerMph(_ v: Double) {
        windYardsPerMph = clamp(v, in: Self.windRange)
        defaults.set(windYardsPerMph, forKey: Keys.wind)
    }

    public func setElevYardsPerFoot(_ v: Double) {
        elevYardsPerFoot = clamp(v, in: Self.elevRange)
        defaults.set(elevYardsPerFoot, forKey: Keys.elev)
    }

    public func setShortSideBias(_ v: Double) {
        shortSideBias = clamp(v, in: Self.biasRange)
        defaults.set(shortSideBias, forKey: Keys.bias)
    }

    public func setShotOutlierYards(_ v: Double) {
        shotOutlierYards = clamp(v, in: Self.outlierRange)
        defaults.set(shotOutlierYards, forKey: Keys.outlier)
    }

    public func resetAll() {
        windYardsPerMph = 1.0
        elevYardsPerFoot = 1.0
        shortSideBias = 0.08
        shotOutlierYards = 100
        for k in [Keys.wind, Keys.elev, Keys.bias, Keys.outlier] {
            defaults.removeObject(forKey: k)
        }
    }

    public var hasOverrides: Bool {
        windYardsPerMph != 1.0
            || elevYardsPerFoot != 1.0
            || shortSideBias != 0.08
            || shotOutlierYards != 100
    }

    private func clamp(_ v: Double, in range: ClosedRange<Double>) -> Double {
        max(range.lowerBound, min(v, range.upperBound))
    }
}
