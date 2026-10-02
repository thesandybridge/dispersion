import CoreMotion
import CoreLocation
import SwiftUI
import WatchConnectivity
import WatchKit

@MainActor
final class WatchGolfStore: NSObject, ObservableObject, WCSessionDelegate, CLLocationManagerDelegate {
    @Published private(set) var round: WatchRound?
    @Published private(set) var queue = WatchShotQueue()
    @Published private(set) var location: CLLocation?
    @Published var message: String?
    @Published var selectedClubId = ""
    @Published private(set) var acquiringGPS = false
    @Published var swingPrompt = false
    private let motion = CMMotionManager()
    private var lastSwingPrompt = Date.distantPast
    private var remindedMarkId: String?
    private var captureAction: (() -> Void)?
    private var captureTimeout: Task<Void, Never>?
    private var active = false
    private var sendingId: String?
    private var queueReadable = true
    private var lastMarkTime = Date.distantPast
    private let manager = CLLocationManager()
    private let session = WCSession.default
    private let queueURL = URL.documentsDirectory.appending(path: "shot-queue.json")

    override init() {
        super.init()
        if let data = try? Data(contentsOf: queueURL) {
            do { queue = try JSONDecoder().decode(WatchShotQueue.self, from: data) }
            catch {
                queueReadable = false
                message = "Could not read saved shots. Restart the app before marking more."
            }
        }
        if let data = UserDefaults.standard.data(forKey: "watch.round") {
            round = try? JSONDecoder().decode(WatchRound.self, from: data)
        }
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
        session.delegate = self
        session.activate()
    }

    var freshLocation: CLLocation? {
        guard let location, abs(location.timestamp.timeIntervalSinceNow) <= 3,
              (0...15).contains(location.horizontalAccuracy) else { return nil }
        return location
    }

    var targetYards: Double? {
        guard let location, abs(location.timestamp.timeIntervalSinceNow) <= 30,
              (0...20).contains(location.horizontalAccuracy), let target = round?.target else { return nil }
        return location.distance(from: CLLocation(latitude: target.latitude, longitude: target.longitude)) / 0.9144
    }

    var lastShot: WatchShot? {
        queue.history?.last { $0.start.sessionId == round?.sessionId && $0.start.hole == round?.hole }
    }

    var greenYardages: GreenYardages? {
        guard targetYards != nil, let location, let green = round?.green else { return nil }
        return GreenYardages.measure(from: WatchPoint(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude), polygon: green)
    }

    var penaltyCount: Int {
        guard let round else { return 0 }
        return max(round.penalties ?? 0, queue.penaltyTotals?["\(round.sessionId):\(round.hole)"] ?? 0)
    }

    func addPenalty(strokes: Int, endPending: Bool) {
        guard (1...2).contains(strokes), penaltyCount + strokes <= 15 else { return }
        guard let round, pendingMatchesHole, queue.holeFinish == nil, !acquiringGPS else { return }
        var updated = queue
        updated.addPenalty(for: round, strokes: strokes, endPending: endPending)
        if persist(updated) {
            WKInterfaceDevice.current().play(.success)
            message = "\(strokes) penalty stroke\(strokes == 1 ? "" : "s") added"
            sync()
        }
    }

    func correctLastShot(club: WatchClub? = nil, delete: Bool = false) {
        guard let round, let lastShot, queue.holeFinish == nil else { return }
        var updated = queue
        updated.addEdit(WatchEdit(sessionId: round.sessionId, courseId: round.courseId, hole: round.hole,
                                 kind: delete ? .deleteShot : .changeClub, shotId: lastShot.id, clubId: club?.id))
        if persist(updated) { message = delete ? "Last completed shot removed" : "Club corrected"; sync() }
    }

    var recommendedClub: WatchClub? {
        guard let yardage = targetYards else { return nil }
        return round?.clubs.min { abs($0.carryYards - yardage) < abs($1.carryYards - yardage) }
    }

    var selectedClub: WatchClub? {
        round?.clubs.first { $0.id == selectedClubId } ?? recommendedClub ?? round?.clubs.first
    }

    var pendingMatchesHole: Bool {
        guard let pending = queue.pending else { return true }
        return pending.sessionId == round?.sessionId && pending.hole == round?.hole
    }

    func setActive(_ active: Bool) {
        self.active = active
        refreshMotion()
        if active {
            manager.requestWhenInUseAuthorization()
            manager.startUpdatingLocation()
            sync()
        } else {
            cancelCapture()
            manager.stopUpdatingLocation()
        }
    }

    func refreshMotion() {
        motion.stopDeviceMotionUpdates()
        guard active, round != nil, UserDefaults.standard.bool(forKey: "watch.swingPrompts"), motion.isDeviceMotionAvailable else { return }
        motion.deviceMotionUpdateInterval = 0.04
        motion.startDeviceMotionUpdates(to: .main) { [weak self] sample, _ in
            guard let sample else { return }
            let rotation = sample.rotationRate
            let acceleration = sample.userAcceleration
            let speed = sqrt(rotation.x * rotation.x + rotation.y * rotation.y + rotation.z * rotation.z)
            let impact = sqrt(acceleration.x * acceleration.x + acceleration.y * acceleration.y + acceleration.z * acceleration.z)
            Task { @MainActor [weak self] in
                guard let self, speed > 7, impact > 1.8, Date.now.timeIntervalSince(self.lastSwingPrompt) > 45,
                      Date.now.timeIntervalSince(self.lastMarkTime) > 20, self.queue.holeFinish == nil else { return }
                self.lastSwingPrompt = .now
                self.swingPrompt = true
                WKInterfaceDevice.current().play(.click)
            }
        }
    }

    private func checkReminder() {
        guard active, UserDefaults.standard.bool(forKey: "watch.reminders"),
              let mark = queue.pending, pendingMatchesHole, let location = freshLocation,
              remindedMarkId != mark.id, Date.now.timeIntervalSince(mark.timestamp) > 120 else { return }
        let here = WatchPoint(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        guard here.yards(to: mark.point) > 35 else { return }
        remindedMarkId = mark.id
        message = "At your ball? Mark your next shot, or choose Reached green."
        WKInterfaceDevice.current().play(.notification)
    }

    func markShot() {
        guard let club = selectedClub, queue.holeFinish == nil, pendingMatchesHole else { return }
        selectedClubId = club.id
        requestFix { self.recordShot() }
    }

    func reachedGreen() {
        guard queue.pending != nil, pendingMatchesHole else { return }
        requestFix { self.finishApproach() }
    }

    private func requestFix(_ action: @escaping () -> Void) {
        guard queueReadable, !acquiringGPS else { return }
        if freshLocation != nil { action(); return }
        guard manager.authorizationStatus != .denied, manager.authorizationStatus != .restricted else {
            message = "Allow location access in Watch Settings to mark shots."
            return
        }
        acquiringGPS = true
        message = "Finding your position… Stay at your ball."
        captureAction = action
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        captureTimeout = Task { @MainActor in
            do { try await Task.sleep(for: .seconds(15)) } catch { return }
            self.cancelCapture()
            self.message = "GPS is not accurate enough yet. No shot saved. Try again at your ball."
            WKInterfaceDevice.current().play(.failure)
        }
    }

    func cancelCapture() {
        captureTimeout?.cancel()
        captureTimeout = nil
        captureAction = nil
        acquiringGPS = false
    }

    private func recordShot() {
        guard queueReadable, Date.now.timeIntervalSince(lastMarkTime) > 3 else { return }
        guard let round, let club = selectedClub, let location = freshLocation else {
            message = "Wait for an accurate GPS fix at your ball."
            return
        }
        var updated = queue
        do {
            try updated.mark(WatchMark(
                sessionId: round.sessionId, courseId: round.courseId, hole: round.hole,
                clubId: club.id,
                point: WatchPoint(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude),
                accuracy: location.horizontalAccuracy
            ))
            guard persist(updated) else { return }
            lastMarkTime = .now
            WKInterfaceDevice.current().play(.success)
            message = "\(club.name) marked"
            swingPrompt = false
            selectedClubId = ""
            sync()
        } catch {
            message = "Finish or cancel the previous hole’s mark first."
        }
    }

    private func finishApproach() {
        guard let location = freshLocation, queue.pending != nil, pendingMatchesHole else { return }
        var updated = queue
        updated.finish(
            at: WatchPoint(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude),
            accuracy: location.horizontalAccuracy
        )
        guard persist(updated) else { return }
        WKInterfaceDevice.current().play(.success)
        message = "Approach saved. Finish the hole after putting."
        sync()
    }

    func cancelMark() {
        var updated = queue
        updated.pending = nil
        if persist(updated) { message = "Unfinished mark cancelled. Completed shots kept." }
    }

    var suggestedScore: Int {
        guard let round else { return 4 }
        let shots = max(round.score ?? 0, queue.completedCount(sessionId: round.sessionId, hole: round.hole) + penaltyCount + (round.putts ?? 0))
        return min(30, max(1, shots + (round.putts == nil ? 2 : 0)))
    }

    func finishHole(for expected: WatchRound, score: Int, putts: Int, penalties: Int) {
        guard queueReadable, let round, queue.pending == nil, queue.holeFinish == nil else { return }
        guard round.sessionId == expected.sessionId, round.hole == expected.hole else {
            message = "The hole changed. Review the score again."
            return
        }
        let finish = WatchHoleFinish(sessionId: round.sessionId, courseId: round.courseId,
                                     hole: round.hole, score: score, putts: putts, penalties: penalties)
        guard finish.isValid else { message = "Total strokes must include putts and penalties."; return }
        var updated = queue
        updated.holeFinish = finish
        guard persist(updated) else { return }
        message = "Hole saved on Watch. Syncing with iPhone…"
        WKInterfaceDevice.current().play(.success)
        sync()
    }

    func changeMarkedClub(to club: WatchClub) {
        guard queue.pending != nil else { return }
        var updated = queue
        updated.pending?.clubId = club.id
        if persist(updated) { message = "Marked club changed to \(club.name)." }
    }

    private func persist(_ updated: WatchShotQueue) -> Bool {
        guard queueReadable else { return false }
        do {
            try JSONEncoder().encode(updated).write(to: queueURL, options: .atomic)
            queue = updated
            return true
        } catch {
            message = "Could not save the shot. Try again."
            WKInterfaceDevice.current().play(.failure)
            return false
        }
    }

    func sync() {
        guard session.activationState == .activated else { return }
        if session.isReachable {
            session.sendMessage(["refresh": true], replyHandler: { reply in
                Task { @MainActor in
                    if let context = reply["context"] as? [String: Any] { self.receive(context) }
                }
            }, errorHandler: nil)
        }
        let payload: [String: Any]
        let id: String
        if let shot = queue.shots.first, let data = try? JSONEncoder().encode(shot) {
            id = shot.id
            payload = ["shot": data, "id": id]
        } else if let edit = queue.edits?.first, let data = try? JSONEncoder().encode(edit) {
            id = edit.id
            payload = ["edit": data, "id": id]
        } else if let finish = queue.holeFinish, let data = try? JSONEncoder().encode(finish) {
            id = finish.id
            payload = ["finish": data, "id": id]
        } else { return }
        if !session.outstandingUserInfoTransfers.contains(where: { ($0.userInfo["id"] as? String) == id }) {
            session.transferUserInfo(payload)
        }
        guard session.isReachable, sendingId == nil else { return }
        sendingId = id
        session.sendMessage(payload, replyHandler: { reply in
            Task { @MainActor in
                self.sendingId = nil
                if let context = reply["context"] as? [String: Any] { self.receive(context) }
                if let id = reply["receipt"] as? String { self.acknowledge([id]) }
                if let error = reply["error"] as? String { self.message = error }
            }
        }, errorHandler: { _ in
            Task { @MainActor in self.sendingId = nil }
        })
    }

    private func acknowledge(_ ids: Set<String>) {
        let hadAcknowledgement = queue.shots.contains { ids.contains($0.id) }
            || queue.edits?.contains { ids.contains($0.id) } == true
            || queue.holeFinish.map { ids.contains($0.id) } == true
        guard hadAcknowledgement else { return }
        var updated = queue
        updated.acknowledge(ids)
        guard persist(updated) else { return }
        for transfer in session.outstandingUserInfoTransfers {
            if let id = transfer.userInfo["id"] as? String, ids.contains(id) { transfer.cancel() }
        }
        sync()
    }

    private func receive(_ context: [String: Any]) {
        if let revision = context["revision"] as? Int {
            guard revision >= UserDefaults.standard.integer(forKey: "watch.contextRevision") else { return }
            UserDefaults.standard.set(revision, forKey: "watch.contextRevision")
        }
        if let data = context["round"] as? Data,
           let round = try? JSONDecoder().decode(WatchRound.self, from: data) {
            if self.round?.hole != round.hole || self.round?.sessionId != round.sessionId {
                cancelCapture()
                selectedClubId = ""
                message = nil
            }
            self.round = round
            refreshMotion()
            UserDefaults.standard.set(data, forKey: "watch.round")
        } else if context["active"] as? Bool == false {
            cancelCapture()
            round = nil
            refreshMotion()
            UserDefaults.standard.removeObject(forKey: "watch.round")
        }
        if let ids = context["receipts"] as? [String] { acknowledge(Set(ids)) }
        if let round, context["round"] is Data,
           !(queue.edits ?? []).contains(where: { $0.sessionId == round.sessionId && $0.hole == round.hole && $0.kind == .penalty }) {
            var updated = queue
            if updated.penaltyTotals == nil { updated.penaltyTotals = [:] }
            updated.penaltyTotals?["\(round.sessionId):\(round.hole)"] = round.penalties ?? 0
            _ = persist(updated)
        }
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.receive(session.receivedApplicationContext)
            self.sync()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in self.receive(applicationContext) }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in self.sync() }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.location = location
            self.checkReminder()
            if self.acquiringGPS, self.freshLocation != nil, let action = self.captureAction {
                self.cancelCapture()
                action()
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            if self.active && (status == .authorizedWhenInUse || status == .authorizedAlways) {
                self.manager.startUpdatingLocation()
            } else if status == .denied || status == .restricted {
                self.message = "Allow location access in Settings to see yardages and mark shots."
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.message = "GPS unavailable. Move into the open and try again." }
    }
}
