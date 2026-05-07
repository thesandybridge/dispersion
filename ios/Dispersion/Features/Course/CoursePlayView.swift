// Live round view with real GolfBert data — tee boxes, flag positions,
// pars, yardages, polygon overlays, and GPS shot tracking.

import MapKit
import SwiftData
import SwiftUI

struct CoursePlayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeAccent) private var accent
    @StateObject private var location = LocationCapture()
    @Query(sort: \ClubModel.carryYards, order: .reverse) private var clubModels: [ClubModel]

    var courseId: String
    var onBack: () -> Void

    @State private var tracker = RoundTracker()
    @State private var showClubPicker = false
    @State private var pendingShotStart: Coord?
    @State private var pendingShotEnd: Coord?
    @State private var showScoreEdit = false
    @State private var showEndRound = false
    @State private var deleteConfirm = false
    @State private var teeColor = "White"
    @State private var selectedClubId: String?
    @State private var selectedSwing: SwingType = .full
    @State private var crosshairCoord: Coord?

    // Cached data — loaded once on appear and on hole change, not per frame
    @State private var cachedCourse: Course?
    @State private var cachedHolePolygons: [CoursePolygon] = []
    @State private var cachedGBHoles: [GolfBertClient.GBHole] = []
    @State private var cachedScorecard: [GolfBertClient.GBHoleTeebox] = []
    @State private var cachedClubOptions: [ClubOption] = []

    private var course: Course? { cachedCourse }
    private var holePolygons: [CoursePolygon] { cachedHolePolygons }
    private var gbHoles: [GolfBertClient.GBHole] { cachedGBHoles }
    private var gbScorecard: [GolfBertClient.GBHoleTeebox] { cachedScorecard }

    private var currentGBHole: GolfBertClient.GBHole? {
        cachedGBHoles.first(where: { $0.number == tracker.currentHole })
    }
    private var flagCoord: Coord? { currentGBHole?.flagPosition }
    private var teeCoord: Coord? { currentGBHole?.teePosition(color: teeColor) }
    struct ClubOption: Identifiable {
        let id: String
        let club: Club
        let swing: SwingType
        var carry: Double { club.carryYards * swing.carryMultiplier }
        var carrySd: Double { club.carrySd * swing.sigmaMultiplier }
        var lateralSd: Double { club.lateralSd * swing.sigmaMultiplier }
    }

    private var clubOptions: [ClubOption] { cachedClubOptions }

    private var selectedClub: Club? {
        clubs.first(where: { $0.id == selectedClubId }) ?? clubs.first
    }

    private var selectedOption: ClubOption? {
        clubOptions.first(where: { $0.club.id == selectedClubId && $0.swing == selectedSwing })
            ?? clubOptions.first
    }

    // Current ball position — last shot landing or tee
    private var ballPosition: Coord? {
        if let last = tracker.shotsForHole(tracker.currentHole).last {
            return Coord(lat: last.endLat, lng: last.endLng)
        }
        return teeCoord
    }

    private var clubDispersion: HoleMapView.ClubDispersionOverlay? {
        guard let opt = selectedOption, let ball = ballPosition, let flag = flagCoord else { return nil }
        let bearing = bearingRad(from: ball, to: flag)
        let carryMeters = opt.carry * 0.9144
        let landingLat = ball.lat + (carryMeters / 111111.0) * cos(bearing)
        let landingLng = ball.lng + (carryMeters / (111111.0 * cos(ball.lat * .pi / 180))) * sin(bearing)
        let landing = Coord(lat: landingLat, lng: landingLng)
        let label = opt.swing == .full ? opt.club.name : "\(opt.club.name) \(opt.swing.label)"
        return HoleMapView.ClubDispersionOverlay(
            center: landing,
            carrySdYards: opt.carrySd,
            lateralSdYards: opt.lateralSd,
            bearing: bearing,
            clubName: label,
            carryYards: Int(opt.carry)
        )
    }

    private var holePar: Int {
        gbScorecard.first(where: { $0.holenumber == tracker.currentHole && $0.color == teeColor })?.par ?? 4
    }
    private var holeYardage: Int {
        gbScorecard.first(where: { $0.holenumber == tracker.currentHole && $0.color == teeColor })?.length ?? 0
    }
    private var holeHandicap: Int {
        gbScorecard.first(where: { $0.holenumber == tracker.currentHole && $0.color == teeColor })?.handicap ?? 0
    }

    private var distanceToGreen: Int? {
        guard let flag = flagCoord, let loc = location.lastCoord else { return nil }
        return Int(haversineYards(from: loc, to: flag))
    }

    private var clubs: [Club] { clubModels.map { $0.toValue() } }
    private var teeColors: [String] {
        Array(Set(gbScorecard.map(\.color))).sorted { a, b in
            let order = ["Blue": 0, "White": 1, "Red": 2]
            return (order[a] ?? 3) < (order[b] ?? 3)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            mapSection
            bottomPanel
        }
        .onAppear {
            DialStore.shared.setActions([])
            location.requestPermission()
            loadCourseData()
            loadHoleData()
            if tracker.state == .idle, let c = cachedCourse {
                if !tracker.loadIfExists(courseId: c.id) {
                    tracker.startRound(courseId: c.id, holeCount: max(c.holeCount, cachedGBHoles.count))
                    for tb in cachedScorecard where tb.color == teeColor {
                        tracker.setPar(hole: tb.holenumber, par: tb.par)
                    }
                }
                // Create/update session
                let session = Session(id: tracker.sessionId, kind: .round, label: c.name)
                _ = try? SessionsRepo(context: modelContext).create(session)
                SessionStore.shared.setActive(ActiveSession(id: tracker.sessionId, kind: .round, label: c.name))
            }
        }
        .onChange(of: teeColor) { _, _ in
            for tb in cachedScorecard where tb.color == teeColor {
                tracker.setPar(hole: tb.holenumber, par: tb.par)
            }
        }
        .onChange(of: tracker.currentHole) { _, _ in
            loadHoleData()
        }
        .dispersionSheet(isPresented: $showClubPicker, detents: [.medium]) {
            clubPickerContent
        }
        .dispersionSheet(isPresented: $showScoreEdit, detents: [.medium]) {
            scoreEditContent
        }
        .confirmationDialog("End round?", isPresented: $showEndRound, titleVisibility: .visible) {
            Button("Finish & save") { finishRound() }
            Button("Cancel round", role: .destructive) { cancelRound() }
            Button("Keep playing", role: .cancel) {}
        } message: {
            Text(tracker.holesPlayed > 0
                 ? "\(tracker.holesPlayed) holes played · \(tracker.totalScore) strokes"
                 : "No holes scored yet")
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        VStack(spacing: 4) {
            HStack {
                Button { showEndRound = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 12))
                        Text("Exit")
                    }
                    .font(DispersionType.mono(12))
                    .foregroundStyle(DesignTokens.mutedForeground)
                }
                .buttonStyle(.plain)
                Spacer()
                if tracker.holesPlayed > 0 {
                    Button { showScoreEdit = true } label: {
                        let tp = tracker.toPar
                        HStack(spacing: 6) {
                            Text("\(tracker.totalScore)")
                                .font(DispersionType.display(18, weight: .regular))
                                .monospacedDigit()
                            Text(tp == 0 ? "E" : (tp > 0 ? "+\(tp)" : "\(tp)"))
                                .font(DispersionType.mono(11, weight: .medium))
                                .foregroundStyle(tp < 0 ? DesignTokens.primary
                                                 : tp == 0 ? DesignTokens.foreground
                                                 : DesignTokens.pPoor)
                        }
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 16)

            // Hole info + tee selector
            HStack(spacing: 10) {
                Text("Hole \(tracker.currentHole)")
                    .font(DispersionType.display(22, weight: .regular))
                Text("Par \(holePar)")
                    .font(DispersionType.mono(12, weight: .medium))
                    .foregroundStyle(DesignTokens.mutedForeground)
                if holeHandicap > 0 {
                    Text("HCP \(holeHandicap)")
                        .font(DispersionType.mono(10))
                        .foregroundStyle(DesignTokens.mutedForeground.opacity(0.6))
                }
                Spacer()
                // Hole nav
                if tracker.currentHole > 1 {
                    Button { prevHole() } label: {
                        Image(systemName: "chevron.left").font(.system(size: 11, weight: .semibold))
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(DesignTokens.surface))
                    }
                    .buttonStyle(.plain)
                }
                if tracker.currentHole < tracker.holeCount {
                    Button { nextHole() } label: {
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(DesignTokens.surface))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)

            // Tee selector — segmented pill
            if teeColors.count > 1 {
                HStack(spacing: 0) {
                    ForEach(teeColors, id: \.self) { color in
                        let isSelected = teeColor == color
                        let yds = gbScorecard.first(where: { $0.holenumber == tracker.currentHole && $0.color == color })?.length ?? 0
                        Button {
                            teeColor = color
                            Haptics.medium()
                        } label: {
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(teeColorSwift(color))
                                    .frame(width: 8, height: 8)
                                    .overlay(Circle().strokeBorder(color == "White" ? Color.gray.opacity(0.4) : .clear, lineWidth: 0.5))
                                Text("\(yds)y")
                                    .font(DispersionType.mono(11, weight: .medium))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(isSelected ? DesignTokens.primary : Color.clear)
                            .foregroundStyle(isSelected ? DesignTokens.primaryForeground : DesignTokens.foreground)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(DesignTokens.surface)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(DesignTokens.border, lineWidth: 1))
                .padding(.horizontal, 16)
            }

            Spacer().frame(height: 4)
        }
        .padding(.top, 4)
        .background(DesignTokens.background)
    }

    // MARK: - Map

    private var mapSection: some View {
        ZStack(alignment: .top) {
        HoleMapView(
            polygons: holePolygons,
            shots: tracker.shotsForHole(tracker.currentHole),
            centerCoord: course.map { Coord(lat: $0.centerLat, lng: $0.centerLng) },
            teeCoord: ballPosition ?? teeCoord,
            greenCoord: flagCoord,
            showCrosshair: true,
            dispersion: clubDispersion,
            crosshairCoord: $crosshairCoord
        )
        .frame(maxHeight: .infinity)

            if let outcome = lastShotOutcome {
                Text(outcome)
                    .font(DispersionType.mono(11, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(accent.opacity(0.9)))
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: lastShotOutcome)
            }
        }
    }

    private var onGreen: Bool {
        guard let ball = ballPosition else { return false }
        let greens = cachedHolePolygons.filter { $0.surface == .green && $0.coordinates.count >= 3 }
        return greens.contains { pointInPolygon(ball, polygon: $0.coordinates) }
    }

    // MARK: - Bottom panel

    private var bottomPanel: some View {
        VStack(spacing: 6) {
            if onGreen {
                puttingPanel
            } else {
                approachPanel
            }
        }
        .background(DesignTokens.card)
        .animation(.easeInOut(duration: 0.2), value: onGreen)
    }

    // MARK: Putting panel (on green)

    private var puttingPanel: some View {
        VStack(spacing: 10) {
            let shotCount = tracker.shotsForHole(tracker.currentHole).count
            let putts = tracker.scores[tracker.currentHole]?.putts ?? 2

            HStack(spacing: 20) {
                VStack(spacing: 0) {
                    Text("\(shotCount)")
                        .font(DispersionType.display(32, weight: .regular))
                        .monospacedDigit()
                    Text("strokes")
                        .font(DispersionType.mono(9))
                        .foregroundStyle(DesignTokens.mutedForeground)
                }

                Spacer()

                // Putts stepper
                HStack(spacing: 8) {
                    Text("Putts").font(DispersionType.mono(11, weight: .medium))
                    Button { tracker.scores[tracker.currentHole]?.putts = max(0, putts - 1); Haptics.light() } label: {
                        Image(systemName: "minus").font(.system(size: 12))
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(DesignTokens.surface))
                    }
                    .buttonStyle(.plain)
                    Text("\(putts)")
                        .font(DispersionType.display(24, weight: .regular))
                        .monospacedDigit()
                        .frame(width: 30, alignment: .center)
                    Button { tracker.scores[tracker.currentHole]?.putts = putts + 1; Haptics.light() } label: {
                        Image(systemName: "plus").font(.system(size: 12))
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(DesignTokens.surface))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            HStack(spacing: 8) {
                if !tracker.shotsForHole(tracker.currentHole).isEmpty {
                    Button { undoShot() } label: {
                        Image(systemName: "arrow.uturn.backward").font(.system(size: 13))
                    }
                    .buttonStyle(.dispersion(.ghost, size: .lg))
                    .frame(width: 44)
                }

                Button {
                    let total = shotCount + putts
                    tracker.setScore(hole: tracker.currentHole, score: total)
                    tracker.scores[tracker.currentHole]?.putts = putts
                    showScoreEdit = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "flag.checkered").font(.system(size: 13))
                        Text("Finish hole")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.dispersion(.primary, size: .lg))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    // MARK: Approach panel (off green)

    private var approachPanel: some View {
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                if let ball = ballPosition, let ch = crosshairCoord {
                    let fromBall = Int(haversineYards(from: ball, to: ch))
                    VStack(spacing: 0) {
                        Text("\(fromBall)")
                            .font(DispersionType.display(32, weight: .regular))
                            .foregroundStyle(DesignTokens.foreground)
                            .monospacedDigit()
                        Text("from ball")
                            .font(DispersionType.mono(9))
                            .foregroundStyle(DesignTokens.mutedForeground)
                    }
                    .frame(maxWidth: .infinity)
                }

                if let ch = crosshairCoord, let flag = flagCoord {
                    let toPin = Int(haversineYards(from: ch, to: flag))
                    VStack(spacing: 0) {
                        Text("\(toPin)")
                            .font(DispersionType.display(32, weight: .regular))
                            .foregroundStyle(DesignTokens.primary)
                            .monospacedDigit()
                        Text("to pin")
                            .font(DispersionType.mono(9))
                            .foregroundStyle(DesignTokens.mutedForeground)
                    }
                    .frame(maxWidth: .infinity)
                }

                let shotCount = tracker.shotsForHole(tracker.currentHole).count
                VStack(spacing: 0) {
                    Text("\(shotCount)")
                        .font(DispersionType.display(22, weight: .regular))
                        .monospacedDigit()
                    Text("shots")
                        .font(DispersionType.mono(9))
                        .foregroundStyle(DesignTokens.mutedForeground)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Club selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(clubOptions, id: \.id) { opt in
                        let isSel = selectedClubId == opt.club.id && selectedSwing == opt.swing
                        Button {
                            selectedClubId = opt.club.id
                            selectedSwing = opt.swing
                            Haptics.light()
                        } label: {
                            VStack(spacing: 1) {
                                HStack(spacing: 3) {
                                    Text(opt.club.name)
                                        .font(DispersionType.ui(10, weight: .medium))
                                        .lineLimit(1)
                                    if opt.swing != .full {
                                        Text(opt.swing.label)
                                            .font(DispersionType.mono(8, weight: .medium))
                                            .foregroundStyle(isSel ? DesignTokens.primaryForeground.opacity(0.7) : DesignTokens.mutedForeground)
                                    }
                                }
                                Text("\(Int(opt.carry))y")
                                    .font(DispersionType.mono(9))
                                    .foregroundStyle(isSel ? DesignTokens.primaryForeground.opacity(0.7) : DesignTokens.mutedForeground)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(isSel ? DesignTokens.primary : DesignTokens.surface)
                            )
                            .foregroundStyle(isSel ? DesignTokens.primaryForeground : DesignTokens.foreground)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }

            HStack(spacing: 10) {
                if !tracker.shotsForHole(tracker.currentHole).isEmpty {
                    Button { undoShot() } label: {
                        Image(systemName: "arrow.uturn.backward").font(.system(size: 14))
                    }
                    .buttonStyle(.dispersion(.ghost, size: .icon))
                }

                Button { logShot() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "scope").font(.system(size: 14))
                        Text("Log shot")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.dispersion(.primary))

                Button { logShotGPS() } label: {
                    Image(systemName: "location.fill").font(.system(size: 14))
                }
                .buttonStyle(.dispersion(.outline, size: .icon))

                Button {
                    let shots = tracker.shotsForHole(tracker.currentHole).count
                    tracker.setScore(hole: tracker.currentHole, score: max(shots, 1))
                    showScoreEdit = true
                } label: {
                    Image(systemName: "flag.checkered").font(.system(size: 14))
                }
                .buttonStyle(.dispersion(.outline, size: .icon))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)

            if location.capturing {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.6)
                    Text("Getting GPS fix...").font(DispersionType.mono(10)).foregroundStyle(DesignTokens.mutedForeground)
                }
            }
        }
    }

    // MARK: - Data loading (called once, not per frame)

    private func loadCourseData() {
        cachedCourse = try? CoursesRepo(context: modelContext).get(id: courseId)
        if let data = UserDefaults.standard.data(forKey: "holes.\(courseId)") {
            cachedGBHoles = (try? JSONDecoder().decode([GolfBertClient.GBHole].self, from: data)) ?? []
        }
        if let data = UserDefaults.standard.data(forKey: "scorecard.\(courseId)") {
            cachedScorecard = (try? JSONDecoder().decode([GolfBertClient.GBHoleTeebox].self, from: data)) ?? []
        }
        // Build club options once
        var opts: [ClubOption] = []
        for club in clubs {
            let cat = ClubCategoryRegistry.categorize(name: club.name, carryYards: club.carryYards)
            let swings: [SwingType]
            switch cat {
            case .wedge: swings = [.full, .threeQuarter, .half]
            case .shortIron: swings = [.full, .threeQuarter]
            default: swings = [.full]
            }
            for s in swings {
                opts.append(ClubOption(id: "\(club.id)_\(s.rawValue)", club: club, swing: s))
            }
        }
        cachedClubOptions = opts
    }

    private func loadHoleData() {
        cachedHolePolygons = (try? CoursesRepo(context: modelContext).polygons(courseId: courseId, hole: tracker.currentHole)) ?? []
        recommendClubForHole()
    }

    private func recommendClubForHole() {
        guard let ball = ballPosition, let flag = flagCoord else { return }
        let dist = haversineYards(from: ball, to: flag)
        if dist > 5, let best = cachedClubOptions.min(by: { abs($0.carry - dist) < abs($1.carry - dist) }) {
            selectedClubId = best.club.id
            selectedSwing = best.swing
        }
    }

    // MARK: - Actions

    private func shotStart() -> Coord? {
        if let last = tracker.shotsForHole(tracker.currentHole).last {
            return Coord(lat: last.endLat, lng: last.endLng)
        }
        return teeCoord
    }

    private func logShot() {
        guard let landing = crosshairCoord, let start = shotStart() else { return }
        pendingShotStart = start
        pendingShotEnd = landing
        showClubPicker = true
    }

    private func logShotGPS() {
        Task {
            guard let landing = try? await location.capture(), let start = shotStart() else { return }
            pendingShotStart = start
            pendingShotEnd = landing
            showClubPicker = true
        }
    }

    @State private var lastShotOutcome: String?

    private func completeShot(clubId: String?, swing: SwingType = .full) {
        guard let start = pendingShotStart, let end = pendingShotEnd else { return }
        tracker.logShot(from: start, to: end, clubId: clubId, accuracy: location.accuracy)
        if let shot = tracker.shots.last {
            _ = try? CoursesRepo(context: modelContext).createShot(shot)
        }

        // Auto-detect shot outcome relative to target line
        if let flag = flagCoord {
            lastShotOutcome = classifyShot(from: start, landing: end, target: flag, clubId: clubId, swing: swing)

            // Also log to the main Shot system with outcome tags
            if let clubId {
                let tags = autoOutcomeTags(from: start, landing: end, target: flag)
                let mainShot = Shot(
                    id: UUID().uuidString.lowercased(),
                    sessionId: tracker.sessionId, clubId: clubId,
                    targetDistanceYards: haversineYards(from: start, to: flag),
                    longDelta: longDelta(from: start, landing: end, target: flag),
                    latDelta: latDelta(from: start, landing: end, target: flag),
                    outcomes: tags
                )
                _ = try? ShotsRepo(context: modelContext).create(mainShot)
            }

            // Auto-detect FIR (tee shot landed on fairway polygon)
            let shotNum = tracker.shotsForHole(tracker.currentHole).count
            if shotNum == 1 && holePar >= 4 {
                let fairways = holePolygons.filter { $0.surface == .fairway && $0.coordinates.count >= 3 }
                let onFairway = fairways.contains { pointInPolygon(end, polygon: $0.coordinates) }
                tracker.scores[tracker.currentHole]?.fairwayHit = onFairway
            }

            // Auto-detect GIR (on green in par - 2 shots or fewer)
            let greens = holePolygons.filter { $0.surface == .green && $0.coordinates.count >= 3 }
            let onGreen = greens.contains { pointInPolygon(end, polygon: $0.coordinates) }
            if onGreen && shotNum <= holePar - 2 {
                tracker.scores[tracker.currentHole]?.girHit = true
            }

            // Auto-select best club+swing for remaining distance
            let remaining = haversineYards(from: end, to: flag)
            if remaining > 5 {
                let best = clubOptions.min(by: { a, b in
                    abs(a.carry - remaining) < abs(b.carry - remaining)
                })
                if let best {
                    selectedClubId = best.club.id
                    selectedSwing = best.swing
                }
            }
        }

        pendingShotStart = nil
        pendingShotEnd = nil
        tracker.save()
        Haptics.success()

        // Clear outcome after a few seconds
        Task {
            try? await Task.sleep(for: .seconds(3))
            lastShotOutcome = nil
        }
    }

    private func classifyShot(from start: Coord, landing: Coord, target: Coord, clubId: String?, swing: SwingType = .full) -> String {
        let ld = longDelta(from: start, landing: landing, target: target)
        let lat = latDelta(from: start, landing: landing, target: target)
        let clubName = clubId.flatMap { id in clubs.first(where: { $0.id == id })?.name } ?? "Shot"
        let swingLabel = swing == .full ? "" : " \(swing.label)"

        var parts: [String] = [clubName + swingLabel]
        let totalDist = Int(haversineYards(from: start, to: landing))
        parts.append("\(totalDist)y")

        if abs(ld) > 3 {
            parts.append(ld < 0 ? "\(Int(abs(ld)))y short" : "\(Int(ld))y long")
        }
        if abs(lat) > 3 {
            parts.append(lat < 0 ? "\(Int(abs(lat)))y left" : "\(Int(lat))y right")
        }
        if abs(ld) <= 3 && abs(lat) <= 3 {
            parts.append("on target")
        }
        return parts.joined(separator: " · ")
    }

    private func autoOutcomeTags(from start: Coord, landing: Coord, target: Coord) -> Set<ShotOutcomeTag> {
        let ld = longDelta(from: start, landing: landing, target: target)
        let lat = latDelta(from: start, landing: landing, target: target)
        var tags: Set<ShotOutcomeTag> = []

        if abs(ld) <= 3 && abs(lat) <= 3 {
            tags.insert(.in)
        } else {
            if ld < -3 { tags.insert(.short) }
            if ld > 3 { tags.insert(.long) }
            if lat < -3 { tags.insert(.left) }
            if lat > 3 { tags.insert(.right) }
        }
        return tags
    }

    // Project landing onto the start→target line to get long/lat deltas
    private func longDelta(from start: Coord, landing: Coord, target: Coord) -> Double {
        let bearing = bearingRad(from: start, to: target)
        let dist = haversineYards(from: start, to: landing)
        let shotBearing = bearingRad(from: start, to: landing)
        let angleDiff = shotBearing - bearing
        let along = dist * cos(angleDiff)
        let targetDist = haversineYards(from: start, to: target)
        return along - targetDist
    }

    private func latDelta(from start: Coord, landing: Coord, target: Coord) -> Double {
        let bearing = bearingRad(from: start, to: target)
        let dist = haversineYards(from: start, to: landing)
        let shotBearing = bearingRad(from: start, to: landing)
        let angleDiff = shotBearing - bearing
        return dist * sin(angleDiff)
    }

    private func undoShot() {
        if let _ = tracker.undoLastShot() {
            try? CoursesRepo(context: modelContext).deleteShots(courseId: courseId, hole: tracker.currentHole)
            for shot in tracker.shotsForHole(tracker.currentHole) {
                _ = try? CoursesRepo(context: modelContext).createShot(shot)
            }
            tracker.save()
            Haptics.medium()
        }
    }

    private func nextHole() {
        tracker.finishHole()
        tracker.nextHole()
        tracker.save()
        Haptics.light()
    }

    private func finishRound() {
        tracker.state = .roundComplete
        // Persist scorecard data keyed by sessionId
        if let data = try? JSONEncoder().encode(Array(tracker.scores.values)) {
            UserDefaults.standard.set(data, forKey: "roundScores.\(tracker.sessionId)")
        }
        tracker.clearSave()
        SessionStore.shared.clear()
        Haptics.success()
        onBack()
    }

    private func cancelRound() {
        // Delete all shots from this session
        let shots = tracker.shots
        for shot in shots {
            try? CoursesRepo(context: modelContext).deleteShots(courseId: courseId, hole: shot.holeNumber)
        }
        if !tracker.sessionId.isEmpty {
            try? SessionsRepo(context: modelContext).delete(id: tracker.sessionId)
        }
        tracker.clearSave()
        SessionStore.shared.clear()
        onBack()
    }

    private func prevHole() {
        tracker.currentHole -= 1
        tracker.state = .holeInProgress(hole: tracker.currentHole, shotCount: tracker.shotsForHole(tracker.currentHole).count)
        Haptics.light()
    }

    private func teeColorSwift(_ color: String) -> Color {
        switch color {
        case "Blue": return .blue
        case "White": return .white
        case "Red": return .red
        case "Gold", "Yellow": return .yellow
        case "Black": return .black
        default: return .gray
        }
    }

    // MARK: - Club picker

    @ViewBuilder
    private var clubPickerContent: some View {
        let shotDist = (pendingShotStart != nil && pendingShotEnd != nil)
            ? Int(haversineYards(from: pendingShotStart!, to: pendingShotEnd!)) : 0

        DSheetHeader(
            eyebrow: "Shot \(tracker.shotsForHole(tracker.currentHole).count + 1) · \(shotDist)y",
            title: "What did you hit?"
        )

        // Pre-select the currently selected club option
        let preselected = selectedOption

        VStack(spacing: 4) {
            ForEach(clubOptions, id: \.id) { opt in
                let isRecommended = opt.id == preselected?.id
                Button {
                    completeShot(clubId: opt.club.id, swing: opt.swing)
                    showClubPicker = false
                } label: {
                    HStack(spacing: 8) {
                        Text(opt.club.name)
                            .font(DispersionType.ui(14, weight: .medium))
                        if opt.swing != .full {
                            Text(opt.swing.label)
                                .font(DispersionType.mono(10, weight: .medium))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(DesignTokens.primary.opacity(0.15)))
                                .foregroundStyle(DesignTokens.primary)
                        }
                        Spacer()
                        Text("\(Int(opt.carry))y")
                            .font(DispersionType.mono(11))
                            .foregroundStyle(DesignTokens.mutedForeground)
                        if isRecommended {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(DesignTokens.primary)
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isRecommended ? DesignTokens.primary.opacity(0.08) : DesignTokens.surface)
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(isRecommended ? DesignTokens.primary.opacity(0.3) : DesignTokens.border, lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)
            }
        }

        Button {
            completeShot(clubId: nil, swing: .full)
            showClubPicker = false
        } label: {
            Text("Skip").frame(maxWidth: .infinity)
        }
        .buttonStyle(.dispersion(.ghost))
    }

    private func bearingRad(from a: Coord, to b: Coord) -> Double {
        let lat1 = a.lat * .pi / 180; let lat2 = b.lat * .pi / 180
        let dLng = (b.lng - a.lng) * .pi / 180
        let y = sin(dLng) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng)
        return atan2(y, x)
    }

    // MARK: - Score edit

    @ViewBuilder
    private var scoreEditContent: some View {
        let h = tracker.currentHole
        let score = tracker.scores[h]?.score ?? 0
        let putts = tracker.scores[h]?.putts ?? 2

        DSheetHeader(eyebrow: "Hole \(h) · Par \(holePar) · \(holeYardage)y", title: "Score")

        let minScore = max(tracker.shotsForHole(h).count, 1)

        // Score stepper
        HStack {
            Button { tracker.setScore(hole: h, score: max(minScore, score - 1)); Haptics.light() } label: {
                Image(systemName: "minus").font(.system(size: 16, weight: .medium))
                    .frame(width: 44, height: 44).background(Circle().fill(DesignTokens.surface))
            }
            .buttonStyle(.plain)

            VStack(spacing: 2) {
                Text("\(score)")
                    .font(DispersionType.display(48, weight: .regular))
                    .monospacedDigit()
                    .foregroundStyle(score < holePar ? DesignTokens.primary
                                     : score == holePar ? DesignTokens.foreground
                                     : DesignTokens.pPoor)
                if score > 0 {
                    Text(HoleScore(hole: h, par: holePar, score: score).label)
                        .font(DispersionType.mono(11, weight: .medium))
                        .foregroundStyle(DesignTokens.mutedForeground)
                }
            }
            .frame(width: 90)

            Button { tracker.setScore(hole: h, score: score + 1); Haptics.light() } label: {
                Image(systemName: "plus").font(.system(size: 16, weight: .medium))
                    .frame(width: 44, height: 44).background(Circle().fill(DesignTokens.surface))
            }
            .buttonStyle(.plain)
        }

        // Putts stepper
        HStack {
            Text("Putts").eyebrow()
            Spacer()
            Button { tracker.scores[h]?.putts = max(0, putts - 1); Haptics.light() } label: {
                Image(systemName: "minus").font(.system(size: 12))
                    .frame(width: 32, height: 32).background(Circle().fill(DesignTokens.surface))
            }
            .buttonStyle(.plain)
            Text("\(putts)")
                .font(DispersionType.display(22, weight: .regular))
                .monospacedDigit()
                .frame(width: 36, alignment: .center)
            Button { tracker.scores[h]?.putts = putts + 1; Haptics.light() } label: {
                Image(systemName: "plus").font(.system(size: 12))
                    .frame(width: 32, height: 32).background(Circle().fill(DesignTokens.surface))
            }
            .buttonStyle(.plain)
        }

        // FIR / GIR toggles
        HStack(spacing: 12) {
            statToggle("FIR", value: Binding(
                get: { tracker.scores[h]?.fairwayHit },
                set: { tracker.scores[h]?.fairwayHit = $0 }
            ))
            statToggle("GIR", value: Binding(
                get: { tracker.scores[h]?.girHit },
                set: { tracker.scores[h]?.girHit = $0 }
            ))
            statToggle("Up & Down", value: Binding(
                get: { tracker.scores[h]?.upAndDown },
                set: { tracker.scores[h]?.upAndDown = $0 }
            ))
        }

        // Penalty
        HStack {
            Text("Penalties").eyebrow()
            Spacer()
            Button { if (tracker.scores[h]?.penaltyStrokes ?? 0) > 0 { tracker.scores[h]?.penaltyStrokes -= 1 }; Haptics.light() } label: {
                Image(systemName: "minus").font(.system(size: 10))
                    .frame(width: 28, height: 28).background(Circle().fill(DesignTokens.surface))
            }
            .buttonStyle(.plain)
            Text("\(tracker.scores[h]?.penaltyStrokes ?? 0)")
                .font(DispersionType.mono(14, weight: .medium))
                .foregroundStyle(DesignTokens.pPoor)
                .frame(width: 28, alignment: .center)
            Button { tracker.scores[h]?.penaltyStrokes += 1; Haptics.light() } label: {
                Image(systemName: "plus").font(.system(size: 10))
                    .frame(width: 28, height: 28).background(Circle().fill(DesignTokens.surface))
            }
            .buttonStyle(.plain)
        }

        Button {
            showScoreEdit = false
            nextHole()
        } label: {
            Text(tracker.currentHole < tracker.holeCount ? "Next hole →" : "Finish round")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.dispersion(.primary, size: .lg))
        .disabled(score == 0)

        // Mini scorecard
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 3) {
                ForEach(1...tracker.holeCount, id: \.self) { hole in
                    let hs = tracker.scores[hole]
                    let p = gbScorecard.first(where: { $0.holenumber == hole && $0.color == teeColor })?.par ?? 4
                    VStack(spacing: 2) {
                        Text("\(hole)").font(DispersionType.mono(8)).foregroundStyle(DesignTokens.mutedForeground)
                        Text(hs?.score ?? 0 > 0 ? "\(hs!.score)" : "-")
                            .font(DispersionType.mono(10, weight: .medium))
                            .foregroundStyle(
                                (hs?.score ?? 0) == 0 ? DesignTokens.mutedForeground
                                : hs!.score < p ? DesignTokens.primary
                                : hs!.score == p ? DesignTokens.foreground
                                : DesignTokens.pPoor
                            )
                    }
                    .frame(width: 24)
                }
            }
        }
    }

    private func statToggle(_ label: String, value: Binding<Bool?>) -> some View {
        Button {
            switch value.wrappedValue {
            case nil: value.wrappedValue = true
            case true: value.wrappedValue = false
            case false: value.wrappedValue = nil
            }
            Haptics.light()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: value.wrappedValue == true ? "checkmark.circle.fill"
                      : value.wrappedValue == false ? "xmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(value.wrappedValue == true ? DesignTokens.primary
                                    : value.wrappedValue == false ? DesignTokens.pPoor
                                    : DesignTokens.mutedForeground)
                Text(label).font(DispersionType.mono(10, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 8).fill(DesignTokens.surface))
        }
        .buttonStyle(.plain)
    }
}
