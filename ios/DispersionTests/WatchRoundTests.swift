import Foundation
import Testing
import SwiftData
@testable import Dispersion

struct WatchRoundTests {
    @Test("A queued hole finish survives restart and only its receipt unlocks marking")
    func queuedHoleFinish() throws {
        var queue = WatchShotQueue()
        let finish = WatchHoleFinish(sessionId: "round", courseId: "course", hole: 1,
                                     score: 5, putts: 2, penalties: 1)
        queue.holeFinish = finish
        queue = try JSONDecoder().decode(WatchShotQueue.self, from: JSONEncoder().encode(queue))
        #expect(throws: WatchShotQueue.QueueError.self) { try queue.mark(mark("new")) }
        queue.acknowledge(["unrelated"])
        #expect(queue.holeFinish != nil)
        queue.acknowledge([finish.id])
        try queue.mark(mark("new"))
        #expect(queue.pending?.id == "new")
    }

    @Test("Acknowledgements retain the number of recorded shots for scoring")
    func scoringCounts() throws {
        var queue = WatchShotQueue()
        try queue.mark(mark("first"))
        try queue.mark(mark("second"))
        queue.finish(at: WatchPoint(latitude: 40.002, longitude: -73), accuracy: 5)
        queue.acknowledge(["first", "second"])
        #expect(queue.completedCount(sessionId: "round", hole: 1) == 2)
        #expect(queue.completedCount(sessionId: "other", hole: 1) == 0)
        #expect(queue.completedCount(sessionId: "round", hole: 2) == 0)
    }

    @Test("Scores must include their putts and penalties")
    func scoreValidation() {
        var finish = WatchHoleFinish(sessionId: "round", courseId: "course", hole: 1,
                                     score: 3, putts: 2, penalties: 2)
        #expect(!finish.isValid)
        finish.score = 5
        #expect(finish.isValid)
    }

    @MainActor
    @Test("Finishing from Watch saves the score and retries never skip a hole")
    func finishIntegration() throws {
        let schema = Schema([CourseShotModel.self, PolygonModel.self, HoleInfoModel.self, RoundModel.self, ShotModel.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let suite = "watch-test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let bridge = WatchRoundBridge(defaults: defaults)
        bridge.start(context: container.mainContext, connect: false)
        let courseId = UUID().uuidString
        let tracker = bridge.tracker(for: courseId)
        tracker.startRound(courseId: courseId, holeCount: 2)
        tracker.save()
        defer { tracker.clearSave() }
        let finish = WatchHoleFinish(sessionId: tracker.sessionId, courseId: courseId,
                                     hole: 1, score: 5, putts: 2, penalties: 1)
        try bridge.receive(finish)
        try bridge.receive(finish)
        #expect(tracker.currentHole == 2)
        #expect(tracker.scores[1]?.score == 5)
        #expect(tracker.scores[1]?.putts == 2)
        #expect(tracker.scores[1]?.penaltyStrokes == 1)
        let restarted = WatchRoundBridge(defaults: defaults)
        restarted.start(context: container.mainContext, connect: false)
        try restarted.receive(finish)
        #expect(restarted.tracker(for: courseId).currentHole == 2)
        let last = WatchHoleFinish(sessionId: tracker.sessionId, courseId: courseId,
                                   hole: 2, score: 4, putts: 1, penalties: 0)
        try bridge.receive(last)
        try bridge.receive(last)
        let summary = try #require(try CoursesRepo(context: container.mainContext).round(id: tracker.sessionId))
        #expect(summary.totalScore == 9)
        #expect(summary.totalPutts == 3)
        #expect(tracker.state == .roundComplete)
        #expect(!tracker.hasSavedRound)
    }

    private func mark(_ id: String, hole: Int = 1, club: String = "7i") -> WatchMark {
        WatchMark(id: id, sessionId: "round", courseId: "course", hole: hole,
                  clubId: club, point: WatchPoint(latitude: 40, longitude: -73), accuracy: 5)
    }

    @Test("Next mark finishes the previous club's shot")
    func chainedMarks() throws {
        var queue = WatchShotQueue()
        try queue.mark(mark("first", club: "driver"))
        #expect(queue.shots.isEmpty)
        var next = mark("second", club: "7i")
        next.point.latitude = 40.001
        try queue.mark(next)
        #expect(queue.shots.count == 1)
        #expect(queue.shots[0].start.clubId == "driver")
        #expect(queue.shots[0].end == next.point)
        #expect(queue.pending == next)
    }

    @Test("Markers cannot silently connect different holes")
    func differentHole() throws {
        var queue = WatchShotQueue()
        try queue.mark(mark("first"))
        #expect(throws: WatchShotQueue.QueueError.self) {
            try queue.mark(mark("second", hole: 2))
        }
        #expect(queue.shots.isEmpty)
        #expect(queue.pending?.id == "first")
    }

    @Test("Reached green completes the approach once and survives restart")
    func greenAndRecovery() throws {
        var queue = WatchShotQueue()
        try queue.mark(mark("first"))
        queue.finish(at: WatchPoint(latitude: 40.001, longitude: -73), accuracy: 7)
        queue.finish(at: WatchPoint(latitude: 40.002, longitude: -73), accuracy: 7)
        let restored = try JSONDecoder().decode(WatchShotQueue.self, from: JSONEncoder().encode(queue))
        #expect(restored.shots.count == 1)
        #expect(restored.pending == nil)
        #expect(restored.shots[0].isValid)
    }

    @Test("Acknowledgements only remove confirmed shots")
    func acknowledgements() throws {
        var queue = WatchShotQueue()
        try queue.mark(mark("first"))
        try queue.mark(mark("second"))
        queue.finish(at: WatchPoint(latitude: 40.001, longitude: -73), accuracy: 5)
        queue.acknowledge(["first"])
        queue.acknowledge(["first", "unknown"])
        #expect(queue.shots.map(\.id) == ["second"])
    }

    @Test("Invalid coordinates and poor GPS are rejected")
    func invalidFix() {
        var shot = WatchShot(start: mark("first"), end: WatchPoint(latitude: 40, longitude: -73), endAccuracy: 5)
        shot.end.latitude = .nan
        #expect(!shot.isValid)
        shot.end.latitude = 40
        shot.endAccuracy = 50
        #expect(!shot.isValid)
    }

    @MainActor
    @Test("Duplicate watch imports preserve scores and do not change current hole")
    func duplicateRoundImport() {
        let tracker = RoundTracker()
        tracker.startRound(courseId: "course", holeCount: 9)
        tracker.currentHole = 2
        tracker.setScore(hole: 1, score: 5)
        let shot = CourseShot(id: "watch-shot", courseId: "course", holeNumber: 1,
                              shotNumber: 1, clubId: "7i", startLat: 40, startLng: -73,
                              endLat: 40.001, endLng: -73, accuracy: 5)
        tracker.acceptWatchShot(shot)
        tracker.acceptWatchShot(shot)
        #expect(tracker.shots.count == 1)
        #expect(tracker.currentHole == 2)
        #expect(tracker.scores[1]?.score == 5)
    }
}
