// Strokes gained calculation using Broadie's proximity-to-hole baseline.
// Expected strokes from a given distance on the fairway (approach shots).

import Foundation

public enum StrokesGained {
    /// Expected strokes to hole out from a given distance (yards) on the
    /// fairway. Simplified Broadie lookup — linear interpolation between
    /// key distances from PGA Tour data.
    public static func expectedStrokes(fromYards distance: Double) -> Double {
        // Broadie baseline: (distance in yards, expected strokes from fairway)
        let table: [(Double, Double)] = [
            (0, 1.0),       // on the green edge
            (20, 2.40),
            (40, 2.60),
            (60, 2.75),
            (80, 2.85),
            (100, 2.92),
            (120, 2.97),
            (140, 3.02),
            (160, 3.08),
            (180, 3.16),
            (200, 3.25),
            (220, 3.40),
            (240, 3.55),
            (260, 3.70),
            (280, 3.85),
            (300, 4.00),
        ]

        let d = max(0, distance)
        if d >= table.last!.0 { return table.last!.1 }

        for i in 0..<(table.count - 1) {
            let (d0, s0) = table[i]
            let (d1, s1) = table[i + 1]
            if d >= d0 && d < d1 {
                let t = (d - d0) / (d1 - d0)
                return s0 + t * (s1 - s0)
            }
        }
        return table.last!.1
    }

    /// Strokes gained for a single approach shot.
    /// Positive = better than baseline, negative = worse.
    ///
    /// - Parameters:
    ///   - startYards: distance to pin before the shot
    ///   - endYards: distance to pin after the shot (use 0 if holed)
    ///   - holed: true if the shot went in
    public static func approach(startYards: Double, endYards: Double, holed: Bool = false) -> Double {
        let before = expectedStrokes(fromYards: startYards)
        let after = holed ? 0.0 : expectedStrokes(fromYards: endYards)
        // SG = expected_before - (1 stroke taken + expected_after)
        return before - (1.0 + after)
    }

    /// Strokes gained for a shot given the target distance and where it landed.
    /// Approximates end distance from the deltas.
    public static func forShot(targetYards: Double, longDelta: Double, latDelta: Double) -> Double {
        // Actual landing distance from the pin
        let endDistance = sqrt(longDelta * longDelta + latDelta * latDelta)
        return approach(startYards: targetYards, endYards: endDistance)
    }

    /// Aggregate strokes gained for a set of shots.
    public static func aggregate(_ shots: [Shot]) -> SGSummary {
        guard !shots.isEmpty else { return .empty }
        var total = 0.0
        var count = 0
        for s in shots {
            if s.longDelta == 0 && s.latDelta == 0 { continue }
            total += forShot(
                targetYards: s.targetDistanceYards,
                longDelta: s.longDelta,
                latDelta: s.latDelta
            )
            count += 1
        }
        guard count > 0 else { return .empty }
        return SGSummary(
            totalSG: total,
            avgSG: total / Double(count),
            shotCount: count
        )
    }
}

public struct SGSummary: Equatable {
    public var totalSG: Double
    public var avgSG: Double
    public var shotCount: Int

    public static let empty = SGSummary(totalSG: 0, avgSG: 0, shotCount: 0)
}
