// SwiftData persistence for the putter domain. Lives separate from
// ClubModel/ShotModel so the schemas don't leak into each other.

import Foundation
import SwiftData

@Model
public final class PutterModel {
    @Attribute(.unique) public var id: String
    public var name: String
    public var lengthInches: Double
    public var headTypeRaw: String
    public var loftDegrees: Double
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String,
        name: String,
        lengthInches: Double,
        headTypeRaw: String,
        loftDegrees: Double,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.lengthInches = lengthInches
        self.headTypeRaw = headTypeRaw
        self.loftDegrees = loftDegrees
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public func toValue() -> Putter {
        Putter(
            id: id,
            name: name,
            lengthInches: lengthInches,
            headType: PutterHeadType(rawValue: headTypeRaw) ?? .blade,
            loftDegrees: loftDegrees,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

@Model
public final class PuttModel {
    @Attribute(.unique) public var id: String
    public var putterId: String
    public var sessionId: String?
    public var distanceFeet: Double
    public var made: Bool
    public var residualFeet: Double?
    public var landingX: Double?
    public var landingY: Double?
    public var contextRaw: String
    public var timestamp: Date

    public init(
        id: String,
        putterId: String,
        sessionId: String?,
        distanceFeet: Double,
        made: Bool,
        residualFeet: Double?,
        landingX: Double?,
        landingY: Double?,
        contextRaw: String,
        timestamp: Date
    ) {
        self.id = id
        self.putterId = putterId
        self.sessionId = sessionId
        self.distanceFeet = distanceFeet
        self.made = made
        self.residualFeet = residualFeet
        self.landingX = landingX
        self.landingY = landingY
        self.contextRaw = contextRaw
        self.timestamp = timestamp
    }

    public func toValue() -> Putt {
        Putt(
            id: id,
            putterId: putterId,
            sessionId: sessionId,
            distanceFeet: distanceFeet,
            made: made,
            residualFeet: residualFeet,
            landingX: landingX,
            landingY: landingY,
            context: PuttContext(rawValue: contextRaw) ?? .practice,
            timestamp: timestamp
        )
    }
}
