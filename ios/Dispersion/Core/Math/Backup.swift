// Port of app/src/lib/backup.ts. JSON export/import of clubs, sessions, shots.

import Foundation

public enum Backup {

    // MARK: - Export

    public static func build(clubs: [Club], sessions: [Session], shots: [Shot]) -> Data {
        let iso = ISO8601DateFormatter()
        let payload = BackupPayload(
            version: 2,
            exportedAt: iso.string(from: .now),
            clubs: clubs.map { c in
                .init(
                    id: c.id,
                    name: c.name,
                    carryYards: c.carryYards,
                    carrySd: c.carrySd,
                    lateralSd: c.lateralSd,
                    createdAt: iso.string(from: c.createdAt),
                    updatedAt: iso.string(from: c.updatedAt)
                )
            },
            sessions: sessions.map { s in
                .init(
                    id: s.id,
                    kind: s.kind.rawValue,
                    label: s.label,
                    startedAt: iso.string(from: s.createdAt)
                )
            },
            shots: shots.map { s in
                .init(
                    id: s.id,
                    sessionId: s.sessionId,
                    clubId: s.clubId,
                    targetDistanceYards: s.targetDistanceYards,
                    longDelta: s.longDelta,
                    latDelta: s.latDelta,
                    outcome: s.outcomes.isEmpty ? nil : Outcomes.encode(s.outcomes),
                    timestamp: iso.string(from: s.timestamp)
                )
            }
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
        public var warnings: [String]
    }

    public static func parse(_ data: Data) throws -> ParsedBackup {
        let payload = try JSONDecoder().decode(BackupPayload.self, from: data)
        guard payload.version == 1 || payload.version == 2 else {
            throw BackupError.unsupportedVersion(payload.version)
        }
        let iso = ISO8601DateFormatter()
        var warnings: [String] = []

        // Clubs — validate each entry
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
                warnings.append("Skipped club '\(name)' with invalid numeric values")
                continue
            }
            let createdAt = iso.date(from: c.createdAt)
            if createdAt == nil {
                warnings.append("Club '\(name)' has malformed date, using import time")
            }
            let updatedAt = c.updatedAt.flatMap { iso.date(from: $0) }
            clubs.append(Club(
                id: c.id,
                name: name,
                carryYards: c.carryYards,
                carrySd: c.carrySd,
                lateralSd: c.lateralSd,
                createdAt: createdAt ?? .now,
                updatedAt: updatedAt ?? createdAt ?? .now
            ))
        }

        // Sessions
        let sessions = (payload.sessions ?? []).map { s in
            Session(
                id: s.id,
                kind: SessionKind(rawValue: s.kind) ?? .round,
                label: s.label,
                createdAt: iso.date(from: s.startedAt) ?? .now
            )
        }

        // Shots — validate and filter orphaned references
        let clubIds = Set(clubs.map(\.id))
        let sessionIds = Set(sessions.map(\.id))
        var shots: [Shot] = []
        for s in (payload.shots ?? []) {
            guard s.targetDistanceYards.isFinite, s.targetDistanceYards > 0,
                  s.longDelta.isFinite, s.latDelta.isFinite else {
                warnings.append("Skipped shot with invalid numeric values (id: \(s.id))")
                continue
            }
            if !clubIds.contains(s.clubId) {
                warnings.append("Skipped shot referencing unknown club (id: \(s.id))")
                continue
            }
            if !sessionIds.contains(s.sessionId) {
                warnings.append("Skipped shot referencing unknown session (id: \(s.id))")
                continue
            }
            shots.append(Shot(
                id: s.id,
                sessionId: s.sessionId,
                clubId: s.clubId,
                targetDistanceYards: s.targetDistanceYards,
                longDelta: s.longDelta,
                latDelta: s.latDelta,
                outcomes: s.outcome.map { Outcomes.decode($0) } ?? [],
                timestamp: iso.date(from: s.timestamp) ?? .now
            ))
        }

        return ParsedBackup(clubs: clubs, sessions: sessions, shots: shots, warnings: warnings)
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

    struct ClubEntry: Codable {
        var id: String
        var name: String
        var carryYards: Double
        var carrySd: Double
        var lateralSd: Double
        var createdAt: String
        var updatedAt: String?
    }

    struct SessionEntry: Codable {
        var id: String
        var kind: String
        var label: String
        var startedAt: String
    }

    struct ShotEntry: Codable {
        var id: String
        var sessionId: String
        var clubId: String
        var targetDistanceYards: Double
        var longDelta: Double
        var latDelta: Double
        var outcome: String?
        var timestamp: String
    }
}
