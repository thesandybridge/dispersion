// Live round view — tee boxes, flag positions, pars, yardages, polygon
// overlays, and GPS shot tracking. All data from local HoleInfo records.

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
    @State private var showScorecard = false
    @State private var showRoundSummary = false
    @State private var showRoundSetup = false
    @State private var showHolePicker = false
    @State private var deleteConfirm = false
    @State private var startingHole: Int = 1
    @State private var selectedClubId: String?
    @State private var selectedSwing: SwingType = .full
    @State private var crosshairCoord: Coord?
    @State private var teeOverrides: [Int: Coord] = [:]
    @State private var activeTee: String = "White"
    @State private var activePinZone: PinZone = .middle

    // Cached data — loaded once on appear and on hole change, not per frame
    @State private var cachedCourse: Course?
    @State private var cachedHolePolygons: [CoursePolygon] = []
    @State private var cachedHoleInfos: [Int: HoleInfo] = [:]
    @State private var cachedClubOptions: [ClubOption] = []

    private var course: Course? { cachedCourse }
    private var holePolygons: [CoursePolygon] { cachedHolePolygons }

    private var flagCoord: Coord? {
        cachedHoleInfos[tracker.currentHole]?.pin(activePinZone)
            ?? cachedHoleInfos[tracker.currentHole]?.defaultPinCoord
    }
    private var teeCoord: Coord? {
        teeOverrides[tracker.currentHole]
            ?? cachedHoleInfos[tracker.currentHole]?.teeBox(named: activeTee)?.coord
            ?? cachedHoleInfos[tracker.currentHole]?.firstTeeCoord
    }
    private var teeIsOverridden: Bool { teeOverrides[tracker.currentHole] != nil }
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

    private var holePar: Int { cachedHoleInfos[tracker.currentHole]?.par ?? 4 }
    private var holeYardage: Int { cachedHoleInfos[tracker.currentHole]?.yardage(tee: activeTee) ?? 0 }
    private var holeHandicap: Int { cachedHoleInfos[tracker.currentHole]?.handicap ?? 0 }

    private var distanceToGreen: Int? {
        guard let flag = flagCoord, let loc = location.lastCoord else { return nil }
        return Int(haversineYards(from: loc, to: flag))
    }

    private var clubs: [Club] { clubModels.map { $0.toValue() } }
    private var putter: Club? {
        clubs.first { ClubCategoryRegistry.categorize(name: $0.name, carryYards: $0.carryYards) == .putter }
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
                if tracker.loadIfExists(courseId: c.id) {
                    // Resume existing round
                    let session = Session(id: tracker.sessionId, kind: .round, label: c.name)
                    _ = try? SessionsRepo(context: modelContext).create(session)
                    SessionStore.shared.setActive(ActiveSession(id: tracker.sessionId, kind: .round, label: c.name))
                } else {
                    // New round — show setup
                    showRoundSetup = true
                }
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
        .dispersionSheet(isPresented: $showScorecard, detents: [.large]) {
            scorecardContent(isComplete: false)
        }
        .dispersionSheet(isPresented: $showRoundSetup, detents: [.medium]) {
            roundSetupContent
        }
        .dispersionSheet(isPresented: $showHolePicker, detents: [.medium]) {
            holePickerContent(
                range: tracker.startHole...tracker.lastHole,
                current: tracker.currentHole,
                scores: tracker.scores,
                pars: cachedHoleInfos
            ) { hole in
                tracker.currentHole = hole
                tracker.state = .holeInProgress(hole: hole, shotCount: tracker.shotsForHole(hole).count)
                loadHoleData()
                showHolePicker = false
                Haptics.medium()
            }
        }
        .alert("End round?", isPresented: $showEndRound) {
            Button("Save & finish") { finishRound() }
            Button("Discard", role: .destructive) { cancelRound() }
            Button("Keep playing", role: .cancel) {}
        } message: {
            Text(tracker.holesPlayed > 0
                 ? "\(tracker.holesPlayed) holes · \(tracker.totalScore) strokes"
                 : "No holes scored yet")
        }
        .fullScreenCover(isPresented: $showRoundSummary) {
            roundCompletionScreen
                .preferredColorScheme(.dark)
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
                    Button { showScorecard = true } label: {
                        let tp = tracker.toPar
                        HStack(spacing: 6) {
                            Image(systemName: "list.number")
                                .font(.system(size: 11))
                                .foregroundStyle(DesignTokens.mutedForeground)
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
                Button { showHolePicker = true; Haptics.light() } label: {
                    HStack(spacing: 4) {
                        Text("Hole \(tracker.currentHole)")
                            .font(DispersionType.display(22, weight: .regular))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(DesignTokens.mutedForeground)
                    }
                }
                .buttonStyle(.plain)
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
                if tracker.currentHole > tracker.startHole {
                    Button { prevHole() } label: {
                        Image(systemName: "chevron.left").font(.system(size: 11, weight: .semibold))
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(DesignTokens.surface))
                    }
                    .buttonStyle(.plain)
                }
                if tracker.currentHole < tracker.lastHole {
                    Button { nextHole() } label: {
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(DesignTokens.surface))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)

            // Tee + pin selectors
            let tees = cachedHoleInfos.values.flatMap(\.teeBoxes).map(\.name)
            let uniqueTees = Array(Set(tees)).sorted {
                let order = ["Blue": 0, "White": 1, "Red": 2, "Gold": 3]
                return (order[$0] ?? 4) < (order[$1] ?? 4)
            }
            if uniqueTees.count > 1 || PinZone.allCases.contains(where: { cachedHoleInfos[tracker.currentHole]?.pin($0) != nil }) {
                HStack(spacing: 6) {
                    if uniqueTees.count > 1 {
                        ForEach(uniqueTees, id: \.self) { name in
                            Button {
                                activeTee = name
                                Haptics.light()
                            } label: {
                                let color = TeeBox.defaultColors.first { $0.name == name }?.color ?? "white"
                                HStack(spacing: 4) {
                                    Circle().fill(teeDisplayColor(color)).frame(width: 6, height: 6)
                                    if holeYardage > 0 {
                                        Text("\(holeYardage)y")
                                            .font(DispersionType.mono(10, weight: .medium))
                                    } else {
                                        Text(name)
                                            .font(DispersionType.mono(10, weight: .medium))
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(activeTee == name ? accent : DesignTokens.surface))
                                .foregroundStyle(activeTee == name ? DesignTokens.primaryForeground : DesignTokens.foreground)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Spacer()

                    // Pin zone selector
                    ForEach(PinZone.allCases, id: \.self) { zone in
                        let hasCoord = cachedHoleInfos[tracker.currentHole]?.pin(zone) != nil
                        if hasCoord {
                            Button {
                                activePinZone = zone
                                Haptics.light()
                            } label: {
                                Text(zone.label.prefix(1).uppercased())
                                    .font(DispersionType.mono(10, weight: .bold))
                                    .frame(width: 24, height: 24)
                                    .background(Circle().fill(activePinZone == zone ? accent : DesignTokens.surface))
                                    .foregroundStyle(activePinZone == zone ? DesignTokens.primaryForeground : DesignTokens.foreground)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            Spacer().frame(height: 4)
        }
        .padding(.top, 4)
        .background(DesignTokens.background)
    }

    private func teeDisplayColor(_ color: String) -> Color {
        switch color {
        case "blue": return .blue
        case "white": return .white
        case "red": return .red
        case "gold": return .yellow
        default: return .gray
        }
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

            // Set tee position — bottom left of map
            VStack {
                Spacer()
                HStack {
                    Menu {
                        Button {
                            if let coord = crosshairCoord {
                                setTeeOverride(coord)
                            }
                        } label: {
                            Label("Set tee to crosshair", systemImage: "mappin.and.ellipse")
                        }
                        if teeIsOverridden {
                            Button(role: .destructive) {
                                clearTeeOverride()
                            } label: {
                                Label("Reset to default", systemImage: "arrow.counterclockwise")
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: teeIsOverridden ? "mappin.circle.fill" : "mappin")
                                .font(.system(size: 11))
                            Text("Tee").font(DispersionType.mono(10, weight: .medium))
                        }
                        .foregroundStyle(teeIsOverridden ? accent : .white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .environment(\.colorScheme, .dark)
                        )
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
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
                    logPuttsToClub(count: putts)
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
                    let h = tracker.currentHole
                    if tracker.scores[h] == nil {
                        tracker.scores[h] = HoleScore(hole: h, par: holePar)
                    }
                    tracker.scores[h]?.penaltyStrokes += 1
                    tracker.scores[h]?.score += 1
                    Haptics.error()
                } label: {
                    Text("+1")
                        .font(DispersionType.mono(11, weight: .bold))
                        .foregroundStyle(DesignTokens.pPoor)
                }
                .buttonStyle(.dispersion(.ghost, size: .icon))

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
        let repo = CoursesRepo(context: modelContext)
        cachedCourse = try? repo.get(id: courseId)
        let infos = (try? repo.holeInfos(courseId: courseId)) ?? []
        cachedHoleInfos = Dictionary(uniqueKeysWithValues: infos.map { ($0.holeNumber, $0) })
        // Load tee overrides
        if let data = UserDefaults.standard.data(forKey: "teeOverrides.\(courseId)") {
            teeOverrides = (try? JSONDecoder().decode([Int: Coord].self, from: data)) ?? [:]
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

    private func setTeeOverride(_ coord: Coord) {
        teeOverrides[tracker.currentHole] = coord
        saveTeeOverrides()
        Haptics.success()
    }

    private func clearTeeOverride() {
        teeOverrides.removeValue(forKey: tracker.currentHole)
        saveTeeOverrides()
        Haptics.medium()
    }

    private func saveTeeOverrides() {
        if let data = try? JSONEncoder().encode(teeOverrides) {
            UserDefaults.standard.set(data, forKey: "teeOverrides.\(courseId)")
        }
    }

    private func recommendClubForHole() {
        selectedSwing = .full

        // On green → putter
        if onGreen, let p = putter {
            selectedClubId = p.id
            return
        }

        guard let ball = ballPosition, let flag = flagCoord else { return }
        let dist = haversineYards(from: ball, to: flag)

        // Tee shot on par 4/5 → longest club (driver)
        let shotCount = tracker.shotsForHole(tracker.currentHole).count
        if shotCount == 0 && holePar >= 4, let longest = clubs.first {
            selectedClubId = longest.id
            selectedSwing = .full
            return
        }

        // Best club for distance
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


    private func completeShot(clubId: String?, swing: SwingType = .full, shotType: ShotType = .full) {
        guard let start = pendingShotStart, let end = pendingShotEnd else { return }
        tracker.logShot(from: start, to: end, clubId: clubId, accuracy: location.accuracy)
        if let shot = tracker.shots.last {
            _ = try? CoursesRepo(context: modelContext).createShot(shot)
        }

        // Auto-detect shot outcome relative to target line
        if let flag = flagCoord {
            lastShotOutcome = classifyShot(from: start, landing: end, target: flag, clubId: clubId, swing: swing)

            // Log to main Shot system — only if shot type counts for dispersion
            // Delta is relative to the CLUB'S expected carry, not the flag
            if let clubId, shotType.countsForDispersion {
                let club = clubs.first(where: { $0.id == clubId })
                let clubCarry = (club?.carryYards ?? 0) * swing.carryMultiplier
                let shotDist = haversineYards(from: start, to: end)
                let bearing = bearingRad(from: start, to: flag)
                let shotBearing = bearingRad(from: start, to: end)
                var angleDiff = shotBearing - bearing
                while angleDiff > .pi { angleDiff -= 2 * .pi }
                while angleDiff < -.pi { angleDiff += 2 * .pi }
                let along = shotDist * cos(angleDiff)
                let across = shotDist * sin(angleDiff)
                let ld = along - clubCarry
                let tags = autoOutcomeTags(longDelta: ld, latDelta: across)
                let mainShot = Shot(
                    id: UUID().uuidString.lowercased(),
                    sessionId: tracker.sessionId, clubId: clubId,
                    targetDistanceYards: clubCarry,
                    longDelta: ld,
                    latDelta: across,
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

    private func autoOutcomeTags(longDelta ld: Double, latDelta lat: Double) -> Set<ShotOutcomeTag> {
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
        let targetDist = haversineYards(from: start, to: target)
        let shotDist = haversineYards(from: start, to: landing)
        let bearing = bearingRad(from: start, to: target)
        let shotBearing = bearingRad(from: start, to: landing)
        var angleDiff = shotBearing - bearing
        // Normalize to -π...π
        while angleDiff > .pi { angleDiff -= 2 * .pi }
        while angleDiff < -.pi { angleDiff += 2 * .pi }
        let along = shotDist * cos(angleDiff)
        return along - targetDist
    }

    private func latDelta(from start: Coord, landing: Coord, target: Coord) -> Double {
        let shotDist = haversineYards(from: start, to: landing)
        let bearing = bearingRad(from: start, to: target)
        let shotBearing = bearingRad(from: start, to: landing)
        var angleDiff = shotBearing - bearing
        while angleDiff > .pi { angleDiff -= 2 * .pi }
        while angleDiff < -.pi { angleDiff += 2 * .pi }
        return shotDist * sin(angleDiff)
    }

    private func logPuttsToClub(count: Int) {
        guard count > 0 else { return }
        let putterId = putter?.id
        guard let putterId else { return }
        for i in 1...count {
            let shot = Shot(
                id: UUID().uuidString.lowercased(),
                sessionId: tracker.sessionId,
                clubId: putterId,
                targetDistanceYards: 0,
                longDelta: 0,
                latDelta: 0,
                outcomes: i == count ? [.in] : []
            )
            _ = try? ShotsRepo(context: modelContext).create(shot)
        }
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
        let hole = tracker.currentHole
        let score = tracker.scores[hole]?.score ?? 0
        let par = tracker.scores[hole]?.par ?? 4
        tracker.finishHole()
        tracker.nextHole()
        tracker.save()

        // Last hole → auto-finish
        if tracker.state == .roundComplete {
            finishRound()
            return
        }

        if score > 0 && score <= par - 1 {
            Haptics.success()
        } else if score > par {
            Haptics.error()
        } else {
            Haptics.medium()
        }
    }

    // MARK: - Round setup

    @ViewBuilder
    private var roundSetupContent: some View {
        DSheetHeader(eyebrow: cachedCourse?.name ?? "Round", title: "How many holes?")

        VStack(spacing: 8) {
            roundOption("Front 9", holes: 9, start: 1)
            roundOption("Back 9", holes: 9, start: 10)
            roundOption("Full 18", holes: 18, start: 1)
        }

        VStack(alignment: .leading, spacing: 8) {
            Text("Custom").eyebrow()
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Start").font(DispersionType.mono(9)).foregroundStyle(DesignTokens.mutedForeground)
                    Picker("", selection: $startingHole) {
                        ForEach(1...(cachedCourse?.holeCount ?? 18), id: \.self) { h in
                            Text("\(h)").tag(h)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 80)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Holes").font(DispersionType.mono(9)).foregroundStyle(DesignTokens.mutedForeground)
                    Picker("", selection: $customHoleCount) {
                        ForEach(1...maxCustomHoles, id: \.self) { h in
                            Text("\(h)").tag(h)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 80)
                }
            }
            Button { beginRound(holeCount: customHoleCount, start: startingHole) } label: {
                Text("Start from hole \(startingHole)").frame(maxWidth: .infinity)
            }
            .buttonStyle(.dispersion(.solid))
        }
    }

    @State private var customHoleCount: Int = 9

    private var maxCustomHoles: Int {
        (cachedCourse?.holeCount ?? 18) - startingHole + 1
    }

    private func roundOption(_ label: String, holes: Int, start: Int) -> some View {
        Button {
            beginRound(holeCount: holes, start: start)
        } label: {
            HStack {
                Text(label).font(DispersionType.ui(14, weight: .medium))
                Spacer()
                Text("Holes \(start)-\(start + holes - 1)")
                    .font(DispersionType.mono(11))
                    .foregroundStyle(DesignTokens.mutedForeground)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(DesignTokens.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(DesignTokens.border, lineWidth: 1)
                    )
            )
            .foregroundStyle(DesignTokens.foreground)
        }
        .buttonStyle(.plain)
    }

    private func beginRound(holeCount: Int, start: Int) {
        guard let c = cachedCourse else { return }
        startingHole = start
        tracker.startRound(courseId: c.id, holeCount: holeCount, startHole: start)
        for (hole, info) in cachedHoleInfos {
            tracker.setPar(hole: hole, par: info.par)
        }
        let session = Session(id: tracker.sessionId, kind: .round, label: c.name)
        _ = try? SessionsRepo(context: modelContext).create(session)
        SessionStore.shared.setActive(ActiveSession(id: tracker.sessionId, kind: .round, label: c.name))
        showRoundSetup = false
        loadHoleData()
        Haptics.success()
    }

    @ViewBuilder
    private func holePickerContent(
        range: ClosedRange<Int>, current: Int,
        scores: [Int: HoleScore], pars: [Int: HoleInfo],
        onSelect: @escaping (Int) -> Void
    ) -> some View {
        DSheetHeader(eyebrow: "Jump to", title: "Select hole")

        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(range), id: \.self) { hole in
                let score = scores[hole]?.score ?? 0
                let par = pars[hole]?.par ?? 4
                let isCurrent = hole == current
                Button { onSelect(hole) } label: {
                    VStack(spacing: 2) {
                        Text("\(hole)")
                            .font(DispersionType.display(18, weight: .regular))
                            .monospacedDigit()
                        if score > 0 {
                            Text("\(score)")
                                .font(DispersionType.mono(10, weight: .medium))
                                .foregroundStyle(score < par ? DesignTokens.primary
                                    : score == par ? DesignTokens.foreground
                                    : DesignTokens.pPoor)
                        } else {
                            Text("·")
                                .font(DispersionType.mono(10))
                                .foregroundStyle(DesignTokens.mutedForeground)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isCurrent ? accent.opacity(0.2) : DesignTokens.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(isCurrent ? accent : Color.clear, lineWidth: 1.5)
                            )
                    )
                    .foregroundStyle(DesignTokens.foreground)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Round completion screen

    private var roundCompletionScreen: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [DesignTokens.ink, DesignTokens.pine.opacity(0.6), DesignTokens.backgroundDeep],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            RadialGradient(
                colors: [accent.opacity(0.15), .clear],
                center: .top, startRadius: 0, endRadius: 400
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 40)

                    // Hero
                    scorecardContent(isComplete: true)

                    // Share + Done
                    HStack(spacing: 12) {
                        Button { shareRoundSummary() } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.up").font(.system(size: 14))
                                Text("Share")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.dispersion(.solid))

                        Button {
                            showRoundSummary = false
                            onBack()
                        } label: {
                            Text("Done").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.dispersion(.primary))
                    }
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 40)
                }
            }
        }
    }

    private func shareRoundSummary() {
        let tp = tracker.toPar
        let toParStr = tp == 0 ? "Even" : (tp > 0 ? "+\(tp)" : "\(tp)")
        let courseName = cachedCourse?.name ?? "Round"
        let text = """
        \(courseName)
        \(tracker.totalScore) (\(toParStr)) · \(tracker.holesPlayed) holes
        Putts: \(tracker.totalPutts) · GIR: \(tracker.greensHit)/\(tracker.holesPlayed)

        Tracked with Dispersion
        """
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController?.presentedViewController
                   ?? scene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
    }

    private func finishRound() {
        tracker.state = .roundComplete

        // Compute strokes gained from session shots
        let sessionShots = (try? ShotsRepo(context: modelContext).listBySession(tracker.sessionId)) ?? []
        let sg = StrokesGained.aggregate(sessionShots)

        // Persist round to SwiftData
        let scores = Array(tracker.scores.values).sorted { $0.hole < $1.hole }
        let round = RoundSummary(
            id: tracker.sessionId,
            courseId: courseId,
            courseName: cachedCourse?.name ?? "Round",
            startedAt: tracker.startedAt,
            completedAt: .now,
            holeCount: tracker.holeCount,
            startHole: tracker.startHole,
            totalScore: tracker.totalScore,
            totalPar: tracker.totalPar,
            holesPlayed: tracker.holesPlayed,
            totalPutts: tracker.totalPutts,
            fairwaysHit: tracker.fairwaysHit,
            fairwaysTotal: tracker.fairwaysTotal,
            greensHit: tracker.greensHit,
            greensTotal: tracker.holesPlayed,
            upAndDowns: tracker.upAndDowns,
            upAndDownAttempts: tracker.upAndDownAttempts,
            sgTotal: sg.totalSG,
            sgAvg: sg.avgSG,
            sgShotCount: sg.shotCount,
            scores: scores
        )
        _ = try? CoursesRepo(context: modelContext).createRound(round)

        // Keep UserDefaults for backward compat
        if let data = try? JSONEncoder().encode(scores) {
            UserDefaults.standard.set(data, forKey: "roundScores.\(tracker.sessionId)")
        }

        tracker.clearSave()
        SessionStore.shared.clear()
        Haptics.success()
        showRoundSummary = true
    }

    private func scorecardContent(isComplete: Bool) -> some View {
        let parsMap = Dictionary(uniqueKeysWithValues: cachedHoleInfos.map { ($0.key, $0.value.par) })
        return RoundScorecardView(
            scores: tracker.scores,
            holeCount: tracker.holeCount,
            courseName: cachedCourse?.name ?? "Round",
            pars: parsMap,
            isComplete: isComplete,
            totalPutts: tracker.totalPutts,
            fairwaysHit: tracker.fairwaysHit,
            fairwaysTotal: tracker.fairwaysTotal,
            greensHit: tracker.greensHit,
            greensTotal: tracker.holesPlayed,
            upAndDowns: tracker.upAndDowns,
            upAndDownAttempts: tracker.upAndDownAttempts,
            onDone: isComplete ? {
                showRoundSummary = false
                onBack()
            } : nil
        )
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

    // MARK: - Club picker

    @ViewBuilder
    private var clubPickerContent: some View {
        let shotDist = (pendingShotStart != nil && pendingShotEnd != nil)
            ? Int(haversineYards(from: pendingShotStart!, to: pendingShotEnd!)) : 0
        let preselected = selectedOption

        DSheetHeader(
            eyebrow: "Shot \(tracker.shotsForHole(tracker.currentHole).count + 1) · \(shotDist)y",
            title: "What did you hit?"
        )

        // Recommended club (one-tap confirm)
        if let rec = preselected, let club = clubs.first(where: { $0.id == rec.club.id }) {
            Button {
                completeShot(clubId: rec.club.id, swing: rec.swing)
                showClubPicker = false
            } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Recommended").eyebrow(color: DesignTokens.primary)
                        HStack(spacing: 6) {
                            Text(club.name).font(DispersionType.display(22, weight: .regular))
                            if rec.swing != .full {
                                Text(rec.swing.label)
                                    .font(DispersionType.mono(10, weight: .medium))
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Capsule().fill(DesignTokens.primary.opacity(0.2)))
                                    .foregroundStyle(DesignTokens.primary)
                            }
                        }
                    }
                    Spacer()
                    Text("\(Int(rec.carry))y")
                        .font(DispersionType.mono(14))
                        .foregroundStyle(DesignTokens.mutedForeground)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(DesignTokens.primary.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(DesignTokens.primary.opacity(0.3), lineWidth: 1))
                )
                .foregroundStyle(DesignTokens.foreground)
            }
            .buttonStyle(.plain)
        }

        // Full club list — only full swings, compact
        ScrollView {
            VStack(spacing: 3) {
                ForEach(clubs, id: \.id) { club in
                    let isRec = club.id == preselected?.club.id
                    if !isRec {
                        Button {
                            completeShot(clubId: club.id, swing: .full)
                            showClubPicker = false
                        } label: {
                            HStack(spacing: 8) {
                                Text(club.name)
                                    .font(DispersionType.ui(13, weight: .medium))
                                Spacer()
                                Text("\(Int(club.carryYards))y")
                                    .font(DispersionType.mono(10))
                                    .foregroundStyle(DesignTokens.mutedForeground)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(DesignTokens.surface)
                            )
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(DesignTokens.foreground)
                    }
                }
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

        // Putts stepper — also updates total score
        let shotCount = tracker.shotsForHole(h).count
        HStack {
            Text("Putts").eyebrow()
            Spacer()
            Button {
                let newPutts = max(0, putts - 1)
                tracker.scores[h]?.putts = newPutts
                tracker.setScore(hole: h, score: shotCount + newPutts)
                Haptics.light()
            } label: {
                Image(systemName: "minus").font(.system(size: 12))
                    .frame(width: 32, height: 32).background(Circle().fill(DesignTokens.surface))
            }
            .buttonStyle(.plain)
            Text("\(putts)")
                .font(DispersionType.display(22, weight: .regular))
                .monospacedDigit()
                .frame(width: 36, alignment: .center)
            Button {
                let newPutts = putts + 1
                tracker.scores[h]?.putts = newPutts
                tracker.setScore(hole: h, score: shotCount + newPutts)
                Haptics.light()
            } label: {
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
            Text(tracker.currentHole < tracker.lastHole ? "Next hole →" : "Finish round")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.dispersion(.primary, size: .lg))
        .disabled(score == 0)

        // Mini scorecard
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 3) {
                ForEach(1...tracker.holeCount, id: \.self) { hole in
                    let hs = tracker.scores[hole]
                    let p = cachedHoleInfos[hole]?.par ?? 4
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
