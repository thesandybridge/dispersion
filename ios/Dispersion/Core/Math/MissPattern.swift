// Analyzes a club's logged shots to determine miss tendencies.
// Feeds the club detail miss breakdown and the aim recommendation.

import Foundation

public struct MissAnalysis: Equatable {
    public var totalShots: Int
    public var avgLongDelta: Double    // positive = long, negative = short
    public var avgLatDelta: Double     // positive = right, negative = left
    public var pctShort: Double
    public var pctLong: Double
    public var pctLeft: Double
    public var pctRight: Double
    public var pctInZone: Double
    public var dominantMiss: String    // e.g. "short-left", "right", "centered"
    /// Recommended aim offset in yards to compensate for bias.
    public var aimOffsetLat: Double    // negative = aim left to compensate right miss
    public var aimOffsetLong: Double   // positive = club up to compensate short miss
}

public enum MissPattern {
    /// Analyze shots for a specific club. All deltas are in yards relative
    /// to the target (long positive, lat positive = right).
    public static func analyze(_ shots: [Shot]) -> MissAnalysis? {
        let withLanding = shots.filter { !($0.longDelta == 0 && $0.latDelta == 0) }
        guard withLanding.count >= 3 else { return nil }

        let n = Double(withLanding.count)
        let longs = withLanding.map(\.longDelta)
        let lats = withLanding.map(\.latDelta)

        let avgLong = longs.reduce(0, +) / n
        let avgLat = lats.reduce(0, +) / n

        // Threshold: shots beyond ±2y from target center count as a miss direction
        let threshold = 2.0
        let shortCount = longs.filter { $0 < -threshold }.count
        let longCount = longs.filter { $0 > threshold }.count
        let leftCount = lats.filter { $0 < -threshold }.count
        let rightCount = lats.filter { $0 > threshold }.count

        // Shots within threshold in both axes = "in zone"
        let inZoneCount = withLanding.filter {
            abs($0.longDelta) <= threshold && abs($0.latDelta) <= threshold
        }.count

        let pctShort = Double(shortCount) / n
        let pctLong = Double(longCount) / n
        let pctLeft = Double(leftCount) / n
        let pctRight = Double(rightCount) / n
        let pctInZone = Double(inZoneCount) / n

        // Dominant miss
        let dominant = describeDominant(
            avgLong: avgLong, avgLat: avgLat,
            pctShort: pctShort, pctLong: pctLong,
            pctLeft: pctLeft, pctRight: pctRight
        )

        // Aim offset: compensate for average miss.
        // If avg miss is 3y right, recommend aiming 3y left.
        let aimLat = -avgLat
        let aimLong = -avgLong

        return MissAnalysis(
            totalShots: withLanding.count,
            avgLongDelta: avgLong,
            avgLatDelta: avgLat,
            pctShort: pctShort,
            pctLong: pctLong,
            pctLeft: pctLeft,
            pctRight: pctRight,
            pctInZone: pctInZone,
            dominantMiss: dominant,
            aimOffsetLat: aimLat,
            aimOffsetLong: aimLong
        )
    }

    private static func describeDominant(
        avgLong: Double, avgLat: Double,
        pctShort: Double, pctLong: Double,
        pctLeft: Double, pctRight: Double
    ) -> String {
        let longBias = abs(avgLong) > 2
        let latBias = abs(avgLat) > 2

        if !longBias && !latBias { return "centered" }

        var parts: [String] = []
        if longBias {
            parts.append(avgLong < 0 ? "short" : "long")
        }
        if latBias {
            parts.append(avgLat < 0 ? "left" : "right")
        }
        return parts.joined(separator: "-")
    }
}
