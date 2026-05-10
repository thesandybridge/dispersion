// Session detail — mirrors ClubDetailView's shape (back link + ghost
// destructive action, stats card with accent strip, sectioned list of
// individual shots). Sits inside a NavigationStack with a hidden nav
// bar so the inline header is the only chrome.

import SwiftData
import SwiftUI

struct SessionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeAccent) private var accent
    @Query(sort: \ClubModel.carryYards, order: .reverse) private var clubModels: [ClubModel]
    @State private var settings = SettingsStore.shared

    var sessionId: String
    var onBack: () -> Void

    @State private var deleteSessionConfirm = false
    @State private var pendingShotDelete: String?

    @State private var session: Session?
    @State private var shots: [Shot] = []
    @State private var putts: [Putt] = []
    @State private var insights: [SessionClubInsight] = []

    private var clubMap: [String: Club] {
        Dictionary(uniqueKeysWithValues: clubModels.map { ($0.id, $0.toValue()) })
    }

    private var isPuttSession: Bool { session?.kind == .putt }

    private var kindAccent: Color {
        switch session?.kind {
        case .range: return accent
        case .round: return DesignTokens.pMarginal
        case .putt:  return DesignTokens.heat4
        case .none:  return accent
        }
    }

    private var puttsAggregate: PutterStats {
        PutterStatsEngine.compute(putts)
    }

    private var aggregateStats: DispersionStats {
        Sigma.dispersionFromShots(shots.map { ShotXY(lat: $0.latDelta, long: $0.longDelta) })
    }

    private var uniqueClubCount: Int {
        Set(shots.map(\.clubId)).count
    }

    var body: some View {
        List {
            Section { header }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

            Section { sessionStatsCard }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

            if !isPuttSession && !insights.isEmpty {
                Section { SessionInsightsCard(insights: insights, unit: settings.unit) }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }

            if isPuttSession {
                if putts.isEmpty {
                    Section { puttEmptyState }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                } else {
                    Section {
                        ForEach(putts, id: \.id) { putt in
                            puttRow(putt)
                                .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 16))
                        }
                        .onDelete { indexSet in
                            for i in indexSet {
                                try? PuttsRepo(context: modelContext).delete(id: putts[i].id)
                            }
                            Haptics.medium()
                            loadSession()
                        }
                    } header: {
                        sectionHeader("Putts", count: putts.count)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            } else if shots.isEmpty {
                Section { emptyState }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            } else {
                Section {
                    ForEach(shots, id: \.id) { shot in
                        shotRow(shot)
                            .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 16))
                    }
                    .onDelete { indexSet in
                        for i in indexSet {
                            try? ShotsRepo(context: modelContext).delete(id: shots[i].id)
                        }
                        Haptics.medium()
                        loadSession()
                    }
                } header: {
                    sectionHeader("Shots", count: shots.count)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section { Color.clear.frame(height: 60) }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(DesignTokens.background)
        .onAppear { loadSession() }
        .onChange(of: sessionId) { _, _ in loadSession() }
        .alert("Delete \(session?.label ?? "this session")?", isPresented: $deleteSessionConfirm) {
            Button("Delete session", role: .destructive) { deleteSession() }
            Button("Cancel", role: .cancel) {}
        } message: {
            if isPuttSession {
                Text("Removes the session and all \(putts.count) of its putts.")
            } else {
                Text("Removes the session and all \(shots.count) of its shots.")
            }
        }
        .alert("Delete this shot?", isPresented: Binding(
            get: { pendingShotDelete != nil },
            set: { if !$0 { pendingShotDelete = nil } }
        )) {
            Button("Delete", role: .destructive) { confirmDeleteShot() }
            Button("Cancel", role: .cancel) { pendingShotDelete = nil }
        } message: {
            Text("The σ values for this club will recalculate without it.")
        }
    }

    // MARK: - Header

    /// Inline header — ClubDetailView pattern: muted "← Back" link on the
    /// left, action pill on the right.
    private var header: some View {
        HStack {
            Button { onBack() } label: {
                Text("← Back")
                    .font(DispersionType.mono(12))
                    .tracking(1.6)
                    .textCase(.uppercase)
                    .foregroundStyle(DesignTokens.foreground.opacity(0.6))
            }
            .buttonStyle(.plain)
            Spacer()
            Button { deleteSessionConfirm = true } label: {
                HStack(spacing: 4) {
                    Image(systemName: "trash").font(.system(size: 11))
                    Text("Delete").font(DispersionType.ui(12, weight: .medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(DesignTokens.destructive.opacity(0.14)))
                .overlay(Capsule().strokeBorder(DesignTokens.destructive.opacity(0.4), lineWidth: 1))
                .foregroundStyle(DesignTokens.destructive)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }

    // MARK: - Session stats card

    /// Mirrors ClubDetailView.statsCard — accent strip + label + statCol grid.
    /// Putt sessions get a putter-flavored stat grid (putts / make % / avg lag);
    /// shot sessions keep the σ-driven layout.
    private var sessionStatsCard: some View {
        let kindLabel: String
        switch session?.kind {
        case .range: kindLabel = "RANGE"
        case .round: kindLabel = "ROUND"
        case .putt:  kindLabel = "PUTT"
        case .none:  kindLabel = "SESSION"
        }
        let lastEnd: Date? = isPuttSession ? putts.last?.timestamp : shots.last?.timestamp
        let durationStr = formatDuration(from: session?.createdAt, until: lastEnd)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(kindAccent)
                    .frame(width: 4, height: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(session?.label ?? "Session")
                        .font(DispersionType.display(24, weight: .regular))
                        .foregroundStyle(DesignTokens.foreground)
                    Text(kindLabel)
                        .font(DispersionType.mono(9, weight: .medium))
                        .tracking(1.5)
                        .foregroundStyle(kindAccent)
                }
                Spacer()
            }

            HStack(spacing: 0) {
                if isPuttSession {
                    statCol("Putts", "\(puttsAggregate.totalPutts)")
                    Spacer()
                    statCol("Make %", "\(Int((puttsAggregate.overallMakePct * 100).rounded()))%")
                    Spacer()
                    if let avg = puttsAggregate.avgLagProximity {
                        statCol("Avg lag", String(format: "%.1f ft", avg))
                        Spacer()
                    }
                    if !durationStr.isEmpty {
                        statCol("Time", durationStr)
                    }
                } else {
                    statCol("Shots", "\(shots.count)")
                    Spacer()
                    if shots.count >= 2 {
                        statCol("σ↕", String(format: "%.1f", aggregateStats.carrySd))
                        Spacer()
                        statCol("σ↔", String(format: "%.1f", aggregateStats.lateralSd))
                        Spacer()
                    }
                    statCol("Clubs", "\(uniqueClubCount)")
                    if !durationStr.isEmpty {
                        Spacer()
                        statCol("Time", durationStr)
                    }
                }
            }

            Text(formatStarted(session?.createdAt ?? .now))
                .font(DispersionType.mono(10))
                .foregroundStyle(DesignTokens.mutedForeground.opacity(0.7))
        }
        .padding(16)
        .background(ThemedCardFill(cornerRadius: 16))
    }

    private func statCol(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(DispersionType.mono(9, weight: .medium))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(DesignTokens.foreground.opacity(0.45))
            Text(value)
                .font(DispersionType.display(18, weight: .regular))
                .foregroundStyle(DesignTokens.foreground)
                .monospacedDigit()
        }
    }

    // MARK: - Section header

    private func sectionHeader(_ label: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Text(label).eyebrow()
            Text("\(count)")
                .font(DispersionType.mono(10, weight: .medium))
                .foregroundStyle(DesignTokens.mutedForeground)
            Spacer()
        }
        .textCase(nil)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    // MARK: - Shot row

    private func shotRow(_ shot: Shot) -> some View {
        let club = clubMap[shot.clubId]
        let cat = club.map { ClubCategoryRegistry.categorize(name: $0.name, carryYards: $0.carryYards) }
        let style = cat.map { ClubCategoryRegistry.style(for: $0) }
        let hasLanding = !(shot.longDelta == 0 && shot.latDelta == 0)

        return HStack(spacing: 12) {
            // Accent strip per club category, faded if club deleted.
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    style.map {
                        AnyShapeStyle(LinearGradient(gradient: $0.gradient, startPoint: .top, endPoint: .bottom))
                    } ?? AnyShapeStyle(DesignTokens.mutedForeground.opacity(0.4))
                )
                .frame(width: 3, height: 36)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(club?.name ?? "(deleted)")
                        .font(DispersionType.ui(14, weight: .medium))
                        .foregroundStyle(DesignTokens.foreground)
                    Text("\(Int(shot.targetDistanceYards))y")
                        .font(DispersionType.mono(10))
                        .foregroundStyle(DesignTokens.mutedForeground)
                    Spacer(minLength: 4)
                    Text(formatTime(shot.timestamp))
                        .font(DispersionType.mono(10))
                        .foregroundStyle(DesignTokens.mutedForeground)
                }

                if hasLanding {
                    let longSign = shot.longDelta >= 0 ? "+" : ""
                    let side = shot.latDelta >= 0 ? "R" : "L"
                    Text("\(longSign)\(Int(shot.longDelta)) long · \(side)\(Int(abs(shot.latDelta)))")
                        .font(DispersionType.mono(11))
                        .foregroundStyle(DesignTokens.mutedForeground)
                }

                if !shot.outcomes.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(shot.outcomes.map(\.rawValue).sorted(), id: \.self) { tag in
                            Text(tag.uppercased())
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .tracking(1)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(tagColor(tag).opacity(0.18)))
                                .foregroundStyle(tagColor(tag))
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(ThemedCardFill(cornerRadius: 14))
    }

    // MARK: - Putt row

    private func puttRow(_ putt: Putt) -> some View {
        let stripeColor: Color = putt.made ? kindAccent : DesignTokens.mutedForeground.opacity(0.45)
        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(stripeColor)
                .frame(width: 3, height: 36)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(putt.made ? "MADE" : "MISSED")
                        .font(DispersionType.mono(9, weight: .medium))
                        .tracking(1.4)
                        .foregroundStyle(stripeColor)
                    Text("\(formatDistance(putt.distanceFeet))")
                        .font(DispersionType.ui(14, weight: .medium))
                        .foregroundStyle(DesignTokens.foreground)
                    Spacer(minLength: 4)
                    Text(formatTime(putt.timestamp))
                        .font(DispersionType.mono(10))
                        .foregroundStyle(DesignTokens.mutedForeground)
                }

                if !putt.made, let r = putt.residualFeet {
                    Text("left \(String(format: "%.1f", r)) ft from cup")
                        .font(DispersionType.mono(11))
                        .foregroundStyle(DesignTokens.mutedForeground)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(ThemedCardFill(cornerRadius: 14))
    }

    // MARK: - Empty states

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "scope")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(DesignTokens.mutedForeground.opacity(0.6))
            Text("No shots in this session")
                .font(DispersionType.ui(15, weight: .medium))
                .foregroundStyle(DesignTokens.foreground)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(ThemedCardFill(cornerRadius: 16))
    }

    private var puttEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "scope")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(DesignTokens.mutedForeground.opacity(0.6))
            Text("No putts in this session")
                .font(DispersionType.ui(15, weight: .medium))
                .foregroundStyle(DesignTokens.foreground)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(ThemedCardFill(cornerRadius: 16))
    }

    private func formatDistance(_ feet: Double) -> String {
        if feet < 10 { return String(format: "%.1f ft", feet) }
        return "\(Int(feet)) ft"
    }

    // MARK: - Actions

    private func deleteSession() {
        // Cascade both shots and putts so any session kind cleans up fully.
        try? ShotsRepo(context: modelContext).deleteBySession(sessionId)
        let puttsRepo = PuttsRepo(context: modelContext)
        let sessionPutts = (try? puttsRepo.listBySession(sessionId)) ?? []
        for p in sessionPutts {
            try? puttsRepo.delete(id: p.id)
        }
        try? SessionsRepo(context: modelContext).delete(id: sessionId)
        onBack()
    }

    private func confirmDeleteShot() {
        guard let id = pendingShotDelete else { return }
        try? ShotsRepo(context: modelContext).delete(id: id)
        pendingShotDelete = nil
        loadSession()
    }

    private func loadSession() {
        let sessionsRepo = SessionsRepo(context: modelContext)
        let shotsRepo = ShotsRepo(context: modelContext)
        let puttsRepo = PuttsRepo(context: modelContext)
        session = try? sessionsRepo.get(id: sessionId)

        let raw = (try? shotsRepo.listBySession(sessionId)) ?? []
        shots = raw.reversed()

        let rawPutts = (try? puttsRepo.listBySession(sessionId)) ?? []
        // listBySession returns ascending by timestamp; show newest at the top.
        putts = rawPutts.reversed()

        let allSessions = (try? sessionsRepo.list()) ?? []
        let priorSessions = allSessions
            .filter { $0.kind == session?.kind && $0.id != sessionId }
            .filter { ($0.createdAt) < (session?.createdAt ?? .now) }
            .sorted { $0.createdAt > $1.createdAt }
        var priorByClub: [String: [Shot]] = [:]
        let clubsInThisSession = Set(raw.map(\.clubId))
        for prior in priorSessions {
            let priorShots = (try? shotsRepo.listBySession(prior.id)) ?? []
            for s in priorShots where clubsInThisSession.contains(s.clubId) {
                if priorByClub[s.clubId]?.isEmpty ?? true {
                    priorByClub[s.clubId, default: []].append(contentsOf: priorShots.filter { $0.clubId == s.clubId })
                }
            }
            if clubsInThisSession.allSatisfy({ priorByClub[$0] != nil }) { break }
        }

        let clubsById = Dictionary(uniqueKeysWithValues: clubModels.map { ($0.id, $0.toValue()) })
        insights = SessionInsightsEngine.compute(
            sessionShots: raw,
            clubsById: clubsById,
            priorShotsByClub: priorByClub
        )
    }

    // MARK: - Formatting

    private func formatStarted(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }

    private func formatTime(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
    }

    private func formatDuration(from start: Date?, until end: Date?) -> String {
        guard let start, let end, end > start else { return "" }
        let mins = Int(end.timeIntervalSince(start) / 60)
        if mins < 1 { return "" }
        if mins < 60 { return "\(mins)m" }
        let h = mins / 60
        let m = mins % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    private func tagColor(_ tag: String) -> Color {
        switch tag {
        case "in":      return DesignTokens.primary
        case "penalty": return DesignTokens.destructive
        case "left", "right": return DesignTokens.destructive
        default:        return DesignTokens.pMarginal
        }
    }
}
