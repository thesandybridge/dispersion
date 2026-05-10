// Coverage for the Math layer beyond what ProbabilityTests already covers:
// - StrokesGained (Broadie baseline + per-shot + aggregate)
// - ShotStatsEngine (per-club session sigma series)
// - AppConfig.validShots (outlier filter)

import Foundation
import Testing
@testable import Dispersion

// MARK: - StrokesGained

@Suite("StrokesGained")
struct StrokesGainedTests {

    @Test("expectedStrokes: 0y on the green falls through to putt baseline")
    func baselineEdges() {
        // 0y is treated as "on the green" — falls to the putt baseline at
        // an assumed 6 ft, ≈ 1.444 strokes.
        #expect(approx(StrokesGained.expectedStrokes(fromYards: 0), 1.444, eps: 0.01))
        // 300y is on the table at 3.74; far past it caps at the last entry.
        #expect(approx(StrokesGained.expectedStrokes(fromYards: 300), 3.74, eps: 0.01))
        #expect(approx(StrokesGained.expectedStrokes(fromYards: 500), 4.40, eps: 0.01))
        // Negative distances clamp to 0 → on-green sentinel.
        #expect(approx(StrokesGained.expectedStrokes(fromYards: -50), 1.444, eps: 0.01))
    }

    @Test("expectedStrokes: monotonic non-decreasing in the approach range")
    func baselineMonotonic() {
        var prev = -Double.infinity
        // Skip the on-green band (≤ 1y) since that maps to a putt value
        // that's intentionally lower than the 10y "fringe" approach value.
        for d in stride(from: 10, through: 300, by: 5) {
            let v = StrokesGained.expectedStrokes(fromYards: Double(d))
            #expect(v >= prev)
            prev = v
        }
    }

    @Test("expectedStrokes: linear interpolation between table points")
    func baselineInterpolation() {
        // Table has 100 → 2.92 and 125 → 2.99. Midpoint at 112.5 should
        // sit halfway between (2.955).
        let mid = StrokesGained.expectedStrokes(fromYards: 112.5)
        #expect(approx(mid, 2.955, eps: 0.001))
    }

    @Test("approach: holing out from 100y is a clear positive SG")
    func approachHoled() {
        let sg = StrokesGained.approach(startYards: 100, endYards: 0, holed: true)
        // Before ≈ 2.92, after = 0, took 1 stroke → SG = 2.92 - 1 = 1.92
        #expect(approx(sg, 1.92, eps: 0.01))
    }

    @Test("expectedPuttingStrokes: signature values across the cup-distance table")
    func puttingBaseline() {
        // Spot-checks against the published Broadie putt table.
        #expect(approx(StrokesGained.expectedPuttingStrokes(fromFeet: 1), 1.001, eps: 0.005))
        #expect(approx(StrokesGained.expectedPuttingStrokes(fromFeet: 5), 1.353, eps: 0.005))
        #expect(approx(StrokesGained.expectedPuttingStrokes(fromFeet: 10), 1.711, eps: 0.005))
        #expect(approx(StrokesGained.expectedPuttingStrokes(fromFeet: 30), 2.061, eps: 0.005))
    }

    @Test("Lie penalties: rough/sand/recovery cost vs fairway")
    func liePenalties() {
        let dist = 150.0
        let fwy = StrokesGained.expectedStrokes(fromYards: dist, lie: .fairway)
        let rough = StrokesGained.expectedStrokes(fromYards: dist, lie: .rough)
        let sand = StrokesGained.expectedStrokes(fromYards: dist, lie: .sand)
        let recovery = StrokesGained.expectedStrokes(fromYards: dist, lie: .recovery)
        #expect(rough > fwy)
        #expect(sand > rough)
        #expect(recovery > sand)
        // Documented deltas — should match Lie.penaltyVsFairway.
        #expect(approx(rough - fwy, 0.20, eps: 0.005))
        #expect(approx(sand - fwy, 0.40, eps: 0.005))
        #expect(approx(recovery - fwy, 0.80, eps: 0.005))
    }

    @Test("approach: matching baseline yields ~zero SG")
    func approachNeutral() {
        // Scan within the approach range (10y+) so we don't pick a putt-
        // baseline value from the on-green band. Tolerance is 0.15 because
        // the published Broadie table is a sparse list and step-quantized
        // values can sit ~0.1 strokes off the true minimum.
        let before = StrokesGained.expectedStrokes(fromYards: 150)
        let approxAfter = before - 1.0
        var bestDist = 10.0
        var bestErr = Double.infinity
        for d in stride(from: 10.0, through: 300.0, by: 0.5) {
            let err = abs(StrokesGained.expectedStrokes(fromYards: d) - approxAfter)
            if err < bestErr { bestErr = err; bestDist = d }
        }
        let sg = StrokesGained.approach(startYards: 150, endYards: bestDist)
        #expect(abs(sg) < 0.15)
    }

    @Test("aggregate: empty returns .empty")
    func aggregateEmpty() {
        #expect(StrokesGained.aggregate([]) == .empty)
    }

    @Test("aggregate: skips shots with both deltas zero (sentinel for no landing data)")
    func aggregateSkipsZeroLanding() {
        let shotsWithLanding = [
            Shot(id: "1", sessionId: "s", clubId: "c", targetDistanceYards: 150, longDelta: -10, latDelta: 5),
        ]
        let shotsWithoutLanding = [
            Shot(id: "2", sessionId: "s", clubId: "c", targetDistanceYards: 150, longDelta: 0, latDelta: 0),
        ]
        let withSG = StrokesGained.aggregate(shotsWithLanding)
        let zeroSG = StrokesGained.aggregate(shotsWithoutLanding)
        #expect(withSG.shotCount == 1)
        #expect(zeroSG.shotCount == 0)
    }

    @Test("aggregate: avgSG = totalSG / count")
    func aggregateAverages() {
        let shots = (0..<5).map { i in
            Shot(id: "\(i)", sessionId: "s", clubId: "c",
                 targetDistanceYards: 150, longDelta: Double(i + 1), latDelta: 0)
        }
        let agg = StrokesGained.aggregate(shots)
        #expect(agg.shotCount == 5)
        #expect(approx(agg.avgSG, agg.totalSG / 5.0, eps: 0.0001))
    }
}

// MARK: - ShotStatsEngine

@Suite("ShotStatsEngine")
struct ShotStatsEngineTests {

    private func makeShot(_ id: String, session: String, long: Double, lat: Double, daysAgo: Int = 0) -> Shot {
        Shot(
            id: id,
            sessionId: session,
            clubId: "club-x",
            targetDistanceYards: 150,
            longDelta: long,
            latDelta: lat,
            timestamp: Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
        )
    }

    @Test("summarize: empty returns nil")
    func summaryEmpty() {
        #expect(ShotStatsEngine.summarize([]) == nil)
    }

    @Test("summarize: single-shot session is filtered out (need n>=2 for sd)")
    func singleShotSessionDropped() {
        let shots = [makeShot("a", session: "s1", long: 5, lat: 0)]
        let s = ShotStatsEngine.summarize(shots)
        #expect(s != nil)
        #expect(s?.totalShots == 1)
        #expect(s?.sessionCount == 0)
        #expect(s?.latestCarrySd == nil)
    }

    @Test("summarize: two sessions produce sigma series in chronological order")
    func chronologicalSeries() {
        let s1 = [
            makeShot("a", session: "old", long: 0, lat: 0, daysAgo: 30),
            makeShot("b", session: "old", long: 10, lat: 0, daysAgo: 30),
        ]
        let s2 = [
            makeShot("c", session: "new", long: 0, lat: 0, daysAgo: 1),
            makeShot("d", session: "new", long: 4, lat: 0, daysAgo: 1),
        ]
        let summary = ShotStatsEngine.summarize(s1 + s2)
        #expect(summary?.sessionCount == 2)
        #expect((summary?.sigmaSeries.count ?? 0) == 2)
        // Newest session has tighter sigma; its value should be the LAST element.
        let series = summary?.sigmaSeries ?? []
        #expect(series.last ?? 999 < series.first ?? 0)
    }

    @Test("summarize: sigmaSeries capped at AppConfig.sigmaTrendSessions")
    func sigmaSeriesWindow() {
        var shots: [Shot] = []
        let n = AppConfig.sigmaTrendSessions + 5
        for i in 0..<n {
            shots.append(makeShot("\(i)a", session: "session-\(i)", long: 0, lat: 0, daysAgo: i))
            shots.append(makeShot("\(i)b", session: "session-\(i)", long: 5, lat: 0, daysAgo: i))
        }
        let summary = ShotStatsEngine.summarize(shots)
        #expect((summary?.sigmaSeries.count ?? 0) == AppConfig.sigmaTrendSessions)
    }
}

// MARK: - AppConfig

@Suite("AppConfig")
struct AppConfigTests {

    @Test("validShots: filters records with delta beyond outlier threshold")
    func validShotsRejectsOutliers() {
        let shots = [
            Shot(id: "1", sessionId: "s", clubId: "c", targetDistanceYards: 150, longDelta: 5, latDelta: 5),
            Shot(id: "2", sessionId: "s", clubId: "c", targetDistanceYards: 150, longDelta: 200, latDelta: 0),
            Shot(id: "3", sessionId: "s", clubId: "c", targetDistanceYards: 150, longDelta: 0, latDelta: -150),
            Shot(id: "4", sessionId: "s", clubId: "c", targetDistanceYards: 150, longDelta: -50, latDelta: 50),
        ]
        let valid = AppConfig.validShots(shots)
        #expect(valid.map(\.id) == ["1", "4"])
    }

    @Test("validShots: empty in, empty out")
    func validShotsEmpty() {
        #expect(AppConfig.validShots([Shot]()).isEmpty)
    }

    @Test("validShots: boundary value is excluded (strict <)")
    func validShotsBoundary() {
        let onBoundary = Shot(
            id: "x", sessionId: "s", clubId: "c", targetDistanceYards: 150,
            longDelta: AppConfig.shotOutlierYards, latDelta: 0
        )
        #expect(AppConfig.validShots([onBoundary]).isEmpty)
    }
}

// MARK: - helpers

private func approx(_ a: Double, _ b: Double, eps: Double = 0.0005) -> Bool {
    abs(a - b) < eps
}
