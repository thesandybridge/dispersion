import Foundation
import SwiftData
import Testing
@testable import Dispersion

struct CourseTrackingTests {
    private func mark(_ id: String) -> WatchMark {
        WatchMark(id: id, sessionId: "round", courseId: "course", hole: 1, clubId: "7i",
                  point: WatchPoint(latitude: 40, longitude: -73), accuracy: 5)
    }

    @Test("Backups preserve round-linked shots and penalty metadata")
    func trackingBackup() throws {
        let course = Course(id: "c", name: "Test", centerLat: 40, centerLng: -73, holeCount: 9)
        var shot = CourseShot(id: "p", courseId: "c", holeNumber: 1, shotNumber: 1,
                              startLat: 40, startLng: -73, endLat: 40, endLng: -73)
        shot.sessionId = "r"
        shot.kind = "penalty"
        shot.penaltyStrokes = 2
        shot.excludedFromDistances = true
        let data = Backup.build(clubs: [], sessions: [], shots: [], courses: [course], courseShots: [shot])
        let parsed = try Backup.parse(data)
        let restored = try #require(parsed.courseShots.first)
        #expect(restored.sessionId == "r")
        #expect(restored.strokeCount == 2)
        #expect(!restored.usableDistance)
    }

    @MainActor
    @Test("Drop position survives a round restart")
    func dropPositionPersistence() {
        let tracker = RoundTracker()
        let id = UUID().uuidString
        tracker.startRound(courseId: id, holeCount: 9)
        defer { tracker.clearSave() }
        tracker.lastPosition = Coord(lat: 40.001, lng: -73.001)
        tracker.save()
        let restored = RoundTracker()
        #expect(restored.loadIfExists(courseId: id))
        #expect(restored.lastPosition?.lat == 40.001)
        #expect(restored.lastPosition?.lng == -73.001)
    }

    @Test("Lost-ball penalty ends an unmeasured shot and never measures the walk to a drop")
    func penaltyQueue() throws {
        var queue = WatchShotQueue()
        try queue.mark(mark("lost"))
        let round = WatchRound(sessionId: "round", courseId: "course", courseName: "Test", hole: 1, par: 4, clubs: [], usesMeters: false)
        queue.addPenalty(for: round, strokes: 1, endPending: true)
        #expect(queue.pending == nil)
        #expect(queue.shots.count == 1)
        #expect(queue.shots[0].excludedFromDistances == true)
        #expect(queue.shots[0].start.point == queue.shots[0].end)
        #expect(queue.completedCount(sessionId: "round", hole: 1) == 1)
        #expect(queue.penaltyTotals?["round:1"] == 1)
        #expect(queue.edits?.first?.strokes == 1)
        let restored = try JSONDecoder().decode(WatchShotQueue.self, from: JSONEncoder().encode(queue))
        #expect(restored.edits?.first?.kind == .penalty)
        queue.acknowledge(["lost", try #require(queue.edits?.first?.id)])
        #expect(queue.shots.isEmpty)
        #expect(queue.edits?.isEmpty == true)
        #expect(queue.history?.count == 1)
        #expect(queue.penaltyTotals?["round:1"] == 1)
    }

    @Test("Corrections survive shot acknowledgement without changing the next pending mark")
    func corrections() throws {
        var queue = WatchShotQueue()
        try queue.mark(mark("first"))
        try queue.mark(mark("next"))
        queue.acknowledge(["first"])
        queue.addEdit(WatchEdit(sessionId: "round", courseId: "course", hole: 1, kind: .changeClub, shotId: "first", clubId: "8i"))
        #expect(queue.history?.last?.start.clubId == "8i")
        queue.addEdit(WatchEdit(sessionId: "round", courseId: "course", hole: 1, kind: .deleteShot, shotId: "first"))
        #expect(queue.history?.isEmpty == true)
        #expect(queue.pending?.id == "next")
        #expect(queue.completedCount(sessionId: "round", hole: 1) == 0)
        #expect(queue.edits?.count == 2)
    }

    @Test("Distance statistics exclude penalties, partial shots and poor GPS")
    func distanceStats() throws {
        func shot(_ yards: Double) -> CourseShot {
            CourseShot(id: UUID().uuidString, courseId: "c", holeNumber: 1, shotNumber: 1,
                       startLat: 0, startLng: 0, endLat: yards / 121610, endLng: 0, accuracy: 5)
        }
        var chip = shot(30); chip.kind = "chip"
        var penalty = shot(200); penalty.kind = "penalty"
        var excluded = shot(250); excluded.excludedFromDistances = true
        var badGPS = shot(300); badGPS.accuracy = 45
        let stats = try #require(CourseDistanceStats.calculate([shot(100), shot(120), shot(140), chip, penalty, excluded, badGPS]))
        #expect(stats.count == 3)
        #expect(abs(stats.median - 120) < 1)
        #expect(abs(stats.low - 108) < 1)
        #expect(abs(stats.high - 132) < 1)
        #expect(CourseDistanceStats.calculate([chip, penalty, excluded, badGPS]) == nil)
    }

    @Test("Old watch queues decode without the newly added state")
    func legacyQueue() throws {
        let data = Data("{\"shots\":[]}".utf8)
        let queue = try JSONDecoder().decode(WatchShotQueue.self, from: data)
        #expect(queue.history == nil)
        #expect(queue.edits == nil)
        #expect(queue.penaltyTotals == nil)
    }

    @Test("Mapped green distances are ordered and invalid geometry is rejected")
    func greenDistances() throws {
        let origin = WatchPoint(latitude: 40, longitude: -73)
        let polygon = [WatchPoint(latitude: 40.001, longitude: -73.0001),
                       WatchPoint(latitude: 40.001, longitude: -72.9999),
                       WatchPoint(latitude: 40.0013, longitude: -73)]
        let distances = try #require(GreenYardages.measure(from: origin, polygon: polygon))
        #expect(distances.front < distances.middle)
        #expect(distances.middle < distances.back)
        #expect(GreenYardages.measure(from: origin, polygon: []) == nil)
    }

    @MainActor
    @Test("Penalties stay in the total when logging shots or changing putts")
    func scoreAccounting() {
        let tracker = RoundTracker()
        tracker.startRound(courseId: UUID().uuidString, holeCount: 9)
        defer { tracker.clearSave() }
        tracker.logShot(from: Coord(lat: 40, lng: -73), to: Coord(lat: 40.001, lng: -73), clubId: "7i", accuracy: 5)
        tracker.setPenalties(hole: 1, count: 2)
        #expect(tracker.scores[1]?.score == 3)
        tracker.logShot(from: Coord(lat: 40.001, lng: -73), to: Coord(lat: 40.002, lng: -73), clubId: "8i", accuracy: 5)
        #expect(tracker.scores[1]?.score == 4)
        tracker.setPutts(hole: 1, count: 2)
        #expect(tracker.scores[1]?.score == 6)
        tracker.setPenalties(hole: 1, count: 1)
        #expect(tracker.scores[1]?.score == 5)
        _ = tracker.undoLastShot()
        #expect(tracker.scores[1]?.score == 4)
        #expect(tracker.scores[1]?.penaltyStrokes == 1)
    }

    @MainActor
    @Test("Watch edits and penalties are idempotent; deleted shots cannot return on retry")
    func editIntegration() throws {
        let schema = Schema([CourseShotModel.self, PolygonModel.self, HoleInfoModel.self, RoundModel.self, ShotModel.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let suite = "course-test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let bridge = WatchRoundBridge(defaults: defaults)
        bridge.start(context: container.mainContext, connect: false)
        let courseId = UUID().uuidString
        let tracker = bridge.tracker(for: courseId)
        tracker.startRound(courseId: courseId, holeCount: 9)
        tracker.save()
        defer { tracker.clearSave() }
        var start = mark("first"); start.courseId = courseId; start.sessionId = tracker.sessionId
        let shot = WatchShot(start: start, end: WatchPoint(latitude: 40.001, longitude: -73), endAccuracy: 5)
        try bridge.receive(shot)
        let repo = CoursesRepo(context: container.mainContext)
        #expect(try repo.shots(sessionId: tracker.sessionId).count == 1)
        let penalty = WatchEdit(sessionId: tracker.sessionId, courseId: courseId, hole: 1, kind: .penalty, strokes: 2)
        try bridge.receive(penalty)
        try bridge.receive(penalty)
        #expect(tracker.scores[1]?.score == 3)
        #expect(tracker.scores[1]?.penaltyStrokes == 2)
        let change = WatchEdit(sessionId: tracker.sessionId, courseId: courseId, hole: 1, kind: .changeClub, shotId: shot.id, clubId: "8i")
        try bridge.receive(change)
        #expect(try repo.shots(sessionId: tracker.sessionId).first { $0.id == shot.id }?.clubId == "8i")
        let deletion = WatchEdit(sessionId: tracker.sessionId, courseId: courseId, hole: 1, kind: .deleteShot, shotId: shot.id)
        try bridge.receive(deletion)
        try bridge.receive(deletion)
        try bridge.receive(shot)
        #expect(try repo.shots(sessionId: tracker.sessionId).count == 1)
        #expect(tracker.scores[1]?.score == 2)
        #expect(tracker.scores[1]?.penaltyStrokes == 2)
        #expect(tracker.lastPosition == nil)
    }
}
