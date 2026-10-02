import Foundation

struct WatchPoint: Codable, Equatable, Sendable {
    var latitude: Double
    var longitude: Double

    var isValid: Bool {
        latitude.isFinite && longitude.isFinite
            && (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }
}

struct WatchClub: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var name: String
    var carryYards: Double
}

struct WatchRound: Codable, Equatable, Sendable {
    var sessionId: String
    var courseId: String
    var courseName: String
    var hole: Int
    var par: Int
    var target: WatchPoint?
    var clubs: [WatchClub]
    var usesMeters: Bool
    var score: Int? = nil
    var putts: Int? = nil
    var penalties: Int? = nil
    var lastHole: Int? = nil
    var green: [WatchPoint]? = nil
}

struct WatchHoleFinish: Codable, Equatable, Identifiable, Sendable {
    var id: String = UUID().uuidString.lowercased()
    var sessionId: String
    var courseId: String
    var hole: Int
    var score: Int
    var putts: Int
    var penalties: Int

    var isValid: Bool {
        !id.isEmpty && !sessionId.isEmpty && !courseId.isEmpty
            && (1...18).contains(hole) && (1...30).contains(score)
            && (0...15).contains(putts) && (0...15).contains(penalties)
            && putts + penalties <= score
    }
}

struct WatchMark: Codable, Equatable, Sendable {
    var id: String = UUID().uuidString.lowercased()
    var sessionId: String
    var courseId: String
    var hole: Int
    var clubId: String
    var point: WatchPoint
    var accuracy: Double
    var timestamp: Date = .now
}

struct WatchShot: Codable, Equatable, Identifiable, Sendable {
    var excludedFromDistances: Bool? = nil
    var start: WatchMark
    var end: WatchPoint
    var endAccuracy: Double
    var id: String { start.id }

    var isValid: Bool {
        !id.isEmpty && !start.sessionId.isEmpty && !start.courseId.isEmpty
            && !start.clubId.isEmpty && (1...18).contains(start.hole)
            && start.point.isValid && end.isValid
            && start.accuracy.isFinite && (0...20).contains(start.accuracy)
            && endAccuracy.isFinite && (0...20).contains(endAccuracy)
            && start.timestamp.timeIntervalSince1970.isFinite
    }
}

// A completed shot stays on disk until the phone acknowledges its ID.
struct WatchShotQueue: Codable {
    var pending: WatchMark?
    var shots: [WatchShot] = []
    var holeFinish: WatchHoleFinish? = nil
    var completedCounts: [String: Int]? = nil
    var history: [WatchShot]? = nil
    var edits: [WatchEdit]? = nil
    var penaltyTotals: [String: Int]? = nil

    func completedCount(sessionId: String, hole: Int) -> Int {
        completedCounts?["\(sessionId):\(hole)"] ?? 0
    }

    private mutating func append(_ shot: WatchShot) {
        shots.append(shot)
        if history == nil { history = [] }
        history?.append(shot)
        history = Array((history ?? []).suffix(100))
        let key = "\(shot.start.sessionId):\(shot.start.hole)"
        if completedCounts == nil { completedCounts = [:] }
        completedCounts?[key, default: 0] += 1
    }

    mutating func mark(_ mark: WatchMark) throws {
        guard holeFinish == nil else { throw QueueError.finishingHole }
        if let pending {
            guard pending.sessionId == mark.sessionId, pending.hole == mark.hole,
                  pending.courseId == mark.courseId else { throw QueueError.differentHole }
            append(WatchShot(start: pending, end: mark.point, endAccuracy: mark.accuracy))
        }
        pending = mark
    }

    mutating func finish(at point: WatchPoint, accuracy: Double) {
        guard let pending else { return }
        append(WatchShot(start: pending, end: point, endAccuracy: accuracy))
        self.pending = nil
    }

    mutating func acknowledge(_ ids: Set<String>) {
        shots.removeAll { ids.contains($0.id) }
        edits?.removeAll { ids.contains($0.id) }
        if let finish = holeFinish, ids.contains(finish.id) { holeFinish = nil }
    }

    mutating func addEdit(_ edit: WatchEdit) {
        if edits == nil { edits = [] }
        edits?.append(edit)
        if edit.kind == .deleteShot, let shotId = edit.shotId {
            if let shot = history?.first(where: { $0.id == shotId }) {
                let key = "\(shot.start.sessionId):\(shot.start.hole)"
                let remaining = max(0, (completedCounts?[key] ?? 0) - 1)
                completedCounts?[key] = remaining
            }
            history?.removeAll { $0.id == shotId }
        }
        if edit.kind == .changeClub, let index = history?.firstIndex(where: { $0.id == edit.shotId }), let clubId = edit.clubId {
            history?[index].start.clubId = clubId
        }
    }

    mutating func addPenalty(for round: WatchRound, strokes: Int, endPending: Bool) {
        guard (1...2).contains(strokes), holeFinish == nil else { return }
        if endPending, let pending {
            append(WatchShot(excludedFromDistances: true, start: pending, end: pending.point, endAccuracy: pending.accuracy))
            self.pending = nil
        }
        let key = "\(round.sessionId):\(round.hole)"
        if penaltyTotals == nil { penaltyTotals = [:] }
        let total = max(penaltyTotals?[key] ?? 0, round.penalties ?? 0) + strokes
        penaltyTotals?[key] = total
        addEdit(WatchEdit(sessionId: round.sessionId, courseId: round.courseId, hole: round.hole, kind: .penalty, strokes: strokes))
    }

    enum QueueError: Error { case differentHole, finishingHole }
}

struct WatchEdit: Codable, Equatable, Identifiable, Sendable {
    enum Kind: String, Codable { case deleteShot, changeClub, penalty }
    var id: String = UUID().uuidString.lowercased()
    var sessionId: String
    var courseId: String
    var hole: Int
    var kind: Kind
    var shotId: String? = nil
    var clubId: String? = nil
    var strokes: Int? = nil

    var isValid: Bool {
        guard !id.isEmpty, !sessionId.isEmpty, !courseId.isEmpty, (1...18).contains(hole) else { return false }
        switch kind {
        case .deleteShot: return shotId?.isEmpty == false
        case .changeClub: return shotId?.isEmpty == false && clubId?.isEmpty == false
        case .penalty: return (1...2).contains(strokes ?? 0)
        }
    }
}

extension WatchPoint {
    func yards(to other: WatchPoint) -> Double {
        let radians = Double.pi / 180
        let a = pow(sin((other.latitude - latitude) * radians / 2), 2)
            + cos(latitude * radians) * cos(other.latitude * radians)
            * pow(sin((other.longitude - longitude) * radians / 2), 2)
        return 6_371_000 * 1.0936133 * 2 * atan2(sqrt(min(1, a)), sqrt(max(0, 1 - a)))
    }
}

struct GreenYardages: Equatable {
    var front: Double
    var middle: Double
    var back: Double

    static func measure(from origin: WatchPoint, polygon: [WatchPoint]) -> GreenYardages? {
        guard origin.isValid, polygon.count >= 3, polygon.allSatisfy(\.isValid) else { return nil }
        let center = WatchPoint(latitude: polygon.map(\.latitude).reduce(0, +) / Double(polygon.count),
                                longitude: polygon.map(\.longitude).reduce(0, +) / Double(polygon.count))
        let distances = polygon.map { origin.yards(to: $0) }
        guard let near = distances.min(), let far = distances.max() else { return nil }
        // Approximate mapped edges; these are not surveyed pin distances.
        return GreenYardages(front: near, middle: origin.yards(to: center), back: far)
    }
}
