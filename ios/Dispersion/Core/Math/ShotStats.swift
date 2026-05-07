// Port of app/src/lib/shotStats.ts. Groups shots by session and computes
// per-club sigma trends over time.

import Foundation

public struct ClubSummary {
    public var clubId: String
    public var totalShots: Int
    public var sessionCount: Int
    public var sigmaSeries: [Double]
    public var sessionPoints: [SessionPoint]
    public var latestCarrySd: Double?
    public var latestLateralSd: Double?
    public var deltaCarrySd: Double?
}

public struct SessionPoint {
    public var date: Date
    public var carrySd: Double
    public var n: Int
}

public enum ShotStatsEngine {
    public static func summarize(_ shots: [Shot]) -> ClubSummary? {
        guard let first = shots.first else { return nil }
        let clubId = first.clubId

        // Group by sessionId
        var bySession: [String: [Shot]] = [:]
        for s in shots {
            bySession[s.sessionId, default: []].append(s)
        }

        // Per-session: compute carrySd, filter ≥ 2 shots
        var sessionResults: [(date: Date, carrySd: Double, lateralSd: Double, n: Int)] = []
        for (_, sessionShots) in bySession {
            let sorted = sessionShots.sorted { $0.timestamp < $1.timestamp }
            let longs = sorted.map(\.longDelta)
            let lats = sorted.map(\.latDelta)
            guard longs.count >= 2 else { continue }
            let cSd = sampleSd(longs)
            let lSd = sampleSd(lats)
            guard cSd.isFinite, lSd.isFinite else { continue }
            let date = sorted.last?.timestamp ?? .now
            sessionResults.append((date, cSd, lSd, longs.count))
        }

        sessionResults.sort { $0.date < $1.date }

        let sigmaSeries = Array(sessionResults.suffix(8).map(\.carrySd))
        let sessionPoints = sessionResults.map {
            SessionPoint(date: $0.date, carrySd: $0.carrySd, n: $0.n)
        }
        let latest = sessionResults.last
        let prev = sessionResults.count >= 2 ? sessionResults[sessionResults.count - 2] : nil
        let delta: Double? = if let l = latest, let p = prev { l.carrySd - p.carrySd } else { nil }

        return ClubSummary(
            clubId: clubId,
            totalShots: shots.count,
            sessionCount: sessionResults.count,
            sigmaSeries: sigmaSeries,
            sessionPoints: sessionPoints,
            latestCarrySd: latest?.carrySd,
            latestLateralSd: latest?.lateralSd,
            deltaCarrySd: delta
        )
    }

    private static func sampleSd(_ values: [Double]) -> Double {
        let n = values.count
        guard n >= 2 else { return 0 }
        let m = values.reduce(0, +) / Double(n)
        var sq = 0.0
        for v in values {
            let d = v - m
            sq += d * d
        }
        return sqrt(sq / Double(n - 1))
    }
}
