import Testing
@testable import Dispersion

@Suite("Probability")
struct ProbabilityTests {
    @Test("normalCdf matches known values")
    func normalCdfKnownValues() {
        #expect(approx(Probability.normalCdf(0), 0.5))
        #expect(approx(Probability.normalCdf(1.96), 0.975, eps: 0.001))
        #expect(approx(Probability.normalCdf(-1.96), 0.025, eps: 0.001))
        #expect(approx(Probability.normalCdf(2.576), 0.995, eps: 0.001))
    }

    @Test("gaussianBand integrates to 1 across whole real line")
    func bandIntegratesToOne() {
        let p = Probability.gaussianBand(mean: 0, sd: 5, lo: -1_000, hi: 1_000)
        #expect(approx(p, 1.0, eps: 0.001))
    }

    @Test("perfect club lands in tight zone with high probability")
    func perfectClub() {
        let club = Club(id: "c", name: "7i", carryYards: 150, carrySd: 1, lateralSd: 1)
        let scenario = ShotScenario(
            distanceToTargetYards: 150,
            safeZoneWidthYards: 30,
            safeZoneDepthYards: 30
        )
        let p = Probability.probabilityInZone(club: club, scenario: scenario)
        #expect(p > 0.999)
    }

    @Test("rankClubs sorts by descending probability")
    func ranks() {
        let tight = Club(id: "tight", name: "tight", carryYards: 150, carrySd: 2, lateralSd: 2)
        let loose = Club(id: "loose", name: "loose", carryYards: 150, carrySd: 12, lateralSd: 12)
        let scenario = ShotScenario(
            distanceToTargetYards: 150,
            safeZoneWidthYards: 12,
            safeZoneDepthYards: 12
        )
        let ranked = Probability.rankClubs([loose, tight], scenario: scenario)
        #expect(ranked.first?.clubId == "tight")
    }
}

@Suite("Sigma")
struct SigmaTests {
    @Test("dispersionFromShots: zero shots → empty")
    func empty() {
        #expect(Sigma.dispersionFromShots([]) == .empty)
    }

    @Test("dispersionFromShots: single shot returns mean only")
    func single() {
        let stats = Sigma.dispersionFromShots([ShotXY(lat: 3, long: -2)])
        #expect(stats.n == 1)
        #expect(stats.carrySd == 0)
        #expect(stats.lateralSd == 0)
        #expect(approx(stats.longBias, -2))
        #expect(approx(stats.latBias, 3))
    }

    @Test("dispersionFromShots: known sample stddev")
    func sampleStddev() {
        // 4 shots with known sd ≈ 5 along long axis.
        let shots = [
            ShotXY(lat: 0, long: -5),
            ShotXY(lat: 0, long: 5),
            ShotXY(lat: 0, long: -5),
            ShotXY(lat: 0, long: 5),
        ]
        let s = Sigma.dispersionFromShots(shots)
        #expect(approx(s.carrySd, 5.7735, eps: 0.001)) // 5/sqrt(3/4)·something — ddof=1
        #expect(approx(s.longBias, 0))
    }
}

private func approx(_ a: Double, _ b: Double, eps: Double = 0.0005) -> Bool {
    abs(a - b) < eps
}
