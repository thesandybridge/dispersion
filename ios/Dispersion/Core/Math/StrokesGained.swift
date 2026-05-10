// Strokes Gained — Mark Broadie's framework, "Assessing golfer performance
// using golfshot-tracking data" (Broadie 2008/2009). Reference values come
// from PGA Tour ShotLink baselines, lightly rounded so the table stays
// readable in code review.
//
// SG for one shot = E[strokes] before − (1 + E[strokes] after).
// Positive → better than the tour baseline; negative → worse.
//
// We carry three baselines:
//   1. Approach (distance to hole, by start lie)
//   2. Tee shot — handled by approach() with `.tee` lie at the box yardage
//   3. Putting (distance to hole in feet, single lie)
//
// Lie penalties are the deltas Broadie reports between same-distance fairway
// and (rough / bunker / recovery). They're approximate — a real PGA Tour
// dataset would also vary the penalty with distance — but at the granularity
// our app needs they're more honest than treating every miss as fairway.

import Foundation

// MARK: - Lie

public enum Lie: String, Codable, CaseIterable, Sendable {
    case tee
    case fairway
    case rough
    case sand
    case recovery   // trees, deep rough, scramble
    case green
}

public extension Lie {
    /// Strokes lost vs same-distance fairway, averaged across distances.
    /// Source: Broadie ShotLink baseline deltas.
    var penaltyVsFairway: Double {
        switch self {
        case .tee:      return 0.0      // Tee box is its own baseline below.
        case .fairway:  return 0.0
        case .rough:    return 0.20
        case .sand:     return 0.40
        case .recovery: return 0.80
        case .green:    return 0.0      // Putting uses the green table.
        }
    }
}

// MARK: - Strokes Gained

public enum StrokesGained {

    /// Expected strokes to hole out from the given distance + lie. Distances
    /// that fall on the green (≤ 1 yard) round up to "1 + putt expectation
    /// from a couple of feet" since the player is effectively on the green.
    /// For any explicit putting distance use `expectedPuttingStrokes`.
    public static func expectedStrokes(fromYards distance: Double, lie: Lie = .fairway) -> Double {
        let d = max(0, distance)

        // On (or essentially on) the green from approach distance — fall
        // through to putting baseline at ~6 ft so we don't return 1.0 for
        // a 0-yard fairway shot.
        if d < 1 { return expectedPuttingStrokes(fromFeet: 6) }

        let baseline = approachBaseline(fromYards: d, lie: lie)
        return baseline
    }

    /// Approach baseline (distance in yards, lie). Shape derived from Broadie
    /// 2009 PGA Tour data; lie penalties applied additively.
    static func approachBaseline(fromYards distance: Double, lie: Lie) -> Double {
        // Broadie baseline (fairway), table reproduced and linearly
        // interpolated. Column: (yards, expected strokes).
        let table: [(Double, Double)] = [
            (10, 2.18),  // immediate fringe / green-edge
            (20, 2.40),
            (30, 2.55),
            (40, 2.65),
            (50, 2.74),
            (60, 2.80),
            (80, 2.88),
            (100, 2.92),
            (125, 2.99),
            (150, 3.06),
            (175, 3.13),
            (200, 3.27),
            (225, 3.39),
            (250, 3.50),
            (275, 3.62),
            (300, 3.74),
            (350, 3.95),
            (400, 4.16),
            (500, 4.40),
        ]

        let baseline: Double
        if distance >= table.last!.0 {
            baseline = table.last!.1
        } else if distance <= table.first!.0 {
            baseline = table.first!.1
        } else {
            baseline = interpolate(distance, in: table)
        }

        // Tee penalty handled separately — at tee box, the hole's "expected
        // strokes" is approximately 4.0 for a par 4 / 5.0 for a par 5. We
        // proxy that with a small bonus on top of fairway since most tees
        // play to roughly fairway-like dispersion.
        switch lie {
        case .tee, .fairway, .green:
            return baseline
        case .rough, .sand, .recovery:
            return baseline + lie.penaltyVsFairway
        }
    }

    /// Expected strokes to hole out from this many feet from the cup, using
    /// the Broadie putting baseline. This is a 1D function (no lie variant).
    public static func expectedPuttingStrokes(fromFeet distanceFeet: Double) -> Double {
        let table: [(Double, Double)] = [
            (1.0, 1.001),
            (2.0, 1.064),
            (3.0, 1.155),
            (4.0, 1.265),
            (5.0, 1.353),
            (6.0, 1.444),
            (7.0, 1.524),
            (8.0, 1.594),
            (9.0, 1.658),
            (10.0, 1.711),
            (12.0, 1.788),
            (15.0, 1.876),
            (20.0, 1.946),
            (25.0, 2.000),
            (30.0, 2.061),
            (40.0, 2.140),
            (50.0, 2.205),
            (60.0, 2.245),
            (75.0, 2.300),
            (90.0, 2.348),
        ]
        let d = max(0, distanceFeet)
        if d <= table.first!.0 { return table.first!.1 }
        if d >= table.last!.0 { return table.last!.1 }
        return interpolate(d, in: table)
    }

    // MARK: - Per-shot SG

    /// SG for one shot. `startLie` defaults to fairway since most logged
    /// shots are full-swing approaches; pass the actual lie to get an
    /// honest number for rough / bunker / recovery.
    public static func approach(
        startYards: Double,
        endYards: Double,
        startLie: Lie = .fairway,
        endLie: Lie = .fairway,
        holed: Bool = false
    ) -> Double {
        let before = expectedStrokes(fromYards: startYards, lie: startLie)
        let after = holed ? 0.0 : expectedStrokes(fromYards: endYards, lie: endLie)
        return before - (1.0 + after)
    }

    /// SG for one putt. `startFeet` and `endFeet` are distances from the
    /// cup. `holed` short-circuits `endFeet`.
    public static func putt(startFeet: Double, endFeet: Double, holed: Bool = false) -> Double {
        let before = expectedPuttingStrokes(fromFeet: startFeet)
        let after = holed ? 0.0 : expectedPuttingStrokes(fromFeet: endFeet)
        return before - (1.0 + after)
    }

    /// SG for an iOS-app Shot record. Treats start lie as fairway by
    /// default; callers with course-context (e.g. a round tracker that
    /// knows the lie) should compute SG via `approach(...)` directly.
    public static func forShot(
        targetYards: Double,
        longDelta: Double,
        latDelta: Double,
        startLie: Lie = .fairway,
        endLie: Lie = .fairway
    ) -> Double {
        let endDistance = sqrt(longDelta * longDelta + latDelta * latDelta)
        return approach(
            startYards: targetYards,
            endYards: endDistance,
            startLie: startLie,
            endLie: endLie
        )
    }

    /// Aggregate strokes gained for a set of shots. Shots whose deltas are
    /// both zero are treated as "no landing data" and skipped.
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

    // MARK: - Helpers

    private static func interpolate(_ x: Double, in table: [(Double, Double)]) -> Double {
        for i in 0..<(table.count - 1) {
            let (x0, y0) = table[i]
            let (x1, y1) = table[i + 1]
            if x >= x0 && x < x1 {
                let t = (x - x0) / (x1 - x0)
                return y0 + t * (y1 - y0)
            }
        }
        return table.last!.1
    }
}

public struct SGSummary: Equatable {
    public var totalSG: Double
    public var avgSG: Double
    public var shotCount: Int

    public static let empty = SGSummary(totalSG: 0, avgSG: 0, shotCount: 0)
}
