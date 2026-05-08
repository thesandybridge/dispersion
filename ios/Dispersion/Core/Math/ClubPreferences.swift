// Persistent club preferences — "I prefer this club at this distance."
// Applied as a σ tightening factor in the calculator ranking.

import Foundation

public struct ClubPreference: Codable, Equatable, Sendable {
    public var clubId: String
    public var distanceYards: Double
    public var radiusYards: Double
    /// Applied to carrySd and lateralSd (< 1 = tighter = higher probability).
    public var sigmaMultiplier: Double

    public init(clubId: String, distanceYards: Double, radiusYards: Double = 15, sigmaMultiplier: Double = 0.92) {
        self.clubId = clubId
        self.distanceYards = distanceYards
        self.radiusYards = radiusYards
        self.sigmaMultiplier = sigmaMultiplier
    }

    public func matches(clubId: String, distance: Double) -> Bool {
        self.clubId == clubId && abs(distance - distanceYards) <= radiusYards
    }
}

public enum ClubPreferences {
    private static let key = "clubPreferences"

    public static func all() -> [ClubPreference] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([ClubPreference].self, from: data)) ?? []
    }

    /// Returns the active preference for a club at a given distance, if any.
    public static func preference(for clubId: String, at distance: Double) -> ClubPreference? {
        all().first { $0.matches(clubId: clubId, distance: distance) }
    }

    /// Set a preference. Replaces any existing preference for the same club
    /// in an overlapping distance range.
    public static func set(_ pref: ClubPreference) {
        var prefs = all()
        prefs.removeAll { $0.clubId == pref.clubId && abs($0.distanceYards - pref.distanceYards) < pref.radiusYards + $0.radiusYards }
        prefs.append(pref)
        save(prefs)
    }

    /// Remove the preference for a club near a given distance.
    public static func remove(clubId: String, near distance: Double) {
        var prefs = all()
        prefs.removeAll { $0.matches(clubId: clubId, distance: distance) }
        save(prefs)
    }

    /// Check if any preference is active for a given distance (any club).
    public static func activePreference(at distance: Double) -> ClubPreference? {
        all().first { abs($0.distanceYards - distance) <= $0.radiusYards }
    }

    private static func save(_ prefs: [ClubPreference]) {
        if let data = try? JSONEncoder().encode(prefs) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
