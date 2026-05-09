// Value types for the putter domain. Lives alongside Club + Shot but
// stays deliberately separate — putting is about distance control on the
// green, not aerial dispersion, so the carry/σ↕/σ↔ vocabulary doesn't
// belong here.

import Foundation

// MARK: - Putter

public enum PutterHeadType: String, Codable, CaseIterable, Sendable {
    case blade, mid, mallet

    public var label: String { rawValue.capitalized }
}

public struct Putter: Identifiable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var lengthInches: Double      // typical: 32–36
    public var headType: PutterHeadType
    public var loftDegrees: Double       // typical: 2–4
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String,
        name: String,
        lengthInches: Double,
        headType: PutterHeadType,
        loftDegrees: Double,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.lengthInches = lengthInches
        self.headType = headType
        self.loftDegrees = loftDegrees
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Putt

public enum PuttContext: String, Codable, CaseIterable, Sendable {
    case practice    // Range mode putt logging
    case round       // Logged during a course round
}

/// One putt attempt. `made == false` requires a non-nil `residualFeet` so
/// we can compute lag accuracy. Optional `landingX/landingY` (in feet,
/// relative to the cup, positive Y = past) is set when the user taps a
/// landing point on the green visual.
public struct Putt: Identifiable, Hashable, Sendable {
    public let id: String
    public let putterId: String
    public let sessionId: String?
    public let distanceFeet: Double
    public let made: Bool
    public let residualFeet: Double?
    public let landingX: Double?
    public let landingY: Double?
    public let context: PuttContext
    public let timestamp: Date

    public init(
        id: String,
        putterId: String,
        sessionId: String?,
        distanceFeet: Double,
        made: Bool,
        residualFeet: Double?,
        landingX: Double? = nil,
        landingY: Double? = nil,
        context: PuttContext,
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
        self.context = context
        self.timestamp = timestamp
    }
}

// MARK: - Distance brackets + stats

/// Bracketing inspired by the PGA Tour strokes-gained reference. Short
/// putts are essentially gimmes; long is anything past lag-putt territory.
public enum PuttDistanceBracket: String, CaseIterable, Sendable {
    case short    // 0–3 ft
    case shortMid // 3–6 ft
    case mid      // 6–15 ft
    case lag      // 15–30 ft
    case long     // 30+ ft

    public static func of(_ feet: Double) -> PuttDistanceBracket {
        switch feet {
        case ..<3:   return .short
        case 3..<6:  return .shortMid
        case 6..<15: return .mid
        case 15..<30: return .lag
        default:     return .long
        }
    }

    public var label: String {
        switch self {
        case .short:    return "0–3 ft"
        case .shortMid: return "3–6 ft"
        case .mid:      return "6–15 ft"
        case .lag:      return "15–30 ft"
        case .long:     return "30+ ft"
        }
    }

    public var shortLabel: String {
        switch self {
        case .short:    return "0–3"
        case .shortMid: return "3–6"
        case .mid:      return "6–15"
        case .lag:      return "15–30"
        case .long:     return "30+"
        }
    }
}

public struct PutterStats: Sendable {
    public let totalPutts: Int
    public let totalMakes: Int
    public let bracketStats: [PuttDistanceBracket: BracketStats]
    /// Average residual distance on missed putts (feet). nil if no misses
    /// have a residual recorded.
    public let avgLagProximity: Double?
    public let sessionsCount: Int

    public struct BracketStats: Sendable {
        public let attempts: Int
        public let makes: Int
        public var makePct: Double {
            attempts > 0 ? Double(makes) / Double(attempts) : 0
        }
    }

    public var overallMakePct: Double {
        totalPutts > 0 ? Double(totalMakes) / Double(totalPutts) : 0
    }

    public static let empty = PutterStats(
        totalPutts: 0,
        totalMakes: 0,
        bracketStats: [:],
        avgLagProximity: nil,
        sessionsCount: 0
    )
}

public enum PutterStatsEngine {
    public static func compute(_ putts: [Putt]) -> PutterStats {
        guard !putts.isEmpty else { return .empty }

        var byBracket: [PuttDistanceBracket: (attempts: Int, makes: Int)] = [:]
        for putt in putts {
            let b = PuttDistanceBracket.of(putt.distanceFeet)
            var entry = byBracket[b] ?? (0, 0)
            entry.attempts += 1
            if putt.made { entry.makes += 1 }
            byBracket[b] = entry
        }
        let bracketStats = byBracket.mapValues {
            PutterStats.BracketStats(attempts: $0.attempts, makes: $0.makes)
        }

        let misses = putts.filter { !$0.made }
        let residuals = misses.compactMap { $0.residualFeet }
        let avgLag: Double? = residuals.isEmpty
            ? nil
            : residuals.reduce(0, +) / Double(residuals.count)

        let sessions = Set(putts.compactMap { $0.sessionId }).count

        return PutterStats(
            totalPutts: putts.count,
            totalMakes: putts.filter { $0.made }.count,
            bracketStats: bracketStats,
            avgLagProximity: avgLag,
            sessionsCount: sessions
        )
    }
}

// MARK: - Defaults

public enum PutterDefaults {
    public static let lengthInches: Double = 34.0
    public static let loftDegrees: Double = 3.0
    public static let headType: PutterHeadType = .blade
}
