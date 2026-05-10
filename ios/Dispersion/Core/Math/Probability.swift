// Probability-first club ranking.
//
// For each club, integrate a 2D Gaussian centered at the club's expected
// landing point over the safe zone → P(in safe). Pair that with a
// strokes-gained valuation of each outcome (in the green, in the rough,
// in a hazard) → expected strokes gained. The best club is the one that
// maximizes E[SG], not just P(zone).
//
// References:
//   • Broadie, M. "Assessing golfer performance using golfshot-tracking
//     data." (Strokes-gained framework + tour proximity-to-hole baselines.)

import Foundation

public enum Probability {
    /// Standard normal CDF approximation (Abramowitz & Stegun 7.1.26 via erf).
    public static func normalCdf(_ x: Double) -> Double {
        let a1 = 0.254829592
        let a2 = -0.284496736
        let a3 = 1.421413741
        let a4 = -1.453152027
        let a5 = 1.061405429
        let p = 0.3275911

        let sign: Double = x < 0 ? -1 : 1
        let absX = abs(x) / sqrt(2.0)
        let t = 1.0 / (1.0 + p * absX)
        let y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * exp(-absX * absX)
        return 0.5 * (1.0 + sign * y)
    }

    /// Probability that a 1D Gaussian with mean `mean` and stddev `sd` falls in `[lo, hi]`.
    public static func gaussianBand(mean: Double, sd: Double, lo: Double, hi: Double) -> Double {
        guard sd > 0 else { return mean >= lo && mean <= hi ? 1 : 0 }
        return normalCdf((hi - mean) / sd) - normalCdf((lo - mean) / sd)
    }

    /// Probability the club lands inside the safe zone, with optional
    /// short-side bias (legacy heuristic — kept for backward compat with
    /// the calculator's current ranking. The expected-SG path below is
    /// the more honest one.)
    public static func probabilityInZone(
        club: Club,
        scenario: ShotScenario,
        shortSideBias: Double = 0.08
    ) -> Double {
        let longLo = -scenario.safeZoneDepthYards / 2
        let longHi = scenario.safeZoneDepthYards / 2
        let latLo = -scenario.safeZoneWidthYards / 2
        let latHi = scenario.safeZoneWidthYards / 2

        let meanLong = club.carryYards - scenario.distanceToTargetYards
        let meanLat = scenario.aimLateralYards

        let pLong = gaussianBand(mean: meanLong, sd: club.carrySd, lo: longLo, hi: longHi)
        let pLat = gaussianBand(mean: meanLat, sd: club.lateralSd, lo: latLo, hi: latHi)
        var p = pLong * pLat

        // Legacy "take more club" exponential decay. The strokes-gained
        // ranking (rankClubsByExpectedSG) supersedes this — short-club
        // penalty emerges naturally from the math because missing short
        // usually leaves a worse next-shot lie than missing long.
        if meanLong < 0 && shortSideBias > 0 {
            let shortness = abs(meanLong)
            let penalty = exp(-shortSideBias * shortness)
            p *= penalty
        }

        return p
    }

    /// Probability of landing in any penalty zone — union, capped at 1.
    public static func probabilityPenalty(club: Club, scenario: ShotScenario) -> Double {
        var total = 0.0
        for zone in scenario.penaltyZones {
            let longLo = zone.centerLong - zone.depthYards / 2
            let longHi = zone.centerLong + zone.depthYards / 2
            let latLo = zone.centerLateral - zone.widthYards / 2
            let latHi = zone.centerLateral + zone.widthYards / 2

            let meanLong = club.carryYards - scenario.distanceToTargetYards
            let meanLat = scenario.aimLateralYards
            let pLong = gaussianBand(mean: meanLong, sd: club.carrySd, lo: longLo, hi: longHi)
            let pLat = gaussianBand(mean: meanLat, sd: club.lateralSd, lo: latLo, hi: latHi)
            total += pLong * pLat
        }
        return min(total, 1)
    }

    // MARK: - Expected strokes-gained

    /// Expected strokes gained for a club + scenario. Decomposes the
    /// dispersion into:
    ///   • P(in green)     · SG when on the green
    ///   • P(in penalty)   · SG when in penalty (≈ 1 stroke + drop + replay)
    ///   • P(rough/miss)   · SG from the ~rough at the expected miss distance
    ///
    /// Higher = better. This is what a strokes-gained-aware
    /// recommendation should optimize, not raw P(zone).
    public static func expectedStrokesGained(
        club: Club,
        scenario: ShotScenario
    ) -> Double {
        let pGreen = probabilityInZone(club: club, scenario: scenario, shortSideBias: 0)
        let pPenalty = probabilityPenalty(club: club, scenario: scenario)
        let pMiss = max(0, 1 - pGreen - pPenalty)

        let startYards = scenario.distanceToTargetYards
        let meanLong = club.carryYards - scenario.distanceToTargetYards
        let endIfMissedYards = max(5, abs(meanLong) + club.carrySd)

        let sgGreen = StrokesGained.approach(
            startYards: startYards,
            endYards: 0,
            startLie: .fairway,
            endLie: .green
        )
        let sgRough = StrokesGained.approach(
            startYards: startYards,
            endYards: endIfMissedYards,
            startLie: .fairway,
            endLie: .rough
        )
        // Penalty: standard PGA proxy is 1.0 stroke loss + reset to a
        // fairway lie at the same approach distance; dramatic in
        // expected value.
        let sgPenalty = -1.0 + StrokesGained.approach(
            startYards: startYards,
            endYards: startYards,
            startLie: .fairway,
            endLie: .fairway
        )

        return pGreen * sgGreen + pMiss * sgRough + pPenalty * sgPenalty
    }

    // MARK: - Ranking

    /// Probability-based ranking (legacy). Kept for the existing calculator
    /// surface — uses `probabilityInZone` with the short-side decay heuristic.
    /// Partial-swing variants are only included when `Club.threeQuarter` /
    /// `Club.half` are calibrated.
    public static func rankClubs(
        _ clubs: [Club],
        scenario: ShotScenario,
        shortSideBias: Double = 0.08
    ) -> [ClubResult] {
        rank(clubs, scenario: scenario, score: { c in
            probabilityInZone(club: c, scenario: scenario, shortSideBias: shortSideBias)
        })
    }

    /// Strokes-gained ranking: orders clubs by expected strokes gained
    /// against the hole geometry. Use this when you have meaningful
    /// penalty zones configured; it makes "take more club" emerge from
    /// the math rather than from a tunable bias coefficient.
    public static func rankClubsByExpectedSG(
        _ clubs: [Club],
        scenario: ShotScenario
    ) -> [ClubResult] {
        rank(clubs, scenario: scenario, score: { c in
            expectedStrokesGained(club: c, scenario: scenario)
        })
    }

    /// Shared iteration that resolves swing variants and applies a scoring
    /// function. Variants below 3% raw probability are dropped from the
    /// list so the calculator doesn't surface vanishingly weak options.
    private static func rank(
        _ clubs: [Club],
        scenario: ShotScenario,
        score: (Club) -> Double
    ) -> [ClubResult] {
        var results: [ClubResult] = []
        for c in clubs {
            let cat = ClubCategoryRegistry.categorize(name: c.name, carryYards: c.carryYards)
            if cat == .putter { continue }
            for swing in c.availableSwings {
                let p = c.profile(for: swing)
                var virtual = c
                virtual.carryYards = p.carry
                virtual.carrySd = p.carrySd
                virtual.lateralSd = p.lateralSd
                let pZone = probabilityInZone(club: virtual, scenario: scenario, shortSideBias: 0)
                if swing != .full && pZone < 0.03 { continue }
                results.append(ClubResult(
                    clubId: c.id,
                    swingType: swing,
                    probabilityInZone: pZone,
                    probabilityPenalty: probabilityPenalty(club: virtual, scenario: scenario),
                    expectedCarry: virtual.carryYards
                ))
            }
        }
        // Sort by the same score function we used to build the entries.
        // For the legacy probability ranking this is `probabilityInZone`;
        // for the SG path the caller injected a different scorer above.
        return results.sorted { lhs, rhs in
            guard let lc = clubs.first(where: { $0.id == lhs.clubId }),
                  let rc = clubs.first(where: { $0.id == rhs.clubId })
            else { return lhs.probabilityInZone > rhs.probabilityInZone }
            var lv = lc; var rv = rc
            let lp = lc.profile(for: lhs.swingType)
            let rp = rc.profile(for: rhs.swingType)
            lv.carryYards = lp.carry; lv.carrySd = lp.carrySd; lv.lateralSd = lp.lateralSd
            rv.carryYards = rp.carry; rv.carrySd = rp.carrySd; rv.lateralSd = rp.lateralSd
            return score(lv) > score(rv)
        }
    }
}
