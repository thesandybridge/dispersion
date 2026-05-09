// Core value types. Mirror of app/src/types.ts.
//
// These are the in-memory shapes the rest of the app reasons about. The
// SwiftData layer (Core/Persistence/Schema.swift) defines @Model classes that
// project to/from these.

import Foundation

// MARK: Pin position

public enum PinPosition: String, CaseIterable, Sendable {
    case front, middle, back

    public var label: String { rawValue.capitalized }

    /// Shifts the effective target distance. Front = play shorter, back = play longer.
    /// Returns yards to add to the raw distance.
    public var distanceAdjustment: Double {
        switch self {
        case .front:  return -8
        case .middle: return 0
        case .back:   return 8
        }
    }
}

// MARK: Shot type — classifies shots for stat filtering

public enum ShotType: String, Codable, CaseIterable, Sendable {
    case full        // normal full swing — counts toward dispersion
    case threeQtr    // 3/4 swing — counts toward dispersion
    case half        // half swing — counts toward dispersion
    case chip        // around the green — excluded from dispersion
    case pitch       // short game — excluded from dispersion
    case punch       // recovery punch out — excluded from dispersion
    case sand        // bunker shot — excluded from dispersion
    case penalty     // drop/penalty — excluded from everything
    case putt        // on the green — excluded from dispersion

    public var label: String {
        switch self {
        case .full: return "Full"
        case .threeQtr: return "3/4"
        case .half: return "Half"
        case .chip: return "Chip"
        case .pitch: return "Pitch"
        case .punch: return "Punch"
        case .sand: return "Sand"
        case .penalty: return "Penalty"
        case .putt: return "Putt"
        }
    }

    public var countsForDispersion: Bool {
        switch self {
        case .full, .threeQtr, .half: return true
        case .chip, .pitch, .punch, .sand, .penalty, .putt: return false
        }
    }

    public var systemImage: String {
        switch self {
        case .full: return "arrow.up.right"
        case .threeQtr: return "arrow.up.right"
        case .half: return "arrow.up.right"
        case .chip: return "arrow.down.right"
        case .pitch: return "arrow.up.forward"
        case .punch: return "arrow.right"
        case .sand: return "sun.dust"
        case .penalty: return "exclamationmark.triangle"
        case .putt: return "circle.bottomhalf.filled"
        }
    }
}

// MARK: Swing type

public enum SwingType: String, Codable, CaseIterable, Sendable {
    case full
    case threeQuarter = "3/4"
    case half

    public var label: String {
        switch self {
        case .full: return "Full"
        case .threeQuarter: return "3/4"
        case .half: return "Half"
        }
    }

    /// Multiplier applied to carry distance relative to full swing.
    public var carryMultiplier: Double {
        switch self {
        case .full: return 1.0
        case .threeQuarter: return 0.85
        case .half: return 0.65
        }
    }

    /// Sigma tends to tighten on partial swings.
    public var sigmaMultiplier: Double {
        switch self {
        case .full: return 1.0
        case .threeQuarter: return 0.90
        case .half: return 0.80
        }
    }
}

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
    public var swingType: SwingType

    public init(
        id: String,
        sessionId: String,
        clubId: String,
        targetDistanceYards: Double,
        longDelta: Double,
        latDelta: Double,
        outcomes: Set<ShotOutcomeTag> = [],
        timestamp: Date = .now,
        swingType: SwingType = .full
    ) {
        self.id = id
        self.sessionId = sessionId
        self.clubId = clubId
        self.targetDistanceYards = targetDistanceYards
        self.longDelta = longDelta
        self.latDelta = latDelta
        self.outcomes = outcomes
        self.timestamp = timestamp
        self.swingType = swingType
    }
}

// MARK: Hole score (for round mode)

public struct HoleScore: Identifiable, Hashable, Codable, Sendable {
    public var id: Int { hole }
    public var hole: Int       // 1-18
    public var par: Int        // 3, 4, or 5
    public var score: Int      // actual strokes
    public var fairwayHit: Bool?
    public var girHit: Bool?   // green in regulation
    public var putts: Int?
    public var upAndDown: Bool?
    public var penaltyStrokes: Int = 0

    public init(hole: Int, par: Int = 4, score: Int = 0, fairwayHit: Bool? = nil, girHit: Bool? = nil, putts: Int? = nil, upAndDown: Bool? = nil) {
        self.hole = hole
        self.par = par
        self.score = score
        self.fairwayHit = fairwayHit
        self.girHit = girHit
        self.putts = putts
    }

    public var toPar: Int { score - par }

    public var label: String {
        if score == 1 { return "Hole in One" }
        switch toPar {
        case ..<(-2): return "Albatross"
        case -2: return "Eagle"
        case -1: return "Birdie"
        case 0: return "Par"
        case 1: return "Bogey"
        case 2: return "Double"
        case 3: return "Triple"
        default: return "+\(toPar)"
        }
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
    public var swingType: SwingType
    public var probabilityInZone: Double
    public var probabilityPenalty: Double
    public var expectedCarry: Double

    public var id: String {
        swingType == .full ? clubId : "\(clubId)_\(swingType.rawValue)"
    }

    public init(
        clubId: String,
        swingType: SwingType = .full,
        probabilityInZone: Double,
        probabilityPenalty: Double,
        expectedCarry: Double
    ) {
        self.clubId = clubId
        self.swingType = swingType
        self.probabilityInZone = probabilityInZone
        self.probabilityPenalty = probabilityPenalty
        self.expectedCarry = expectedCarry
    }
}
