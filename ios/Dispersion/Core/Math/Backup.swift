// Port of app/src/lib/backup.ts. JSON export/import of clubs, sessions, shots.

import Foundation

public enum Backup {

    // MARK: - Export

    public static func build(clubs: [Club], sessions: [Session], shots: [Shot]) -> Data {
        let payload = BackupPayload(
            version: 2,
            exportedAt: ISO8601DateFormatter().string(from: .now),
            clubs: clubs.map { c in
                .init(
                    id: c.id,
                    name: c.name,
                    carryYards: c.carryYards,
                    carrySd: c.carrySd,
                    lateralSd: c.lateralSd,
                    createdAt: ISO8601DateFormatter().string(from: c.createdAt)
                )
            },
            sessions: sessions.map { s in
                .init(
                    id: s.id,
                    kind: s.kind.rawValue,
                    label: s.label,
                    startedAt: ISO8601DateFormatter().string(from: s.createdAt)
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
                    timestamp: ISO8601DateFormatter().string(from: s.timestamp)
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
    }

    public static func parse(_ data: Data) throws -> ParsedBackup {
        let payload = try JSONDecoder().decode(BackupPayload.self, from: data)
        guard payload.version == 1 || payload.version == 2 else {
            throw BackupError.unsupportedVersion(payload.version)
        }
        let iso = ISO8601DateFormatter()
        let clubs = payload.clubs.map { c in
            Club(
                id: c.id,
                name: c.name,
                carryYards: c.carryYards,
                carrySd: c.carrySd,
                lateralSd: c.lateralSd,
                createdAt: iso.date(from: c.createdAt) ?? .now,
                updatedAt: .now
            )
        }
        let sessions = (payload.sessions ?? []).map { s in
            Session(
                id: s.id,
                kind: SessionKind(rawValue: s.kind) ?? .round,
                label: s.label,
                createdAt: iso.date(from: s.startedAt) ?? .now
            )
        }
        let shots = (payload.shots ?? []).map { s in
            Shot(
                id: s.id,
                sessionId: s.sessionId,
                clubId: s.clubId,
                targetDistanceYards: s.targetDistanceYards,
                longDelta: s.longDelta,
                latDelta: s.latDelta,
                outcomes: s.outcome.map { Outcomes.decode($0) } ?? [],
                timestamp: iso.date(from: s.timestamp) ?? .now
            )
        }
        return ParsedBackup(clubs: clubs, sessions: sessions, shots: shots)
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
