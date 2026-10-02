// Full app backup — clubs, sessions, shots, face strikes, courses, hole
// infos, and polygons. Everything the user has built, locally.

import Foundation

public enum Backup {

    // MARK: - Export

    public static func build(
        clubs: [Club], sessions: [Session], shots: [Shot],
        faceStrikes: [FaceStrike] = [],
        courses: [Course] = [], holeInfos: [HoleInfo] = [], polygons: [CoursePolygon] = [],
        courseShots: [CourseShot] = [], rounds: [RoundSummary] = []
    ) -> Data {
        let iso = ISO8601DateFormatter()
        let payload = BackupPayload(
            version: 4,
            exportedAt: iso.string(from: .now),
            clubs: clubs.map { c in
                .init(id: c.id, name: c.name, carryYards: c.carryYards,
                      carrySd: c.carrySd, lateralSd: c.lateralSd,
                      createdAt: iso.string(from: c.createdAt),
                      updatedAt: iso.string(from: c.updatedAt))
            },
            sessions: sessions.map { s in
                .init(id: s.id, kind: s.kind.rawValue, label: s.label,
                      startedAt: iso.string(from: s.createdAt))
            },
            shots: shots.map { s in
                .init(id: s.id, sessionId: s.sessionId, clubId: s.clubId,
                      targetDistanceYards: s.targetDistanceYards,
                      longDelta: s.longDelta, latDelta: s.latDelta,
                      outcome: s.outcomes.isEmpty ? nil : Outcomes.encode(s.outcomes),
                      timestamp: iso.string(from: s.timestamp))
            },
            faceStrikes: faceStrikes.map { f in
                .init(id: f.id, clubId: f.clubId, x: f.x, y: f.y,
                      timestamp: iso.string(from: f.timestamp))
            },
            courses: courses.map { c in
                .init(id: c.id, name: c.name, centerLat: c.centerLat, centerLng: c.centerLng,
                      holeCount: c.holeCount)
            },
            holeInfos: holeInfos,
            polygons: polygons.map { p in
                .init(id: p.id, courseId: p.courseId, holeNumber: p.holeNumber ?? 0,
                      surface: p.surface.rawValue, coordinates: p.coordinates)
            },
            courseShots: courseShots,
            rounds: rounds
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? encoder.encode(payload)) ?? Data()
    }

    // MARK: - Import

    public struct ParsedBackup {
        public var clubs: [Club]
        public var sessions: [Session]
        public var shots: [Shot]
        public var faceStrikes: [FaceStrike]
        public var courses: [Course]
        public var holeInfos: [HoleInfo]
        public var polygons: [CoursePolygon]
        public var courseShots: [CourseShot]
        public var rounds: [RoundSummary]
        public var warnings: [String]
    }

    public static func parse(_ data: Data) throws -> ParsedBackup {
        let payload = try JSONDecoder().decode(BackupPayload.self, from: data)
        guard (1...4).contains(payload.version) else {
            throw BackupError.unsupportedVersion(payload.version)
        }
        let iso = ISO8601DateFormatter()
        var warnings: [String] = []

        // Clubs
        var clubs: [Club] = []
        for c in payload.clubs {
            let name = c.name.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else {
                warnings.append("Skipped club with empty name (id: \(c.id))")
                continue
            }
            guard c.carryYards.isFinite, c.carryYards >= 0,
                  c.carrySd.isFinite, c.carrySd >= 0,
                  c.lateralSd.isFinite, c.lateralSd >= 0 else {
                warnings.append("Skipped club '\(name)' with invalid values")
                continue
            }
            let createdAt = iso.date(from: c.createdAt)
            let updatedAt = c.updatedAt.flatMap { iso.date(from: $0) }
            clubs.append(Club(
                id: c.id, name: name,
                carryYards: c.carryYards, carrySd: c.carrySd, lateralSd: c.lateralSd,
                createdAt: createdAt ?? .now,
                updatedAt: updatedAt ?? createdAt ?? .now
            ))
        }

        // Sessions
        let sessions = (payload.sessions ?? []).map { s in
            Session(id: s.id, kind: SessionKind(rawValue: s.kind) ?? .round,
                    label: s.label, createdAt: iso.date(from: s.startedAt) ?? .now)
        }

        // Shots — validate refs
        let clubIds = Set(clubs.map(\.id))
        let sessionIds = Set(sessions.map(\.id))
        var shots: [Shot] = []
        for s in (payload.shots ?? []) {
            guard s.targetDistanceYards.isFinite, s.targetDistanceYards > 0,
                  s.longDelta.isFinite, s.latDelta.isFinite else { continue }
            if !clubIds.contains(s.clubId) {
                warnings.append("Skipped shot referencing unknown club (id: \(s.id))")
                continue
            }
            if !sessionIds.contains(s.sessionId) {
                warnings.append("Skipped shot referencing unknown session (id: \(s.id))")
                continue
            }
            shots.append(Shot(
                id: s.id, sessionId: s.sessionId, clubId: s.clubId,
                targetDistanceYards: s.targetDistanceYards,
                longDelta: s.longDelta, latDelta: s.latDelta,
                outcomes: s.outcome.map { Outcomes.decode($0) } ?? [],
                timestamp: iso.date(from: s.timestamp) ?? .now
            ))
        }

        // Face strikes
        let faceStrikes = (payload.faceStrikes ?? []).compactMap { f -> FaceStrike? in
            guard clubIds.contains(f.clubId) else { return nil }
            return FaceStrike(id: f.id, clubId: f.clubId, x: f.x, y: f.y,
                              timestamp: iso.date(from: f.timestamp) ?? .now)
        }

        // Courses
        let courses = (payload.courses ?? []).map { c in
            Course(id: c.id, name: c.name, centerLat: c.centerLat, centerLng: c.centerLng,
                   holeCount: c.holeCount)
        }
        let courseIds = Set(courses.map(\.id))

        // Hole infos — filter to valid courses
        let holeInfos = (payload.holeInfos ?? []).filter { courseIds.contains($0.courseId) }

        // Polygons
        let polygons = (payload.polygons ?? []).compactMap { p -> CoursePolygon? in
            guard courseIds.contains(p.courseId),
                  let surface = SurfaceType(rawValue: p.surface) else { return nil }
            return CoursePolygon(id: p.id, courseId: p.courseId,
                                holeNumber: p.holeNumber > 0 ? p.holeNumber : nil,
                                surface: surface, coordinates: p.coordinates)
        }

        return ParsedBackup(
            clubs: clubs, sessions: sessions, shots: shots,
            faceStrikes: faceStrikes,
            courses: courses, holeInfos: holeInfos, polygons: polygons,
            courseShots: (payload.courseShots ?? []).filter { courseIds.contains($0.courseId) && $0.distanceYards.isFinite && (1...18).contains($0.holeNumber) },
            rounds: (payload.rounds ?? []).filter { courseIds.contains($0.courseId) && (1...18).contains($0.holeCount) },
            warnings: warnings
        )
    }

    public enum BackupError: LocalizedError {
        case unsupportedVersion(Int)
        public var errorDescription: String? {
            switch self {
            case .unsupportedVersion(let v): return "Unsupported backup version: \(v)"
            }
        }
    }
}

// MARK: - Codable payload

private struct BackupPayload: Codable {
    var version: Int
    var exportedAt: String
    var clubs: [ClubEntry]
    var sessions: [SessionEntry]?
    var shots: [ShotEntry]?
    var faceStrikes: [FaceStrikeEntry]?
    var courses: [CourseEntry]?
    var holeInfos: [HoleInfo]?
    var polygons: [PolygonEntry]?
    var courseShots: [CourseShot]?
    var rounds: [RoundSummary]?

    struct ClubEntry: Codable {
        var id, name: String
        var carryYards, carrySd, lateralSd: Double
        var createdAt: String
        var updatedAt: String?
    }
    struct SessionEntry: Codable {
        var id, kind, label, startedAt: String
    }
    struct ShotEntry: Codable {
        var id, sessionId, clubId: String
        var targetDistanceYards, longDelta, latDelta: Double
        var outcome: String?
        var timestamp: String
    }
    struct FaceStrikeEntry: Codable {
        var id, clubId: String
        var x, y: Double
        var timestamp: String
    }
    struct CourseEntry: Codable {
        var id, name: String
        var centerLat, centerLng: Double
        var holeCount: Int
    }
    struct PolygonEntry: Codable {
        var id, courseId: String
        var holeNumber: Int
        var surface: String
        var coordinates: [Coord]
    }
}
