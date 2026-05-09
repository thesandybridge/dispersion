// Centralized magic numbers. Each constant has a comment explaining its
// origin and purpose so future tuning is grounded.

import Foundation

public enum AppConfig {

    // MARK: Shot data

    /// Longitudinal/lateral delta beyond which a recorded shot is treated as
    /// noise (mis-tap, calibration error, accidental tap on the radar).
    /// Real-world golf shots rarely deviate >100 yards from target — anything
    /// outside this is almost certainly bad data, not a real outlier.
    public static let shotOutlierYards: Double = 100

    /// Filters a shot collection down to records that look like real shots.
    public static func validShots<S: Sequence>(_ shots: S) -> [Shot] where S.Element == Shot {
        shots.filter { abs($0.longDelta) < shotOutlierYards && abs($0.latDelta) < shotOutlierYards }
    }

    // MARK: Statistics windows

    /// Rolling window of recent sessions used for sigma trend visualizations.
    public static let sigmaTrendSessions: Int = 8

    /// DECADE-style "recent shots" window for per-club dispersion. 20 shots is
    /// what the DECADE methodology recommends for stable sigma estimates.
    public static let recentShotsForDispersion: Int = 20

    /// Minimum shots before showing strokes-gained aggregates.
    public static let minShotsForSGAggregate: Int = 2

    /// Minimum shots before showing per-club strokes-gained breakdown.
    public static let minShotsForClubSG: Int = 3

    // MARK: Time windows

    /// "Recent activity" window in days, used for last-30-days counters.
    public static let recentActivityDays: Int = 30

    // MARK: Geo / GPS

    /// On-target threshold in yards — shots inside this band are flagged
    /// "on target" rather than long/short/left/right.
    public static let onTargetYards: Double = 3

    /// Map search radius (meters) when searching golf courses by name with
    /// the user's current location as an anchor.
    public static let courseSearchRadiusMeters: Double = 100_000

    /// Map search radius (meters) when "search nearby" is invoked without a
    /// query — we want a tighter radius so users get only nearby results.
    public static let courseNearbyRadiusMeters: Double = 30_000

    /// Network timeout for course searches, beyond which we surface a
    /// "search timed out" error and let the user retry.
    public static let courseSearchTimeout: Duration = .seconds(12)

    // MARK: Calibration

    /// Minimum sample size before a calibration save is even allowed.
    public static let minShotsToCalibrate: Int = 2

    /// Sample size at which calibration confidence becomes "good" — enough
    /// data that the measured σ is reasonably trustworthy.
    public static let goodCalibrationSize: Int = 10

    /// Sample size at which calibration confidence becomes "high" — DECADE
    /// recommends ~30 shots for tight confidence intervals.
    public static let highCalibrationSize: Int = 30
}

public enum CalibrationConfidence: String {
    case insufficient   // < minShotsToCalibrate
    case low            // < goodCalibrationSize
    case good           // < highCalibrationSize
    case high           // >= highCalibrationSize

    public var label: String {
        switch self {
        case .insufficient: return "Need more shots"
        case .low:          return "Low confidence"
        case .good:         return "Good"
        case .high:         return "High confidence"
        }
    }

    public var description: String {
        switch self {
        case .insufficient: return "Log at least \(AppConfig.minShotsToCalibrate) shots."
        case .low:          return "Aim for \(AppConfig.goodCalibrationSize)+ shots before saving."
        case .good:         return "Reliable enough to save."
        case .high:         return "Tour-quality sample size."
        }
    }

    public static func from(shotCount n: Int) -> CalibrationConfidence {
        if n < AppConfig.minShotsToCalibrate { return .insufficient }
        if n < AppConfig.goodCalibrationSize { return .low }
        if n < AppConfig.highCalibrationSize { return .good }
        return .high
    }
}

