// Session-level insights: per-club σ for the session, miss-direction
// summary, deltas vs the player's stored stats AND vs the previous
// session of the same club.
//
// Pure computation — view layer in SessionInsightsCard.swift.

import Foundation

public struct SessionClubInsight: Identifiable, Hashable {
    public var clubId: String
    public var clubName: String
    public var shotCount: Int
    public var stats: DispersionStats
    /// δ vs club's stored σ (negative = tighter than stored, positive = looser).
    public var carrySdDeltaVsStored: Double
    public var lateralSdDeltaVsStored: Double
    /// δ vs previous session for this club, if available.
    public var carrySdDeltaVsPrevious: Double?
    public var lateralSdDeltaVsPrevious: Double?
    /// Mean lateral miss in yards: negative = leans left, positive = leans right.
    public var lateralBias: Double
    /// Mean long miss: negative = short of target, positive = long.
    public var longBias: Double

    public var id: String { clubId }
}

public enum SessionInsightsEngine {
    /// Compute insights for every club represented in `sessionShots`.
    /// `priorShotsByClub` is the shots from the *previous* session for each
    /// club, used to compute deltas. `clubsById` maps club ID to its stored stats.
    public static func compute(
        sessionShots: [Shot],
        clubsById: [String: Club],
        priorShotsByClub: [String: [Shot]]
    ) -> [SessionClubInsight] {
        var grouped: [String: [Shot]] = [:]
        for s in sessionShots {
            grouped[s.clubId, default: []].append(s)
        }

        return grouped
            .compactMap { clubId, shots -> SessionClubInsight? in
                guard let club = clubsById[clubId] else { return nil }
                let withLanding = shots.filter { !($0.longDelta == 0 && $0.latDelta == 0) }
                guard withLanding.count >= 2 else { return nil }
                let xy = withLanding.map { ShotXY(lat: $0.latDelta, long: $0.longDelta) }
                let stats = Sigma.dispersionFromShots(xy)

                let priorShots = priorShotsByClub[clubId] ?? []
                let priorStats: DispersionStats?
                if priorShots.count >= 2 {
                    let priorXy = priorShots
                        .filter { !($0.longDelta == 0 && $0.latDelta == 0) }
                        .map { ShotXY(lat: $0.latDelta, long: $0.longDelta) }
                    priorStats = Sigma.dispersionFromShots(priorXy)
                } else {
                    priorStats = nil
                }

                return SessionClubInsight(
                    clubId: clubId,
                    clubName: club.name,
                    shotCount: withLanding.count,
                    stats: stats,
                    carrySdDeltaVsStored: stats.carrySd - club.carrySd,
                    lateralSdDeltaVsStored: stats.lateralSd - club.lateralSd,
                    carrySdDeltaVsPrevious: priorStats.map { stats.carrySd - $0.carrySd },
                    lateralSdDeltaVsPrevious: priorStats.map { stats.lateralSd - $0.lateralSd },
                    lateralBias: stats.latBias,
                    longBias: stats.longBias
                )
            }
            .sorted { $0.clubName < $1.clubName }
    }
}
