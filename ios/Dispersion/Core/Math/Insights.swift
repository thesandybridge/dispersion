// Port of app/src/lib/insights.ts. Heuristic insights about a player's bag
// based on their clubs and recent shot history.

import Foundation

public enum InsightSeverity: String, Sendable {
    case good
    case warn
    case info
}

public struct InsightAction: Hashable, Sendable {
    public var label: String
    public var clubId: String?
}

public struct Insight: Identifiable, Hashable, Sendable {
    public var id: String
    public var severity: InsightSeverity
    public var title: String
    public var body: String
    public var action: InsightAction?
}

public enum Insights {
    public static func compute(clubs: [Club], shots: [Shot], now: Date = .now) -> [Insight] {
        var out: [Insight] = []

        // Bucket shots by club for the passes that need it.
        var byClub: [String: [Shot]] = [:]
        for s in shots { byClub[s.clubId, default: []].append(s) }

        out.append(contentsOf: widerThanShorter(clubs: clubs))
        out.append(contentsOf: staleData(clubs: clubs, byClub: byClub, now: now))
        out.append(contentsOf: longBias(clubs: clubs, byClub: byClub))
        out.append(contentsOf: sigmaTightening(clubs: clubs, byClub: byClub))
        return out
    }

    // MARK: Pass: longer club has wider σ than the next-shorter club.
    private static func widerThanShorter(clubs: [Club]) -> [Insight] {
        guard clubs.count >= 2 else { return [] }
        let sorted = clubs.sorted { $0.carryYards > $1.carryYards }
        var out: [Insight] = []
        for i in 0..<(sorted.count - 1) {
            let longer = sorted[i]
            let shorter = sorted[i + 1]
            if longer.carrySd > shorter.carrySd * 1.18 {
                let pct = Int(((longer.carrySd - shorter.carrySd) / shorter.carrySd) * 100)
                out.append(Insight(
                    id: "wider-\(longer.id)-\(shorter.id)",
                    severity: .warn,
                    title: "\(longer.name) disperses \(pct)% wider than \(shorter.name)",
                    body: "Your longer club has looser σ than the next one down. Worth questioning whether the extra distance is worth the variance.",
                    action: InsightAction(label: "Open \(longer.name)", clubId: longer.id)
                ))
            }
        }
        return out
    }

    // MARK: Pass: a club has no recent shot data.
    private static func staleData(
        clubs: [Club],
        byClub: [String: [Shot]],
        now: Date
    ) -> [Insight] {
        var out: [Insight] = []
        let staleThreshold: TimeInterval = 60 * 60 * 24 * 60 // 60 days
        for c in clubs {
            let shots = byClub[c.id] ?? []
            guard let latest = shots.map(\.timestamp).max() else { continue }
            if now.timeIntervalSince(latest) > staleThreshold {
                out.append(Insight(
                    id: "stale-\(c.id)",
                    severity: .info,
                    title: "\(c.name) hasn't been logged in a while",
                    body: "Last shot was over 60 days ago. Confidence in stored σ decays — log a few balls to refresh.",
                    action: InsightAction(label: "Open \(c.name)", clubId: c.id)
                ))
            }
        }
        return out
    }

    // MARK: Pass: club's stored carry vs measured mean has drifted.
    private static func longBias(clubs: [Club], byClub: [String: [Shot]]) -> [Insight] {
        var out: [Insight] = []
        for c in clubs {
            let shots = byClub[c.id] ?? []
            guard shots.count >= 8 else { continue }
            let meanLong = shots.map(\.longDelta).reduce(0, +) / Double(shots.count)
            // longDelta is delta from target. To turn into bias vs stored carry,
            // assume target was carryYards (mostly true for range mode).
            if abs(meanLong) > max(c.carrySd * 0.7, 4) {
                let direction = meanLong > 0 ? "long" : "short"
                out.append(Insight(
                    id: "bias-\(c.id)",
                    severity: .warn,
                    title: "\(c.name) playing ~\(Int(abs(meanLong)))y \(direction) of stored carry",
                    body: "Recent shots cluster off the stored carry. Consider re-calibrating.",
                    action: InsightAction(label: "Open \(c.name)", clubId: c.id)
                ))
            }
        }
        return out
    }

    // MARK: Pass: measured σ noticeably tighter than stored.
    private static func sigmaTightening(clubs: [Club], byClub: [String: [Shot]]) -> [Insight] {
        var out: [Insight] = []
        for c in clubs {
            let shots = byClub[c.id] ?? []
            guard shots.count >= 8 else { continue }
            let xy = shots.map { ShotXY(lat: $0.latDelta, long: $0.longDelta) }
            let stats = Sigma.dispersionFromShots(xy)
            if stats.carrySd > 0 && stats.carrySd < c.carrySd * 0.78 {
                let pct = Int((1 - (stats.carrySd / c.carrySd)) * 100)
                out.append(Insight(
                    id: "tightening-\(c.id)",
                    severity: .good,
                    title: "\(c.name) σ↕ has tightened ~\(pct)%",
                    body: "Recent dispersion is meaningfully tighter than the stored value. Consider saving to update.",
                    action: InsightAction(label: "Open \(c.name)", clubId: c.id)
                ))
            }
        }
        return out
    }
}
