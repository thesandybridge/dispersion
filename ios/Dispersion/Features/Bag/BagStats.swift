// Cached aggregate stats for the Bag screen. Replaces a per-render
// `@Query private var allShotModels` followed by O(N) filtering in
// computed properties. Computed once via the repo on view appear /
// when the bag composition changes, and held in @State.

import Foundation
import SwiftData

public struct BagStats {
    public var totalShots: Int
    public var recentShotCount: Int
    public var avgSG: Double
    public var bestClubName: String?
    public var bestClubSG: Double?
    public var worstClubName: String?
    public var worstClubSG: Double?
    public var shotsByClub: [String: Int]

    public static let empty = BagStats(
        totalShots: 0,
        recentShotCount: 0,
        avgSG: 0,
        bestClubName: nil,
        bestClubSG: nil,
        worstClubName: nil,
        worstClubSG: nil,
        shotsByClub: [:]
    )

    /// Build a fresh BagStats from the persistent store. Heavy work happens
    /// once per call — caller is responsible for invoking it at the right
    /// times (e.g., .onAppear, after saving a club).
    public static func load(context: ModelContext, clubs: [Club]) -> BagStats {
        let repo = ShotsRepo(context: context)
        let allShots = (try? repo.listAll()) ?? []
        let valid = AppConfig.validShots(allShots)

        let cutoff = Calendar.current.date(
            byAdding: .day,
            value: -AppConfig.recentActivityDays,
            to: .now
        ) ?? .now

        var shotsByClub: [String: Int] = [:]
        for s in valid {
            shotsByClub[s.clubId, default: 0] += 1
        }

        let aggregate = StrokesGained.aggregate(valid)

        // Best / worst SG club among regular (non-putter) clubs with enough data.
        let regular = clubs.filter {
            ClubCategoryRegistry.categorize(name: $0.name, carryYards: $0.carryYards) != .putter
        }
        var clubSGs: [(club: Club, sg: Double)] = []
        for club in regular {
            let clubShots = valid.filter { $0.clubId == club.id }
            let agg = StrokesGained.aggregate(clubShots)
            guard agg.shotCount >= AppConfig.minShotsForClubSG else { continue }
            clubSGs.append((club, agg.avgSG))
        }
        let best = clubSGs.max(by: { $0.sg < $1.sg })
        let worst = clubSGs.min(by: { $0.sg < $1.sg })

        return BagStats(
            totalShots: valid.count,
            recentShotCount: valid.lazy.filter { $0.timestamp >= cutoff }.count,
            avgSG: aggregate.avgSG,
            bestClubName: best?.club.name,
            bestClubSG: best?.sg,
            worstClubName: worst?.club.name,
            worstClubSG: worst?.sg,
            shotsByClub: shotsByClub
        )
    }
}
