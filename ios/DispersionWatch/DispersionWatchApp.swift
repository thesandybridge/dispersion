import SwiftUI

@main
struct DispersionWatchApp: App {
    @StateObject private var store = WatchGolfStore()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            WatchRoundView(store: store)
                .tint(Color(red: 0.55, green: 0.79, blue: 0.60))
                .onChange(of: phase, initial: true) { _, phase in
                    store.setActive(phase == .active)
                }
        }
    }
}

struct WatchRoundView: View {
    @ObservedObject var store: WatchGolfStore
    @State private var choosingClub = false
    @State private var cancelConfirmation = false
    @State private var scoring = false
    @State private var scoringRound: WatchRound?
    @State private var changingMarkedClub = false
    @State private var penaltySheet = false
    @State private var correctingCompletedClub = false
    @State private var deleteLastConfirmation = false
    @AppStorage("watch.reminders") private var reminders = false
    @AppStorage("watch.swingPrompts") private var swingPrompts = false
    @State private var score = 4
    @State private var putts = 2
    @State private var penalties = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    if let round = store.round {
                        TimelineView(.periodic(from: .now, by: 1)) { _ in
                            HStack(alignment: .firstTextBaseline, spacing: 5) {
                                Text(store.targetYards.map { String(Int(($0 * (round.usesMeters ? 0.9144 : 1)).rounded())) } ?? "—")
                                    .font(.system(size: 40, weight: .medium, design: .rounded))
                                    .monospacedDigit()
                                Text(round.target == nil ? "Set a pin on iPhone" : "\(round.usesMeters ? "m" : "yd") to pin")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        Button {
                            changingMarkedClub = false
                            correctingCompletedClub = false
                            choosingClub = true
                        } label: {
                            HStack(spacing: 6) {
                                Text(store.selectedClub?.name ?? "Choose club")
                                    .font(.headline)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(WatchControlStyle.accent)
                            }
                        }
                        .buttonStyle(WatchControlStyle())
                        .accessibilityHint("Choose the club for your next shot")
                        .disabled(round.clubs.isEmpty || store.acquiringGPS)

                        Button(action: store.markShot) {
                            Label(store.acquiringGPS ? "Finding GPS…" : "Mark shot", systemImage: store.acquiringGPS ? "location.magnifyingglass" : "plus")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(WatchControlStyle(primary: true))
                        .disabled(store.selectedClub == nil || !store.pendingMatchesHole || store.acquiringGPS || store.queue.holeFinish != nil)
                        if let distances = store.greenYardages {
                            HStack {
                                greenNumber("Front", yards: distances.front)
                                greenNumber("Middle", yards: distances.middle)
                                greenNumber("Back", yards: distances.back)
                            }
                            Text("Approx. mapped green edges").font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                        if let shot = store.lastShot {
                            VStack(spacing: 5) {
                                Text("LAST SHOT").font(.caption2).foregroundStyle(.secondary)
                                Text("\(round.clubs.first { $0.id == shot.start.clubId }?.name ?? "Shot") · \(shot.excludedFromDistances == true ? "unmeasured" : distanceLabel(shot.start.point.yards(to: shot.end)))")
                                    .font(.headline)
                                Button("Correct last shot") {
                                    correctingCompletedClub = true
                                    changingMarkedClub = false
                                    choosingClub = true
                                }.buttonStyle(WatchControlStyle())
                                Button("Undo last shot") { deleteLastConfirmation = true }
                                    .buttonStyle(WatchControlStyle())
                            }.padding(.vertical, 6)
                        }
                        Button { penaltySheet = true } label: {
                            Label("Penalty\(store.penaltyCount > 0 ? " · \(store.penaltyCount)" : "")", systemImage: "plus.circle")
                        }
                        .buttonStyle(WatchControlStyle())
                        .disabled(store.acquiringGPS || store.queue.holeFinish != nil || !store.pendingMatchesHole)
                        if store.swingPrompt {
                            Text("Swing detected? At your ball, tap Mark shot to confirm.").font(.caption2)
                            Button("Dismiss") { store.swingPrompt = false }.buttonStyle(WatchControlStyle())
                        }
                        if store.acquiringGPS {
                            Button("Cancel GPS request", action: store.cancelCapture).font(.caption2)
                        }
                        if let pending = store.queue.pending {
                            Text("\(round.clubs.first { $0.id == pending.clubId }?.name ?? "Shot") marked · hole \(pending.hole)")
                                .font(.caption2).foregroundStyle(.secondary)
                            if store.pendingMatchesHole {
                                Button { store.reachedGreen() } label: {
                                    Label("Reached green", systemImage: "flag.fill")
                                }
                                    .buttonStyle(WatchControlStyle())
                                    .disabled(store.acquiringGPS)
                                Button("Change marked club") {
                                    changingMarkedClub = true
                                    correctingCompletedClub = false
                                    choosingClub = true
                                }.buttonStyle(WatchControlStyle())
                            } else {
                                Text("An unfinished mark belongs to another hole. Return to that hole on iPhone or cancel the mark.")
                                    .font(.caption2)
                            }
                        }
                        if store.queue.pending == nil && store.queue.holeFinish == nil {
                            Button(round.hole == round.lastHole ? "Finish round" : "Finish hole") {
                                scoringRound = round
                                score = store.suggestedScore
                                putts = round.putts ?? 2
                                penalties = store.penaltyCount
                                scoring = true
                            }
                            .buttonStyle(WatchControlStyle())
                        }
                        if store.queue.holeFinish != nil {
                            ProgressView("Syncing hole…").font(.caption2)
                            Text("Keep your iPhone nearby. The next hole appears after saving.")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    } else {
                        Image(systemName: "flag.circle").font(.largeTitle)
                        Text("Ready for a round").font(.headline)
                        Text("Start or resume a round in Course on your iPhone.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    if store.round != nil {
                        Toggle("Shot reminders", isOn: $reminders).font(.caption2)
                        Toggle("Swing prompts (beta)", isOn: $swingPrompts).font(.caption2)
                            .onChange(of: swingPrompts) { _, _ in store.refreshMotion() }
                        Text("Prompts run while this app is open. Swings always need confirmation.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    if let message = store.message {
                        Text(message).font(.caption2)
                    }
                    if !store.queue.shots.isEmpty || !(store.queue.edits ?? []).isEmpty || store.queue.holeFinish != nil {
                        Button("Sync saved changes", action: store.sync)
                            .font(.caption2)
                        Text("Keep the round open on iPhone until all shots sync.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    if store.queue.pending != nil {
                        Button("Cancel unfinished mark", role: .destructive) { cancelConfirmation = true }
                            .font(.caption2)
                    }
                }
                .padding(.horizontal, 4)
            }
            .navigationTitle(store.round.map { "Hole \($0.hole) · Par \($0.par)" } ?? "Dispersion")
            .sheet(isPresented: $choosingClub) {
                NavigationStack {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 6) {
                                Text(correctingCompletedClub ? "Correct your last shot" : changingMarkedClub ? "Correct your last mark" : "Choose your next club")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .padding(.bottom, 4)
                                ForEach(store.round?.clubs ?? []) { club in
                                    Button {
                                        if correctingCompletedClub { store.correctLastShot(club: club) }
                                        else if changingMarkedClub { store.changeMarkedClub(to: club) }
                                        else { store.selectedClubId = club.id }
                                        choosingClub = false
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(club.name).font(.headline)
                                                Text(carryLabel(club) + " carry")
                                                    .font(.caption2).foregroundStyle(.secondary)
                                            }
                                            Spacer(minLength: 4)
                                            if club.id == pickerClubId {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(WatchControlStyle.accent)
                                            }
                                        }
                                    }
                                    .buttonStyle(WatchControlStyle(selected: club.id == pickerClubId))
                                    .accessibilityAddTraits(club.id == pickerClubId ? .isSelected : [])
                                    .id(club.id)
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                        .onAppear {
                            if let pickerClubId { proxy.scrollTo(pickerClubId, anchor: .center) }
                        }
                    }
                    .navigationTitle("Clubs")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { choosingClub = false }
                        }
                    }
                }
            }
            .sheet(isPresented: $penaltySheet) {
                ScrollView {
                    VStack(spacing: 10) {
                        Text("Add penalty").font(.headline)
                        Text("Choose the strokes to add. These count toward your score, never your distance averages.")
                            .font(.caption2).foregroundStyle(.secondary)
                        ForEach(1...2, id: \.self) { count in
                            Button("+\(count) stroke\(count == 1 ? "" : "s")") {
                                store.addPenalty(strokes: count, endPending: false)
                                penaltySheet = false
                            }.buttonStyle(WatchControlStyle())
                        }
                        if store.queue.pending != nil {
                            Text("Lost ball or taking a drop? End the mark so your walk is not measured as a shot.")
                                .font(.caption2).foregroundStyle(.secondary)
                            ForEach(1...2, id: \.self) { count in
                                Button("End mark + \(count) penalty") {
                                    store.addPenalty(strokes: count, endPending: true)
                                    penaltySheet = false
                                }.buttonStyle(WatchControlStyle())
                            }
                        }
                    }
                }
            }
            .confirmationDialog("Remove the last completed shot?", isPresented: $deleteLastConfirmation) {
                Button("Remove shot", role: .destructive) { store.correctLastShot(delete: true) }
            } message: {
                Text("Your current unfinished mark stays. You can add a missing shot on iPhone.")
            }
            .sheet(isPresented: $scoring) {
                ScrollView {
                    VStack(spacing: 12) {
                        Text("Hole \(scoringRound?.hole ?? 1)").font(.headline)
                        scoreControl("Strokes", value: $score, range: 1...30)
                        Text("Includes putts and penalties").font(.caption2).foregroundStyle(.secondary)
                        scoreControl("Putts", value: $putts, range: 0...15)
                            .onChange(of: putts) { old, new in score = min(30, max(1, score + new - old)) }
                        scoreControl("Penalties", value: $penalties, range: 0...15)
                            .onChange(of: penalties) { old, new in score = min(30, max(1, score + new - old)) }
                        if putts + penalties > score {
                            Text("Strokes must include putts and penalties.").font(.caption2)
                        }
                        Button("Save hole") {
                            if let scoringRound {
                                store.finishHole(for: scoringRound, score: score, putts: putts, penalties: penalties)
                            }
                            scoring = false
                        }
                        .buttonStyle(WatchControlStyle(primary: true))
                        .disabled(putts + penalties > score)
                    }
                }
            }
            .confirmationDialog("Cancel this unfinished shot?", isPresented: $cancelConfirmation) {
                Button("Cancel mark", role: .destructive, action: store.cancelMark)
            } message: {
                Text("Completed shots stay saved.")
            }
        }
    }

    private func distanceLabel(_ yards: Double) -> String {
        let meters = store.round?.usesMeters == true
        return "\(Int((yards * (meters ? 0.9144 : 1)).rounded())) \(meters ? "m" : "yd")"
    }

    private func greenNumber(_ label: String, yards: Double) -> some View {
        VStack(spacing: 3) {
            Text(label).font(.system(size: 10)).foregroundStyle(.secondary)
            Text(distanceLabel(yards)).font(.caption.weight(.semibold)).monospacedDigit()
        }.frame(maxWidth: .infinity)
    }

    private var pickerClubId: String? {
        correctingCompletedClub ? store.lastShot?.start.clubId : changingMarkedClub ? store.queue.pending?.clubId : store.selectedClub?.id
    }

    private func carryLabel(_ club: WatchClub) -> String {
        let meters = store.round?.usesMeters == true
        return "\(Int((club.carryYards * (meters ? 0.9144 : 1)).rounded())) \(meters ? "m" : "yd")"
    }

    private func scoreControl(_ title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        VStack(spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack {
                Button { value.wrappedValue -= 1 } label: {
                    Image(systemName: "minus").frame(maxWidth: .infinity)
                }
                .buttonStyle(WatchControlStyle())
                .disabled(value.wrappedValue <= range.lowerBound)
                .accessibilityLabel("Decrease \(title.lowercased())")
                Text("\(value.wrappedValue)")
                    .font(.title2.weight(.semibold)).monospacedDigit()
                    .frame(minWidth: 32)
                    .accessibilityLabel("\(title): \(value.wrappedValue)")
                Button { value.wrappedValue += 1 } label: {
                    Image(systemName: "plus").frame(maxWidth: .infinity)
                }
                .buttonStyle(WatchControlStyle())
                .disabled(value.wrappedValue >= range.upperBound)
                .accessibilityLabel("Increase \(title.lowercased())")
            }
        }
    }

}


private struct WatchControlStyle: ButtonStyle {
    static let accent = Color(red: 0.72, green: 0.88, blue: 0.55)
    @Environment(\.isEnabled) private var isEnabled
    var primary = false
    var selected = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(primary ? Color.black : Color.white)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(primary ? Self.accent : Color.white.opacity(selected ? 0.15 : 0.09), in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(selected ? Self.accent.opacity(0.65) : .clear, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 16))
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}
