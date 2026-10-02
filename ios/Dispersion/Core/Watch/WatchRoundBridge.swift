import Foundation
import SwiftData
import WatchConnectivity

@MainActor
final class WatchRoundBridge: NSObject, WCSessionDelegate {
    static let shared = WatchRoundBridge()
    private var context: ModelContext?
    private var trackers: [String: RoundTracker] = [:]
    private var round: WatchRound?
    private var receipts: Set<String> = []
    private var recentReceipts: [String] = []
    private let defaults: UserDefaults
    private var connectivityEnabled = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        super.init()
    }

    func start(context: ModelContext, connect: Bool = true) {
        guard self.context == nil else { return }
        self.context = context
        receipts = Set(defaults.stringArray(forKey: "watch.receipts") ?? [])
        recentReceipts = defaults.stringArray(forKey: "watch.recentReceipts") ?? []
        if let data = defaults.data(forKey: "watch.round") {
            round = try? JSONDecoder().decode(WatchRound.self, from: data)
        }
        connectivityEnabled = connect
        guard connect, WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func tracker(for courseId: String) -> RoundTracker {
        if let tracker = trackers[courseId], tracker.state != .roundComplete, tracker.state != .idle {
            return tracker
        }
        let tracker = RoundTracker()
        _ = tracker.loadIfExists(courseId: courseId)
        trackers[courseId] = tracker
        return tracker
    }

    func publish(_ round: WatchRound) {
        self.round = round
        defaults.set(try? JSONEncoder().encode(round), forKey: "watch.round")
        sendContext()
    }

    func end(sessionId: String) {
        guard round?.sessionId == sessionId else { return }
        round = nil
        defaults.removeObject(forKey: "watch.round")
        sendContext()
    }

    private func contextPayload() -> [String: Any] {
        let revision = defaults.integer(forKey: "watch.contextRevision") + 1
        defaults.set(revision, forKey: "watch.contextRevision")
        var payload: [String: Any] = ["active": round != nil, "receipts": recentReceipts, "revision": revision]
        if let round, let data = try? JSONEncoder().encode(round) { payload["round"] = data }
        return payload
    }

    private func sendContext() {
        guard connectivityEnabled, WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        try? WCSession.default.updateApplicationContext(contextPayload())
    }

    // Retries use the original mark ID, including after the user undoes a shot.
    func receive(_ shot: WatchShot) throws {
        guard shot.isValid else { throw ImportError.invalidShot }
        if receipts.contains(shot.id) {
            rememberReceipt(shot.id)
            sendContext()
            return
        }
        guard let context else { throw ImportError.unavailable }
        let tracker = tracker(for: shot.start.courseId)
        guard tracker.sessionId == shot.start.sessionId,
              tracker.state != .idle, tracker.state != .roundComplete,
              tracker.hasSavedRound,
              (tracker.startHole...tracker.lastHole).contains(shot.start.hole) else {
            throw ImportError.roundEnded
        }
        let repo = CoursesRepo(context: context)
        let existing = try repo.shots(courseId: shot.start.courseId, hole: shot.start.hole)
            .first { $0.id == shot.id }
        var saved = existing ?? CourseShot(
            id: shot.id, courseId: shot.start.courseId, holeNumber: shot.start.hole,
            shotNumber: tracker.shotsForHole(shot.start.hole).count + 1,
            clubId: shot.start.clubId,
            startLat: shot.start.point.latitude, startLng: shot.start.point.longitude,
            endLat: shot.end.latitude, endLng: shot.end.longitude,
            accuracy: max(shot.start.accuracy, shot.endAccuracy), timestamp: shot.start.timestamp
        )
        saved.sessionId = shot.start.sessionId
        saved.excludedFromDistances = shot.excludedFromDistances
        if existing == nil { try repo.createShot(saved) }
        tracker.acceptWatchShot(saved)
        tracker.save()
        receipts.insert(shot.id)
        defaults.set(Array(receipts), forKey: "watch.receipts")
        rememberReceipt(shot.id)
        sendContext()
    }

    func receive(_ edit: WatchEdit) throws {
        guard edit.isValid else { throw ImportError.invalidShot }
        if receipts.contains(edit.id) { rememberReceipt(edit.id); return }
        guard let context else { throw ImportError.unavailable }
        let tracker = tracker(for: edit.courseId)
        guard tracker.sessionId == edit.sessionId, tracker.hasSavedRound,
              tracker.state != .roundComplete else { throw ImportError.roundEnded }
        let repo = CoursesRepo(context: context)
        switch edit.kind {
        case .penalty:
            var event = CourseShot(id: edit.id, courseId: edit.courseId, holeNumber: edit.hole,
                                   shotNumber: tracker.shotsForHole(edit.hole).count + 1,
                                   startLat: 0, startLng: 0, endLat: 0, endLng: 0)
            event.sessionId = edit.sessionId
            event.kind = "penalty"
            event.penaltyStrokes = edit.strokes
            event.excludedFromDistances = true
            if !(try repo.shots(sessionId: edit.sessionId)).contains(where: { $0.id == edit.id }) {
                try repo.createShot(event)
            }
            tracker.acceptWatchShot(event)
        case .deleteShot:
            guard let id = edit.shotId else { throw ImportError.invalidShot }
            let saved = try repo.shots(sessionId: edit.sessionId).first { $0.id == id && $0.holeNumber == edit.hole }
            if saved != nil { try repo.deleteShot(id: id) }
            tracker.removeCourseShot(id: id)
        case .changeClub:
            guard let id = edit.shotId,
                  var shot = try repo.shots(sessionId: edit.sessionId).first(where: { $0.id == id && $0.holeNumber == edit.hole }) else {
                throw ImportError.invalidShot
            }
            shot.clubId = edit.clubId
            try repo.updateShot(shot)
            tracker.replaceCourseShot(shot)
        }
        tracker.save()
        receipts.insert(edit.id)
        defaults.set(Array(receipts), forKey: "watch.receipts")
        rememberReceipt(edit.id)
        if var updated = round, updated.sessionId == edit.sessionId {
            updated.score = tracker.scores[updated.hole]?.score
            updated.penalties = tracker.scores[updated.hole]?.penaltyStrokes
            publish(updated)
        }
    }

    private func rememberReceipt(_ id: String) {
        recentReceipts.removeAll { $0 == id }
        recentReceipts.append(id)
        recentReceipts = Array(recentReceipts.suffix(50))
        defaults.set(recentReceipts, forKey: "watch.recentReceipts")
    }

    func receive(_ finish: WatchHoleFinish) throws {
        guard finish.isValid else { throw ImportError.invalidShot }
        guard let context else { throw ImportError.unavailable }
        if receipts.contains(finish.id) { rememberReceipt(finish.id); return }
        let tracker = tracker(for: finish.courseId)
        let repo = CoursesRepo(context: context)
        let savedRound = try repo.round(id: finish.sessionId)
        if tracker.watchFinishedCommands.contains(finish.id) || savedRound != nil {
            if savedRound != nil {
                tracker.state = .roundComplete
                tracker.clearSave()
                end(sessionId: finish.sessionId)
            }
            rememberReceipt(finish.id)
            return
        }
        guard tracker.sessionId == finish.sessionId, tracker.currentHole == finish.hole,
              tracker.state != .idle, tracker.state != .roundComplete,
              tracker.hasSavedRound else {
            throw ImportError.roundEnded
        }
        let nextInfo = finish.hole < tracker.lastHole
            ? try repo.holeInfo(courseId: tracker.courseId, hole: finish.hole + 1) : nil
        let nextGreen = finish.hole < tracker.lastHole
            ? try repo.polygons(courseId: tracker.courseId, hole: finish.hole + 1).first { $0.surface == .green }?.coordinates : nil
        guard var score = tracker.scores[finish.hole] else { throw ImportError.invalidShot }
        score.score = finish.score
        score.putts = finish.putts
        score.penaltyStrokes = finish.penalties
        tracker.scores[finish.hole] = score
        if finish.hole == tracker.lastHole {
            let sg = StrokesGained.aggregate(try ShotsRepo(context: context).listBySession(tracker.sessionId))
            let summary = RoundSummary(
                id: tracker.sessionId, courseId: tracker.courseId,
                courseName: round?.courseName ?? "Round", startedAt: tracker.startedAt,
                completedAt: .now, holeCount: tracker.holeCount, startHole: tracker.startHole,
                totalScore: tracker.totalScore, totalPar: tracker.totalPar,
                holesPlayed: tracker.holesPlayed, totalPutts: tracker.totalPutts,
                fairwaysHit: tracker.fairwaysHit, fairwaysTotal: tracker.fairwaysTotal,
                greensHit: tracker.greensHit, greensTotal: tracker.holesPlayed,
                upAndDowns: tracker.upAndDowns, upAndDownAttempts: tracker.upAndDownAttempts,
                sgTotal: sg.totalSG, sgAvg: sg.avgSG, sgShotCount: sg.shotCount,
                scores: tracker.scores.values.sorted { $0.hole < $1.hole }
            )
            try repo.createRound(summary)
            tracker.state = .roundComplete
            tracker.clearSave()
            if SessionStore.shared.active?.id == tracker.sessionId { SessionStore.shared.clear() }
            end(sessionId: tracker.sessionId)
        } else {
            tracker.nextHole()
            tracker.watchFinishedCommands.append(finish.id)
            tracker.save()
            if var updated = round, updated.sessionId == tracker.sessionId {
                updated.hole = tracker.currentHole
                updated.par = tracker.scores[tracker.currentHole]?.par ?? 4
                updated.target = (nextInfo?.defaultPinCoord ?? nextGreen.map { centroid($0) }).map { WatchPoint(latitude: $0.lat, longitude: $0.lng) }
                updated.green = nextGreen?.map { WatchPoint(latitude: $0.lat, longitude: $0.lng) }
                updated.score = tracker.scores[tracker.currentHole]?.score
                updated.putts = tracker.scores[tracker.currentHole]?.putts
                updated.penalties = tracker.scores[tracker.currentHole]?.penaltyStrokes
                publish(updated)
            }
        }
        receipts.insert(finish.id)
        defaults.set(Array(receipts), forKey: "watch.receipts")
        rememberReceipt(finish.id)
    }

    private func handle(_ payload: [String: Any]) -> [String: Any] {
        if let data = payload["edit"] as? Data,
           let edit = try? JSONDecoder().decode(WatchEdit.self, from: data) {
            do {
                try receive(edit)
                sendContext()
                return ["receipt": edit.id, "context": contextPayload()]
            } catch { return ["error": error.localizedDescription] }
        }
        if let data = payload["finish"] as? Data,
           let finish = try? JSONDecoder().decode(WatchHoleFinish.self, from: data) {
            do {
                try receive(finish)
                sendContext()
                return ["receipt": finish.id, "context": contextPayload()]
            } catch { return ["error": error.localizedDescription] }
        }
        guard let data = payload["shot"] as? Data,
              let shot = try? JSONDecoder().decode(WatchShot.self, from: data) else {
            sendContext()
            return ["context": contextPayload()]
        }
        do {
            try receive(shot)
            return ["receipt": shot.id]
        } catch {
            return ["error": error.localizedDescription]
        }
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in self.sendContext() }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in replyHandler(self.handle(message)) }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        Task { @MainActor in _ = self.handle(userInfo) }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    enum ImportError: LocalizedError {
        case invalidShot, unavailable, roundEnded
        var errorDescription: String? {
            switch self {
            case .invalidShot: return "This shot has invalid location data."
            case .unavailable: return "Open Dispersion on your iPhone to sync."
            case .roundEnded: return "This round is no longer active. Your shot is still saved on the watch."
            }
        }
    }
}
