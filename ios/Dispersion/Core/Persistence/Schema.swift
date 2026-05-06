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

    public init(
        id: String,
        name: String,
        carryYards: Double,
        carrySd: Double,
        lateralSd: Double,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.carryYards = carryYards
        self.carrySd = carrySd
        self.lateralSd = lateralSd
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public func toValue() -> Club {
        Club(
            id: id,
            name: name,
            carryYards: carryYards,
            carrySd: carrySd,
            lateralSd: lateralSd,
            createdAt: createdAt,
            updatedAt: updatedAt
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

    public init(
        id: String,
        sessionId: String,
        clubId: String,
        targetDistanceYards: Double,
        longDelta: Double,
        latDelta: Double,
        outcomeRaw: String,
        timestamp: Date
    ) {
        self.id = id
        self.sessionId = sessionId
        self.clubId = clubId
        self.targetDistanceYards = targetDistanceYards
        self.longDelta = longDelta
        self.latDelta = latDelta
        self.outcomeRaw = outcomeRaw
        self.timestamp = timestamp
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
            timestamp: timestamp
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
