import MapKit
import SwiftData
import SwiftUI

struct CourseShotReview: View {
    @Environment(\.modelContext) private var context
    @Environment(\.themeAccent) private var accent
    @Query private var clubModels: [ClubModel]
    let sessionId: String
    let courseId: String
    @State private var hole: Int
    @State private var shots: [CourseShot] = []
    @State private var editing: CourseShot?
    @State private var adding = false
    @State private var score = 4
    @State private var putts = 2
    @State private var penalties = 0
    @State private var errorMessage: String?
    @State private var savedMessage: String?
    @State private var deleting: CourseShot?

    init(sessionId: String, courseId: String, initialHole: Int = 1) {
        self.sessionId = sessionId
        self.courseId = courseId
        _hole = State(initialValue: initialHole)
    }

    private var holeShots: [CourseShot] { shots.filter { $0.holeNumber == hole }.sorted { $0.timestamp < $1.timestamp } }
    private var trackedCount: Int { holeShots.filter { !$0.isPenalty }.count }
    private var missingCount: Int { max(0, score - putts - penalties - trackedCount) }
    private var holeRange: ClosedRange<Int> {
        if let round = try? CoursesRepo(context: context).round(id: sessionId) {
            return round.startHole...(round.startHole + round.holeCount - 1)
        }
        let tracker = WatchRoundBridge.shared.tracker(for: courseId)
        return tracker.sessionId == sessionId ? tracker.startHole...tracker.lastHole : 1...18
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Review your round").font(DispersionType.display(28))
                Picker("Hole", selection: $hole) {
                    ForEach(holeRange, id: \.self) { Text("Hole \($0)").tag($0) }
                }.pickerStyle(.menu)
                if !holeShots.filter({ !$0.isPenalty }).isEmpty {
                    Map {
                        ForEach(holeShots.filter { !$0.isPenalty && $0.excludedFromDistances != true }) { shot in
                            MapPolyline(coordinates: [shot.startCoordinate, shot.endCoordinate])
                                .stroke(accent, lineWidth: 3)
                            Annotation("\(shot.shotNumber)", coordinate: shot.endCoordinate) {
                                Text("\(shot.shotNumber)").font(.caption.bold()).padding(6)
                                    .background(accent, in: Circle()).foregroundStyle(.black)
                            }
                        }
                    }
                    .mapStyle(.imagery)
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .id(hole)
                }
                if missingCount > 0 {
                    Label("\(missingCount) possible missing shot\(missingCount == 1 ? "" : "s")", systemImage: "exclamationmark.circle")
                        .foregroundStyle(DesignTokens.pMarginal)
                    Text("Your score, putts and penalties suggest more shots than were tracked. Check the score or add the missing locations.").font(.caption)
                }
                ForEach(holeShots) { shot in
                    Button { editing = shot } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(shot.isPenalty ? "+\(shot.strokeCount) penalty" : "\(clubModels.first { $0.id == shot.clubId }?.name ?? "Shot") · \(distance(shot.distanceYards))")
                                    .font(.headline)
                                if !shot.isPenalty {
                                    Text(shot.excludedFromDistances == true ? "Excluded from distances" : (shot.kind ?? "full").capitalized)
                                        .font(.caption).foregroundStyle(DesignTokens.mutedForeground)
                                    if needsReview(shot) {
                                        Label("Check distance / GPS", systemImage: "exclamationmark.circle").font(.caption)
                                    }
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .foregroundStyle(DesignTokens.foreground)
                        .padding(14).background(ThemedCardFill())
                    }.buttonStyle(.plain)
                    Button("Remove \(shot.isPenalty ? "penalty entry" : "shot")", role: .destructive) { deleting = shot }
                        .font(.caption)
                }
                Button { adding = true } label: { Label("Add missed shot", systemImage: "plus") }
                    .buttonStyle(.dispersion(.secondary))
                VStack(alignment: .leading, spacing: 12) {
                    Text("Hole score").font(.headline)
                    Stepper("Total strokes: \(score)", value: $score, in: 1...30)
                    Stepper("Putts: \(putts)", value: $putts, in: 0...15)
                    Stepper("Penalties: \(penalties)", value: $penalties, in: 0...15)
                    Text("Total strokes includes putts and penalties. Editing shot locations does not change this score.").font(.caption)
                    Button("Save score") { saveScore() }
                        .buttonStyle(.dispersion())
                        .disabled(putts + penalties > score)
                }.padding(16).background(ThemedCardFill())
                if let savedMessage { Text(savedMessage).font(.caption).foregroundStyle(accent) }
                if let errorMessage { Text(errorMessage).foregroundStyle(DesignTokens.destructive) }
            }.padding()
        }
        .onAppear { reload() }
        .onChange(of: hole) { _, _ in reload() }
        .dispersionSheet(isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } }), detents: [.large], scrollable: false) {
            if let shot = editing { CourseShotEditor(shot: shot, isNew: false) { reload() } }
        }
        .dispersionSheet(isPresented: $adding, detents: [.large], scrollable: false) {
            CourseShotEditor(shot: newShot(), isNew: true) { reload() }
        }
        .confirmationDialog("Remove this entry?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Remove", role: .destructive) { remove() }
        } message: { Text("The score stays unchanged. Adjust it below if needed.") }
    }

    private func needsReview(_ shot: CourseShot) -> Bool {
        let carry = clubModels.first { $0.id == shot.clubId }?.carryYards ?? 300
        return shot.accuracy > 20 || shot.distanceYards < 10 || shot.distanceYards > max(100, carry * 1.65)
    }

    private func distance(_ yards: Double) -> String {
        "\(Int(Units.from(yards: yards, in: SettingsStore.shared.unit).rounded())) \(SettingsStore.shared.unit.label)"
    }

    private func reload() {
        do {
            let repo = CoursesRepo(context: context)
            try repo.associateLegacyShots(sessionId: sessionId)
            shots = try repo.shots(sessionId: sessionId)
            let tracker = WatchRoundBridge.shared.tracker(for: courseId)
            let saved = try repo.round(id: sessionId)?.scores.first { $0.hole == hole }
                ?? (tracker.sessionId == sessionId ? tracker.scores[hole] : nil)
            score = max(1, saved?.score ?? trackedCount + 2)
            putts = saved?.putts ?? 2
            penalties = saved?.penaltyStrokes ?? 0
        } catch { errorMessage = error.localizedDescription }
    }

    private func newShot() -> CourseShot {
        let center = (try? CoursesRepo(context: context).get(id: courseId))
        let start = holeShots.last?.endCoordinate ?? CLLocationCoordinate2D(latitude: center?.centerLat ?? 0, longitude: center?.centerLng ?? 0)
        var shot = CourseShot(id: UUID().uuidString.lowercased(), courseId: courseId, holeNumber: hole,
                              shotNumber: holeShots.count + 1, startLat: start.latitude, startLng: start.longitude,
                              endLat: start.latitude, endLng: start.longitude)
        shot.sessionId = sessionId
        shot.kind = "full"
        return shot
    }

    private func remove() {
        guard let shot = deleting else { return }
        do {
            try CoursesRepo(context: context).deleteShot(id: shot.id)
            let tracker = WatchRoundBridge.shared.tracker(for: courseId)
            if tracker.sessionId == sessionId {
                tracker.shots.removeAll { $0.id == shot.id }
                tracker.save()
            }
            deleting = nil
            reload()
        } catch { errorMessage = error.localizedDescription }
    }

    private func saveScore() {
        do {
            try CoursesRepo(context: context).updateHoleScore(sessionId: sessionId, hole: hole, score: score, putts: putts, penalties: penalties)
            let tracker = WatchRoundBridge.shared.tracker(for: courseId)
            if tracker.sessionId == sessionId, tracker.hasSavedRound {
                tracker.scores[hole]?.score = score
                tracker.scores[hole]?.putts = putts
                tracker.scores[hole]?.penaltyStrokes = penalties
                tracker.save()
            }
            savedMessage = "Score saved"
        } catch { errorMessage = error.localizedDescription }
    }
}

struct CourseShotEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var clubs: [ClubModel]
    @State var shot: CourseShot
    var isNew: Bool
    var onSave: () -> Void
    @State private var endpoint = 0
    @State private var startPlaced = false
    @State private var endPlaced = false
    @State private var errorMessage: String?
    @State private var camera: MapCameraPosition = .automatic

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(isNew ? "Add missed shot" : "Correct shot").font(DispersionType.display(28))
                if shot.isPenalty {
                    Text("Penalty entries never contribute to club distances. Change the penalty count in Hole score, or remove an accidental entry.").font(.body)
                    Button("Done") { dismiss() }.buttonStyle(.dispersion())
                } else {
                    Picker("Club", selection: Binding(get: { shot.clubId ?? "" }, set: { shot.clubId = $0 })) {
                        Text("Choose club").tag("")
                        ForEach(clubs) { Text($0.name).tag($0.id) }
                    }
                    Picker("Shot type", selection: Binding(get: { shot.kind ?? "full" }, set: { shot.kind = $0 })) {
                        Text("Full swing").tag("full")
                        Text("Partial").tag("partial")
                        Text("Chip / pitch").tag("chip")
                        Text("Recovery / punch").tag("punch")
                        Text("Bunker").tag("sand")
                    }
                    Picker("Place on map", selection: $endpoint) {
                        Text("Start").tag(0)
                        Text("Finish").tag(1)
                    }.pickerStyle(.segmented)
                    Text("Tap the map to place the \(endpoint == 0 ? "start" : "finish"). Pan and zoom to find your ball locations.")
                        .font(.caption).foregroundStyle(DesignTokens.mutedForeground)
                    MapReader { proxy in
                        Map(position: $camera) {
                            Marker("Start", coordinate: shot.startCoordinate).tint(.blue)
                            Marker("Finish", coordinate: shot.endCoordinate).tint(.green)
                            MapPolyline(coordinates: [shot.startCoordinate, shot.endCoordinate]).stroke(.white, lineWidth: 3)
                        }
                        .mapStyle(.imagery)
                        .gesture(SpatialTapGesture().onEnded { event in
                            guard let coord = proxy.convert(event.location, from: .local) else { return }
                            if endpoint == 0 {
                                shot.startLat = coord.latitude; shot.startLng = coord.longitude
                                startPlaced = true; endpoint = 1
                            } else {
                                shot.endLat = coord.latitude; shot.endLng = coord.longitude
                                endPlaced = true
                            }
                        })
                    }.frame(height: 300).clipShape(RoundedRectangle(cornerRadius: 16))
                    Text("\(Int(Units.from(yards: shot.distanceYards, in: SettingsStore.shared.unit).rounded())) \(SettingsStore.shared.unit.label) total")
                        .font(.headline)
                    Toggle("Exclude from distance averages", isOn: Binding(get: { shot.excludedFromDistances == true }, set: { shot.excludedFromDistances = $0 }))
                    Text("Your score stays unchanged. Review it separately if this was an extra or missing stroke.").font(.caption)
                    Button("Save shot") { save() }.buttonStyle(.dispersion())
                        .disabled((isNew && (!startPlaced || !endPlaced)) || shot.clubId == nil || shot.clubId == "" || shot.distanceYards < 1)
                    if let errorMessage { Text(errorMessage).foregroundStyle(DesignTokens.destructive) }
                }
            }.padding()
        }
        .onAppear {
            camera = .region(MKCoordinateRegion(center: shot.startCoordinate, latitudinalMeters: 450, longitudinalMeters: 450))
        }
    }

    private func save() {
        do {
            let repo = CoursesRepo(context: context)
            if startPlaced || endPlaced { shot.accuracy = 0 }
            if isNew { try repo.createShot(shot) } else { try repo.updateShot(shot) }
            let tracker = WatchRoundBridge.shared.tracker(for: shot.courseId)
            if tracker.sessionId == shot.sessionId, tracker.hasSavedRound {
                if isNew { tracker.shots.append(shot); tracker.save() }
                else { tracker.replaceCourseShot(shot) }
            }
            onSave()
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}

private extension CourseShot {
    var startCoordinate: CLLocationCoordinate2D { .init(latitude: startLat, longitude: startLng) }
    var endCoordinate: CLLocationCoordinate2D { .init(latitude: endLat, longitude: endLng) }
}
