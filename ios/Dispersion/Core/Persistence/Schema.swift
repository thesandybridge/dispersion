// SwiftData persistence layer. Replaces the drizzle/SQLite setup in
// app/src/db/. The @Model classes below are the on-disk representation;
// repository functions in this folder convert to/from the value types in
// Core/Models/Models.swift so the rest of the app never touches SwiftData
// directly.

import Foundation
import SwiftData

@Model
public final class ClubModel {
    @Attribute(.unique) public var id: String
    public var name: String
    public var carryYards: Double
    public var carrySd: Double
    public var lateralSd: Double
    public var createdAt: Date
    public var updatedAt: Date

    // Optional swing-variant calibration. SwiftData lightweight migration
    // assigns nil to legacy rows. Stored as flat columns rather than a
    // nested struct so the schema is easy to evolve.
    public var threeQuarterCarryYards: Double?
    public var threeQuarterCarrySd: Double?
    public var threeQuarterLateralSd: Double?
    public var threeQuarterSamples: Int?

    public var halfCarryYards: Double?
    public var halfCarrySd: Double?
    public var halfLateralSd: Double?
    public var halfSamples: Int?

    public init(
        id: String,
        name: String,
        carryYards: Double,
        carrySd: Double,
        lateralSd: Double,
        createdAt: Date,
        updatedAt: Date,
        threeQuarter: SwingProfile? = nil,
        half: SwingProfile? = nil
    ) {
        self.id = id
        self.name = name
        self.carryYards = carryYards
        self.carrySd = carrySd
        self.lateralSd = lateralSd
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.threeQuarterCarryYards = threeQuarter?.carryYards
        self.threeQuarterCarrySd = threeQuarter?.carrySd
        self.threeQuarterLateralSd = threeQuarter?.lateralSd
        self.threeQuarterSamples = threeQuarter?.sampleCount
        self.halfCarryYards = half?.carryYards
        self.halfCarrySd = half?.carrySd
        self.halfLateralSd = half?.lateralSd
        self.halfSamples = half?.sampleCount
    }

    public func toValue() -> Club {
        Club(
            id: id,
            name: name,
            carryYards: carryYards,
            carrySd: carrySd,
            lateralSd: lateralSd,
            threeQuarter: swingProfile(
                carry: threeQuarterCarryYards,
                carrySd: threeQuarterCarrySd,
                lateralSd: threeQuarterLateralSd,
                samples: threeQuarterSamples
            ),
            half: swingProfile(
                carry: halfCarryYards,
                carrySd: halfCarrySd,
                lateralSd: halfLateralSd,
                samples: halfSamples
            ),
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private func swingProfile(
        carry: Double?,
        carrySd: Double?,
        lateralSd: Double?,
        samples: Int?
    ) -> SwingProfile? {
        guard let carry, let carrySd, let lateralSd else { return nil }
        return SwingProfile(
            carryYards: carry,
            carrySd: carrySd,
            lateralSd: lateralSd,
            sampleCount: samples ?? 0
        )
    }
}

@Model
public final class SessionModel {
    @Attribute(.unique) public var id: String
    public var kindRaw: String
    public var label: String
    public var createdAt: Date

    public init(id: String, kindRaw: String, label: String, createdAt: Date) {
        self.id = id
        self.kindRaw = kindRaw
        self.label = label
        self.createdAt = createdAt
    }

    public var kind: SessionKind {
        SessionKind(rawValue: kindRaw) ?? .range
    }

    public func toValue() -> Session {
        Session(id: id, kind: kind, label: label, createdAt: createdAt)
    }
}

@Model
public final class ShotModel {
    @Attribute(.unique) public var id: String
    public var sessionId: String
    public var clubId: String
    public var targetDistanceYards: Double
    public var longDelta: Double
    public var latDelta: Double
    /// CSV-encoded outcome tag set, see `Outcomes.encode`.
    public var outcomeRaw: String
    public var timestamp: Date
    /// SwingType raw value. Defaults to "full" so existing rows migrate cleanly
    /// (SwiftData lightweight migration assigns the default to legacy rows).
    public var swingTypeRaw: String = SwingType.full.rawValue

    public init(
        id: String,
        sessionId: String,
        clubId: String,
        targetDistanceYards: Double,
        longDelta: Double,
        latDelta: Double,
        outcomeRaw: String,
        timestamp: Date,
        swingTypeRaw: String = SwingType.full.rawValue
    ) {
        self.id = id
        self.sessionId = sessionId
        self.clubId = clubId
        self.targetDistanceYards = targetDistanceYards
        self.longDelta = longDelta
        self.latDelta = latDelta
        self.outcomeRaw = outcomeRaw
        self.timestamp = timestamp
        self.swingTypeRaw = swingTypeRaw
    }

    public func toValue() -> Shot {
        Shot(
            id: id,
            sessionId: sessionId,
            clubId: clubId,
            targetDistanceYards: targetDistanceYards,
            longDelta: longDelta,
            latDelta: latDelta,
            outcomes: Outcomes.decode(outcomeRaw),
            timestamp: timestamp,
            swingType: SwingType(rawValue: swingTypeRaw) ?? .full
        )
    }
}

@Model
public final class FaceStrikeModel {
    @Attribute(.unique) public var id: String
    public var clubId: String
    public var x: Double
    public var y: Double
    public var timestamp: Date

    public init(id: String, clubId: String, x: Double, y: Double, timestamp: Date) {
        self.id = id
        self.clubId = clubId
        self.x = x
        self.y = y
        self.timestamp = timestamp
    }

    public func toValue() -> FaceStrike {
        FaceStrike(id: id, clubId: clubId, x: x, y: y, timestamp: timestamp)
    }
}
