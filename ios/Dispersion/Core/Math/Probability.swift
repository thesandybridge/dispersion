// Port of app/src/lib/probability.ts.
//
// For each club, integrate a 2D Gaussian centered at the club's expected
// landing point over the safe zone. Output a probability in [0, 1].

import Foundation

public enum Probability {
    /// Standard normal CDF approximation (Abramowitz & Stegun 7.1.26 via erf).
    /// SwiftFoundation has `erf` in Numerics; we use the inline approximation
    /// to stay dep-free.
    public static func normalCdf(_ x: Double) -> Double {
        // Constants from A&S 7.1.26
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

    /// DECADE-inspired bias: shift the zone center back by this fraction of
    /// zone depth so that clubs carrying slightly past the pin score higher.
    /// Most amateurs miss short, so "take more club" is the right default.
    private static let decadeBias = 0.15

    /// Probability the club lands inside the safe zone (assumes independent
    /// long/lateral Gaussians). Zone is shifted back per DECADE to favor
    /// clubs that carry slightly past the target.
    public static func probabilityInZone(club: Club, scenario: ShotScenario) -> Double {
        // Shift the zone center toward the short side so clubs that fly
        // past the pin by a bit get a higher probability score.
        let bias = scenario.safeZoneDepthYards * decadeBias
        let longLo = -scenario.safeZoneDepthYards / 2 - bias
        let longHi = scenario.safeZoneDepthYards / 2 - bias
        let latLo = -scenario.safeZoneWidthYards / 2
        let latHi = scenario.safeZoneWidthYards / 2

        let meanLong = club.carryYards - scenario.distanceToTargetYards
        let meanLat = 0.0

        let pLong = gaussianBand(mean: meanLong, sd: club.carrySd, lo: longLo, hi: longHi)
        let pLat = gaussianBand(mean: meanLat, sd: club.lateralSd, lo: latLo, hi: latHi)
        return pLong * pLat
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
            let meanLat = 0.0
            let pLong = gaussianBand(mean: meanLong, sd: club.carrySd, lo: longLo, hi: longHi)
            let pLat = gaussianBand(mean: meanLat, sd: club.lateralSd, lo: latLo, hi: latHi)
            total += pLong * pLat
        }
        return min(total, 1)
    }

    /// Which clubs get partial swing variants — only wedges and short irons.
    private static func swingsForClub(_ club: Club) -> [SwingType] {
        let cat = ClubCategoryRegistry.categorize(name: club.name, carryYards: club.carryYards)
        switch cat {
        case .wedge:
            return [.full, .threeQuarter, .half]
        case .shortIron:
            return [.full, .threeQuarter]
        default:
            return [.full]
        }
    }

    /// Rank a bag against a scenario by descending probability-in-zone.
    /// Generates partial swing variants only for wedges and short irons.
    public static func rankClubs(_ clubs: [Club], scenario: ShotScenario) -> [ClubResult] {
        var results: [ClubResult] = []
        for c in clubs {
            for swing in swingsForClub(c) {
                var virtual = c
                virtual.carryYards = c.carryYards * swing.carryMultiplier
                virtual.carrySd = c.carrySd * swing.sigmaMultiplier
                virtual.lateralSd = c.lateralSd * swing.sigmaMultiplier
                let pZone = probabilityInZone(club: virtual, scenario: scenario)
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
        return results.sorted { $0.probabilityInZone > $1.probabilityInZone }
    }
}
