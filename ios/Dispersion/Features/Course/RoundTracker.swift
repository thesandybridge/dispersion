// Round tracking state machine. Manages hole-by-hole GPS shot logging
// during an on-course round.

import SwiftData
import SwiftUI

@MainActor
@Observable
public final class RoundTracker {
    public enum State: Equatable {
        case idle
        case awaitingTeeShot(hole: Int)
        case holeInProgress(hole: Int, shotCount: Int)
        case holeFinished(hole: Int)
        case roundComplete
    }

    public var state: State = .idle
    public var courseId: String = ""
    public var sessionId: String = ""
    public var currentHole: Int = 1
    public var shots: [CourseShot] = []
    public var scores: [Int: HoleScore] = [:]
    public var lastPosition: Coord?
    public var holeCount: Int = 18
    public var startHole: Int = 1
    public var lastHole: Int { startHole + holeCount - 1 }
    public var startedAt: Date = .now
    var watchFinishedCommands: [String] = []

    public func startRound(courseId: String, holeCount: Int, startHole: Int = 1) {
        self.courseId = courseId
        self.sessionId = UUID().uuidString.lowercased()
        self.holeCount = holeCount
        self.startHole = startHole
        self.currentHole = startHole
        self.shots = []
        self.scores = [:]
        self.startedAt = .now
        self.watchFinishedCommands = []
        self.state = .awaitingTeeShot(hole: startHole)
        initScores()
    }

    public func logShot(from: Coord, to: Coord, clubId: String?, accuracy: Double) {
        let shotNumber = shots.filter { $0.holeNumber == currentHole }.count + 1
        var shot = CourseShot(
            id: UUID().uuidString.lowercased(),
            courseId: courseId,
            holeNumber: currentHole,
            shotNumber: shotNumber,
            clubId: clubId,
            startLat: from.lat, startLng: from.lng,
            endLat: to.lat, endLng: to.lng,
            accuracy: accuracy
        )
        shot.sessionId = sessionId
        shots.append(shot)
        lastPosition = to
        state = .holeInProgress(hole: currentHole, shotCount: shotNumber)

        // Auto-update score to match shot count + putts estimate
        if var score = scores[currentHole] {
            score.score = shotsForHole(currentHole).filter { !$0.isPenalty }.count + score.penaltyStrokes + (score.putts ?? 0)
            scores[currentHole] = score
        }
    }

    public func undoLastShot() -> CourseShot? {
        guard let last = shots.last, last.holeNumber == currentHole else { return nil }
        removeCourseShot(id: last.id)
        let remaining = shotsForHole(currentHole).filter { !$0.isPenalty }.count
        state = remaining > 0
            ? .holeInProgress(hole: currentHole, shotCount: remaining)
            : .awaitingTeeShot(hole: currentHole)
        return last
    }

    public func acceptWatchShot(_ shot: CourseShot) {
        guard !shots.contains(where: { $0.id == shot.id }) else { return }
        shots.append(shot)
        let count = shotsForHole(shot.holeNumber).filter { !$0.isPenalty }.count
        if var score = scores[shot.holeNumber] {
            if shot.isPenalty { score.penaltyStrokes += shot.strokeCount; score.score += shot.strokeCount }
            score.score = max(score.score, count + (score.putts ?? 0) + score.penaltyStrokes)
            scores[shot.holeNumber] = score
        }
        if shot.holeNumber == currentHole && !shot.isPenalty {
            lastPosition = Coord(lat: shot.endLat, lng: shot.endLng)
            state = .holeInProgress(hole: currentHole, shotCount: count)
        }
    }

    public func replaceCourseShot(_ shot: CourseShot) {
        guard let index = shots.firstIndex(where: { $0.id == shot.id }) else { return }
        shots[index] = shot
        save()
    }

    public func removeCourseShot(id: String) {
        guard let index = shots.firstIndex(where: { $0.id == id }) else { return }
        let shot = shots.remove(at: index)
        if var score = scores[shot.holeNumber] {
            score.score = max(0, score.score - shot.strokeCount)
            if shot.isPenalty { score.penaltyStrokes = max(0, score.penaltyStrokes - shot.strokeCount) }
            scores[shot.holeNumber] = score
        }
        if shot.holeNumber == currentHole {
            lastPosition = shotsForHole(currentHole).last(where: { !$0.isPenalty }).map { Coord(lat: $0.endLat, lng: $0.endLng) }
        }
        save()
    }

    public func finishHole(score: Int? = nil) {
        if let s = score { scores[currentHole]?.score = s }
        state = .holeFinished(hole: currentHole)
    }

    public func nextHole() {
        if currentHole >= lastHole {
            state = .roundComplete
        } else {
            currentHole += 1
            lastPosition = nil
            state = .awaitingTeeShot(hole: currentHole)
        }
    }

    public func setPenalties(hole: Int, count: Int) {
        guard var value = scores[hole] else { return }
        let next = max(0, min(15, count))
        value.score = max(0, value.score + next - value.penaltyStrokes)
        value.penaltyStrokes = next
        scores[hole] = value
        save()
    }

    public func setPutts(hole: Int, count: Int) {
        guard var value = scores[hole] else { return }
        let next = max(0, min(15, count))
        let strokes = shotsForHole(hole).filter { !$0.isPenalty }.count
        value.score = max(strokes + next + value.penaltyStrokes, value.score + next - (value.putts ?? 0))
        value.putts = next
        scores[hole] = value
        save()
    }

    public func setScore(hole: Int, score: Int) {
        scores[hole]?.score = score
    }

    public func setPar(hole: Int, par: Int) {
        scores[hole]?.par = par
    }

    public var totalScore: Int {
        scores.values.filter { $0.score > 0 }.reduce(0) { $0 + $1.score }
    }

    public var totalPar: Int {
        scores.values.filter { $0.score > 0 }.reduce(0) { $0 + $1.par }
    }

    public var toPar: Int { totalScore - totalPar }

    public var holesPlayed: Int {
        scores.values.filter { $0.score > 0 }.count
    }

    public func shotsForHole(_ hole: Int) -> [CourseShot] {
        shots.filter { $0.holeNumber == hole }.sorted { $0.shotNumber < $1.shotNumber }
    }

    private func initScores() {
        for h in startHole...lastHole {
            scores[h] = HoleScore(hole: h, par: 4, score: 0)
        }
    }

    // MARK: - Persistence

    var hasSavedRound: Bool { UserDefaults.standard.data(forKey: saveKey) != nil }

    private var saveKey: String { "activeRound.\(courseId)" }

    public func save() {
        let data = RoundData(
            courseId: courseId,
            sessionId: sessionId,
            currentHole: currentHole,
            holeCount: holeCount,
            startHole: startHole,
            scores: scores,
            shots: shots,
            startedAt: startedAt,
            watchFinishedCommands: watchFinishedCommands,
            lastPosition: lastPosition
        )
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }

    public func loadIfExists(courseId: String) -> Bool {
        let key = "activeRound.\(courseId)"
        guard let data = UserDefaults.standard.data(forKey: key),
              let round = try? JSONDecoder().decode(RoundData.self, from: data)
        else { return false }
        self.courseId = round.courseId
        self.sessionId = round.sessionId
        self.currentHole = round.currentHole
        self.holeCount = round.holeCount
        self.startHole = round.startHole ?? 1
        self.scores = round.scores
        self.shots = round.shots
        self.lastPosition = round.lastPosition
        self.startedAt = round.startedAt
        self.watchFinishedCommands = round.watchFinishedCommands ?? []
        self.state = .holeInProgress(hole: currentHole, shotCount: shotsForHole(currentHole).count)
        return true
    }

    public func clearSave() {
        UserDefaults.standard.removeObject(forKey: saveKey)
    }

    // Round stats
    public var totalPutts: Int {
        scores.values.compactMap(\.putts).reduce(0, +)
    }
    public var fairwaysHit: Int {
        scores.values.filter { $0.fairwayHit == true }.count
    }
    public var fairwaysTotal: Int {
        scores.values.filter { $0.par >= 4 && $0.score > 0 }.count
    }
    public var greensHit: Int {
        scores.values.filter { $0.girHit == true }.count
    }
    public var upAndDowns: Int {
        scores.values.filter { $0.upAndDown == true }.count
    }
    public var upAndDownAttempts: Int {
        scores.values.filter { $0.girHit == false && $0.score > 0 }.count
    }
}

private struct RoundData: Codable {
    var courseId: String
    var sessionId: String
    var currentHole: Int
    var holeCount: Int
    var startHole: Int?  // optional for backward compat with saved rounds
    var scores: [Int: HoleScore]
    var shots: [CourseShot]
    var startedAt: Date
    var watchFinishedCommands: [String]?
    var lastPosition: Coord?
}
