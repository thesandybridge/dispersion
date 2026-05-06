// Port of app/src/lib/sampleBag.ts. Realistic single-digit-handicap starter bag.

import Foundation

public enum SampleBag {
    public struct Entry: Sendable {
        public let name: String
        public let carryYards: Double
        public let carrySd: Double
        public let lateralSd: Double
    }

    public static let entries: [Entry] = [
        .init(name: "Driver",  carryYards: 258, carrySd: 9.5, lateralSd: 14),
        .init(name: "3 Wood",  carryYards: 232, carrySd: 8.5, lateralSd: 11),
        .init(name: "5 Wood",  carryYards: 215, carrySd: 7.8, lateralSd: 10),
        .init(name: "4 Hybrid", carryYards: 200, carrySd: 6.8, lateralSd: 9),
        .init(name: "5 Iron",  carryYards: 188, carrySd: 6.2, lateralSd: 8),
        .init(name: "6 Iron",  carryYards: 178, carrySd: 5.8, lateralSd: 7.5),
        .init(name: "7 Iron",  carryYards: 165, carrySd: 5.2, lateralSd: 7),
        .init(name: "8 Iron",  carryYards: 153, carrySd: 4.6, lateralSd: 6.5),
        .init(name: "9 Iron",  carryYards: 141, carrySd: 4.2, lateralSd: 6),
        .init(name: "PW",      carryYards: 128, carrySd: 3.8, lateralSd: 5.5),
        .init(name: "GW",      carryYards: 112, carrySd: 3.4, lateralSd: 5),
        .init(name: "SW",      carryYards: 92,  carrySd: 3.0, lateralSd: 4.5),
        .init(name: "LW",      carryYards: 70,  carrySd: 2.6, lateralSd: 4),
    ]

    public static func clubs(idGen: () -> String = { UUID().uuidString.lowercased() }) -> [Club] {
        let now = Date()
        return entries.map { e in
            Club(
                id: idGen(),
                name: e.name,
                carryYards: e.carryYards,
                carrySd: e.carrySd,
                lateralSd: e.lateralSd,
                createdAt: now,
                updatedAt: now
            )
        }
    }
}
