// Core value types. Mirror of app/src/types.ts.
//
// These are the in-memory shapes the rest of the app reasons about. The
// SwiftData layer (Core/Persistence/Schema.swift) defines @Model classes that
// project to/from these.

import Foundation

// MARK: Club

public struct Club: Identifiable, Hashable, Sendable {
    public var id: String
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
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.carryYards = carryYards
        self.carrySd = carrySd
        self.lateralSd = lateralSd
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: Session

public enum SessionKind: String, Codable, CaseIterable, Sendable {
    case range
    case round
}

public struct Session: Identifiable, Hashable, Sendable {
    public var id: String
    public var kind: SessionKind
    public var label: String
    public var createdAt: Date

    public init(id: String, kind: SessionKind, label: String, createdAt: Date = .now) {
        self.id = id
        self.kind = kind
        self.label = label
        self.createdAt = createdAt
    }
}

// MARK: Shot

/// Outcome tag set. The TS version stores a comma-separated string; we keep
/// it strongly typed and serialize at the persistence boundary.
public enum ShotOutcomeTag: String, Codable, CaseIterable, Sendable {
    case `in`
    case short
    case long
    case left
    case right
    case penalty
}

public struct Shot: Identifiable, Hashable, Sendable {
    public var id: String
    public var sessionId: String
    public var clubId: String
    public var targetDistanceYards: Double
    public var longDelta: Double
    public var latDelta: Double
    public var outcomes: Set<ShotOutcomeTag>
    public var timestamp: Date

    public init(
        id: String,
        sessionId: String,
        clubId: String,
        targetDistanceYards: Double,
        longDelta: Double,
        latDelta: Double,
        outcomes: Set<ShotOutcomeTag> = [],
        timestamp: Date = .now
    ) {
        self.id = id
        self.sessionId = sessionId
        self.clubId = clubId
        self.targetDistanceYards = targetDistanceYards
        self.longDelta = longDelta
        self.latDelta = latDelta
        self.outcomes = outcomes
        self.timestamp = timestamp
    }
}

// MARK: Face strikes

public struct FaceStrike: Identifiable, Hashable, Sendable {
    public var id: String
    public var clubId: String
    public var x: Double          // -1...1, lateral on face
    public var y: Double          // -1...1, vertical on face
    public var timestamp: Date

    public init(id: String, clubId: String, x: Double, y: Double, timestamp: Date = .now) {
        self.id = id
        self.clubId = clubId
        self.x = x
        self.y = y
        self.timestamp = timestamp
    }
}

// MARK: Scenario / probability output

/// What the calculator screen evaluates against a bag of clubs.
public struct ShotScenario: Hashable, Sendable {
    public var distanceToTargetYards: Double
    public var safeZoneWidthYards: Double
    public var safeZoneDepthYards: Double
    public var penaltyZones: [PenaltyZone]

    public init(
        distanceToTargetYards: Double,
        safeZoneWidthYards: Double,
        safeZoneDepthYards: Double,
        penaltyZones: [PenaltyZone] = []
    ) {
        self.distanceToTargetYards = distanceToTargetYards
        self.safeZoneWidthYards = safeZoneWidthYards
        self.safeZoneDepthYards = safeZoneDepthYards
        self.penaltyZones = penaltyZones
    }
}

public struct PenaltyZone: Hashable, Sendable {
    /// Center of the penalty zone relative to the target (yards).
    public var centerLateral: Double
    public var centerLong: Double
    public var widthYards: Double
    public var depthYards: Double

    public init(centerLateral: Double, centerLong: Double, widthYards: Double, depthYards: Double) {
        self.centerLateral = centerLateral
        self.centerLong = centerLong
        self.widthYards = widthYards
        self.depthYards = depthYards
    }
}

/// Per-club ranking emitted by `Probability.rankClubs(...)`.
public struct ClubResult: Identifiable, Hashable, Sendable {
    public var clubId: String
    public var probabilityInZone: Double
    public var probabilityPenalty: Double
    public var expectedCarry: Double

    public var id: String { clubId }

    public init(
        clubId: String,
        probabilityInZone: Double,
        probabilityPenalty: Double,
        expectedCarry: Double
    ) {
        self.clubId = clubId
        self.probabilityInZone = probabilityInZone
        self.probabilityPenalty = probabilityPenalty
        self.expectedCarry = expectedCarry
    }
}
