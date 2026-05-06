// Port of app/src/lib/units.ts. Yards is the canonical internal unit; UI
// converts at the boundary based on user preference.

import Foundation

public enum DistanceUnit: String, Codable, CaseIterable, Sendable {
    case yards
    case meters

    public var label: String {
        switch self {
        case .yards: return "yd"
        case .meters: return "m"
        }
    }
}

public enum Units {
    /// Convert yards to display unit.
    public static func from(yards: Double, in unit: DistanceUnit) -> Double {
        switch unit {
        case .yards: return yards
        case .meters: return yards * 0.9144
        }
    }

    /// Convert a value in display unit back to yards.
    public static func toYards(_ value: Double, from unit: DistanceUnit) -> Double {
        switch unit {
        case .yards: return value
        case .meters: return value / 0.9144
        }
    }

    /// Round to a sensible precision for the unit (yards: int; meters: 0.5).
    public static func roundForUnit(_ v: Double, unit: DistanceUnit) -> Double {
        switch unit {
        case .yards: return v.rounded()
        case .meters: return (v * 2).rounded() / 2
        }
    }
}
