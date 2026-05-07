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
    public var startedAt: Date = .now

    public func startRound(courseId: String, holeCount: Int) {
        self.courseId = courseId
        self.sessionId = UUID().uuidString.lowercased()
        self.holeCount = holeCount
        self.currentHole = 1
        self.shots = []
        self.scores = [:]
        self.startedAt = .now
        self.state = .awaitingTeeShot(hole: 1)
        initScores()
    }

    public func logShot(from: Coord, to: Coord, clubId: String?, accuracy: Double) {
        let shotNumber = shots.filter { $0.holeNumber == currentHole }.count + 1
        let shot = CourseShot(
            id: UUID().uuidString.lowercased(),
            courseId: courseId,
            holeNumber: currentHole,
            shotNumber: shotNumber,
            clubId: clubId,
            startLat: from.lat, startLng: from.lng,
            endLat: to.lat, endLng: to.lng,
            accuracy: accuracy
        )
        shots.append(shot)
        lastPosition = to
        state = .holeInProgress(hole: currentHole, shotCount: shotNumber)

        // Auto-update score to match shot count + putts estimate
        if scores[currentHole] != nil {
            scores[currentHole]?.score = shotNumber
        }
    }

    public func undoLastShot() -> CourseShot? {
        guard let last = shots.last, last.holeNumber == currentHole else { return nil }
        shots.removeLast()
        let remaining = shots.filter { $0.holeNumber == currentHole }.count
        state = remaining > 0
            ? .holeInProgress(hole: currentHole, shotCount: remaining)
            : .awaitingTeeShot(hole: currentHole)
        scores[currentHole]?.score = remaining
        return last
    }

    public func finishHole(score: Int? = nil) {
        if let s = score { scores[currentHole]?.score = s }
        state = .holeFinished(hole: currentHole)
    }

    public func nextHole() {
        if currentHole >= holeCount {
            state = .roundComplete
        } else {
            currentHole += 1
            lastPosition = nil
            state = .awaitingTeeShot(hole: currentHole)
        }
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
        for h in 1...holeCount {
            scores[h] = HoleScore(hole: h, par: 4, score: 0)
        }
    }

    // MARK: - Persistence

    private var saveKey: String { "activeRound.\(courseId)" }

    public func save() {
        let data = RoundData(
            courseId: courseId,
            sessionId: sessionId,
            currentHole: currentHole,
            holeCount: holeCount,
            scores: scores,
            shots: shots,
            startedAt: startedAt
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
        self.scores = round.scores
        self.shots = round.shots
        self.startedAt = round.startedAt
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
    var scores: [Int: HoleScore]
    var shots: [CourseShot]
    var startedAt: Date
}
