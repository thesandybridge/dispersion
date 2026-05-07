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
    @State private var deleteConfirm = false
    @State private var teeColor = "White"

    private var course: Course? {
        try? CoursesRepo(context: modelContext).get(id: courseId)
    }
    private var allPolygons: [CoursePolygon] {
        (try? CoursesRepo(context: modelContext).polygons(courseId: courseId)) ?? []
    }
    private var holePolygons: [CoursePolygon] {
        allPolygons.filter { $0.holeNumber == tracker.currentHole }
    }

    // Cached GolfBert data
    private var gbHoles: [GolfBertClient.GBHole] {
        guard let data = UserDefaults.standard.data(forKey: "holes.\(courseId)"),
              let holes = try? JSONDecoder().decode([GolfBertClient.GBHole].self, from: data)
        else { return [] }
        return holes
    }
    private var gbScorecard: [GolfBertClient.GBHoleTeebox] {
        guard let data = UserDefaults.standard.data(forKey: "scorecard.\(courseId)"),
              let tees = try? JSONDecoder().decode([GolfBertClient.GBHoleTeebox].self, from: data)
        else { return [] }
        return tees
    }

    private var currentGBHole: GolfBertClient.GBHole? {
        gbHoles.first(where: { $0.number == tracker.currentHole })
    }
    private var flagCoord: Coord? { currentGBHole?.flagPosition }
    private var teeCoord: Coord? { currentGBHole?.teePosition(color: teeColor) }
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
            location.requestPermission()
            if tracker.state == .idle, let c = course {
                tracker.startRound(courseId: c.id, holeCount: max(c.holeCount, gbHoles.count))
                for tb in gbScorecard where tb.color == teeColor {
                    tracker.setPar(hole: tb.holenumber, par: tb.par)
                }
            }
        }
        .onChange(of: teeColor) { _, _ in
            for tb in gbScorecard where tb.color == teeColor {
                tracker.setPar(hole: tb.holenumber, par: tb.par)
            }
        }
        .dispersionSheet(isPresented: $showClubPicker, detents: [.medium]) {
            clubPickerContent
        }
        .dispersionSheet(isPresented: $showScoreEdit, detents: [.medium]) {
            scoreEditContent
        }
        .alert("Delete this course?", isPresented: $deleteConfirm) {
            Button("Delete", role: .destructive) {
                try? CoursesRepo(context: modelContext).deleteCourse(id: courseId)
                onBack()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        VStack(spacing: 4) {
            HStack {
                Button { onBack() } label: {
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
                // Tee color picker
                HStack(spacing: 4) {
                    ForEach(teeColors, id: \.self) { color in
                        Button { teeColor = color; Haptics.light() } label: {
                            Circle()
                                .fill(teeColorSwift(color))
                                .frame(width: teeColor == color ? 16 : 12, height: teeColor == color ? 16 : 12)
                                .overlay {
                                    if teeColor == color {
                                        Circle().strokeBorder(.white, lineWidth: 1.5)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)

            // Hole info
            HStack(spacing: 10) {
                Text("Hole \(tracker.currentHole)")
                    .font(DispersionType.display(22, weight: .regular))
                Text("Par \(holePar)")
                    .font(DispersionType.mono(12, weight: .medium))
                    .foregroundStyle(DesignTokens.mutedForeground)
                Text("\(holeYardage)y")
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
            .padding(.bottom, 4)
        }
        .padding(.top, 4)
        .background(DesignTokens.background)
    }

    // MARK: - Map

    private var mapSection: some View {
        HoleMapView(
            polygons: holePolygons,
            shots: tracker.shotsForHole(tracker.currentHole),
            centerCoord: course.map { Coord(lat: $0.centerLat, lng: $0.centerLng) },
            teeCoord: teeCoord,
            greenCoord: flagCoord
        )
        .frame(maxHeight: .infinity)
    }

    // MARK: - Bottom panel

    private var bottomPanel: some View {
        VStack(spacing: 6) {
            HStack(spacing: 20) {
                if let d = distanceToGreen {
                    VStack(spacing: 0) {
                        Text("\(d)")
                            .font(DispersionType.display(36, weight: .regular))
                            .foregroundStyle(DesignTokens.primary)
                            .monospacedDigit()
                        Text("to pin")
                            .font(DispersionType.mono(9))
                            .foregroundStyle(DesignTokens.mutedForeground)
                    }
                }
                Spacer()
                let shotCount = tracker.shotsForHole(tracker.currentHole).count
                if shotCount > 0 {
                    VStack(spacing: 0) {
                        Text("\(shotCount)")
                            .font(DispersionType.display(22, weight: .regular))
                            .monospacedDigit()
                        Text("shots")
                            .font(DispersionType.mono(9))
                            .foregroundStyle(DesignTokens.mutedForeground)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            HStack(spacing: 10) {
                Button { logShot() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "scope").font(.system(size: 13))
                        Text("Log shot")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.dispersion(.primary, size: .lg))

                Button {
                    let shots = tracker.shotsForHole(tracker.currentHole).count
                    tracker.setScore(hole: tracker.currentHole, score: max(shots, 1))
                    showScoreEdit = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark").font(.system(size: 13))
                        Text("Score")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.dispersion(.outline, size: .lg))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            if location.capturing {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.6)
                    Text("Getting GPS...").font(DispersionType.mono(10)).foregroundStyle(DesignTokens.mutedForeground)
                }
            }
        }
        .background(DesignTokens.card)
    }

    // MARK: - Actions

    private func logShot() {
        Task {
            guard let coord = try? await location.capture() else { return }
            let start: Coord
            if let last = tracker.shotsForHole(tracker.currentHole).last {
                start = Coord(lat: last.endLat, lng: last.endLng)
            } else if let tee = teeCoord {
                start = tee
            } else {
                start = coord
            }
            pendingShotStart = start
            pendingShotEnd = coord
            showClubPicker = true
        }
    }

    private func completeShot(clubId: String?) {
        guard let start = pendingShotStart, let end = pendingShotEnd else { return }
        tracker.logShot(from: start, to: end, clubId: clubId, accuracy: location.accuracy)
        if let shot = tracker.shots.last {
            _ = try? CoursesRepo(context: modelContext).createShot(shot)
        }
        pendingShotStart = nil
        pendingShotEnd = nil
        Haptics.success()
    }

    private func nextHole() {
        tracker.finishHole()
        tracker.nextHole()
        Haptics.light()
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
        DSheetHeader(eyebrow: "Shot \(tracker.shotsForHole(tracker.currentHole).count + 1)", title: "What did you hit?")

        if let start = pendingShotStart, let end = pendingShotEnd {
            Text("\(Int(haversineYards(from: start, to: end))) yards")
                .font(DispersionType.display(32, weight: .regular))
                .monospacedDigit()
                .foregroundStyle(DesignTokens.primary)
        }

        VStack(spacing: 6) {
            ForEach(clubs, id: \.id) { club in
                Button {
                    completeShot(clubId: club.id)
                    showClubPicker = false
                } label: {
                    HStack {
                        Text(club.name).font(DispersionType.ui(14, weight: .medium))
                        Text("\(Int(club.carryYards))y").font(DispersionType.mono(11)).foregroundStyle(DesignTokens.mutedForeground)
                        Spacer()
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(DesignTokens.surface)
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(DesignTokens.border, lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)
            }
        }

        Button {
            completeShot(clubId: nil)
            showClubPicker = false
        } label: {
            Text("Skip").frame(maxWidth: .infinity)
        }
        .buttonStyle(.dispersion(.ghost))
    }

    // MARK: - Score edit

    @ViewBuilder
    private var scoreEditContent: some View {
        DSheetHeader(eyebrow: "Hole \(tracker.currentHole) · Par \(holePar)", title: "Score")

        let score = tracker.scores[tracker.currentHole]?.score ?? 0
        HStack {
            Button { tracker.setScore(hole: tracker.currentHole, score: max(1, score - 1)); Haptics.light() } label: {
                Image(systemName: "minus").font(.system(size: 16, weight: .medium))
                    .frame(width: 44, height: 44).background(Circle().fill(DesignTokens.surface))
            }
            .buttonStyle(.plain)

            VStack(spacing: 2) {
                Text("\(score)")
                    .font(DispersionType.display(56, weight: .regular))
                    .monospacedDigit()
                    .foregroundStyle(score < holePar ? DesignTokens.primary
                                     : score == holePar ? DesignTokens.foreground
                                     : DesignTokens.pPoor)
                if score > 0 {
                    Text(HoleScore(hole: tracker.currentHole, par: holePar, score: score).label)
                        .font(DispersionType.mono(11, weight: .medium))
                        .foregroundStyle(DesignTokens.mutedForeground)
                }
            }
            .frame(width: 100)

            Button { tracker.setScore(hole: tracker.currentHole, score: score + 1); Haptics.light() } label: {
                Image(systemName: "plus").font(.system(size: 16, weight: .medium))
                    .frame(width: 44, height: 44).background(Circle().fill(DesignTokens.surface))
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
                ForEach(1...tracker.holeCount, id: \.self) { h in
                    let hs = tracker.scores[h]
                    let p = gbScorecard.first(where: { $0.holenumber == h && $0.color == teeColor })?.par ?? 4
                    VStack(spacing: 2) {
                        Text("\(h)").font(DispersionType.mono(8)).foregroundStyle(DesignTokens.mutedForeground)
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
}
