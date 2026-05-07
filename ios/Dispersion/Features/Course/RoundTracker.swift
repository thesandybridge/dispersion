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
    public var currentHole: Int = 1
    public var shots: [CourseShot] = []
    public var scores: [Int: HoleScore] = [:]  // hole number → score
    public var lastPosition: Coord?
    public var holeCount: Int = 18

    public func startRound(courseId: String, holeCount: Int) {
        self.courseId = courseId
        self.holeCount = holeCount
        self.currentHole = 1
        self.shots = []
        self.scores = [:]
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
}
