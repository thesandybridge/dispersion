// Shot history — sessions list with per-club sigma cards.

import SwiftData
import SwiftUI

struct ShotLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeAccent) private var accent
    @Query(sort: \ClubModel.carryYards, order: .reverse) private var clubModels: [ClubModel]

    var onOpenSession: (String) -> Void

    @State private var sessions: [Session] = []
    @State private var totalShots: Int = 0
    @State private var last30DayShots: Int = 0
    @State private var clubSummaries: [(Club, ClubShotSummary)] = []

    private var clubs: [Club] { clubModels.map { $0.toValue() } }

    var body: some View {
        List {
            // Stats header
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(totalShots)")
                            .font(DispersionType.display(32, weight: .regular))
                            .monospacedDigit()
                        Text("total shots")
                            .font(DispersionType.mono(10))
                            .foregroundStyle(DesignTokens.mutedForeground)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(last30DayShots)")
                            .font(DispersionType.display(24, weight: .regular))
                            .monospacedDigit()
                            .foregroundStyle(accent)
                        Text("last \(AppConfig.recentActivityDays) days")
                            .font(DispersionType.mono(10))
                            .foregroundStyle(DesignTokens.mutedForeground)
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))

            // Per-club cards
            if !clubSummaries.isEmpty {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(clubSummaries, id: \.0.id) { club, summary in
                                clubCard(club: club, summary: summary)
                            }
                        }
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            }

            // Sessions
            if sessions.isEmpty {
                Section {
                    Text("No sessions yet. Start a Range session or log a shot from the Calculator.")
                        .font(DispersionType.ui(13))
                        .foregroundStyle(DesignTokens.mutedForeground)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            } else {
                Section {
                    ForEach(sessions, id: \.id) { session in
                        Button { onOpenSession(session.id) } label: {
                            sessionRow(session)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { indexSet in
                        for i in indexSet {
                            let s = sessions[i]
                            try? ShotsRepo(context: modelContext).deleteBySession(s.id)
                            try? SessionsRepo(context: modelContext).delete(id: s.id)
                        }
                        Haptics.medium()
                        refreshData()
                    }
                } header: {
                    Text("Sessions")
                        .eyebrow()
                        .textCase(nil)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 16))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .onAppear { refreshData() }
        .onChange(of: clubModels.count) { _, _ in refreshData() }
    }

    private func refreshData() {
        let sessionsRepo = SessionsRepo(context: modelContext)
        let shotsRepo = ShotsRepo(context: modelContext)

        let allSessions = (try? sessionsRepo.list()) ?? []
        sessions = allSessions.filter { s in
            ((try? shotsRepo.listBySession(s.id))?.count ?? 0) > 0
        }

        totalShots = (try? shotsRepo.countAll()) ?? 0
        let cutoff = Calendar.current.date(
            byAdding: .day, value: -AppConfig.recentActivityDays, to: .now
        ) ?? .now
        last30DayShots = (try? shotsRepo.count(since: cutoff)) ?? 0

        clubSummaries = clubs.compactMap { club -> (Club, ClubShotSummary)? in
            let shots = (try? shotsRepo.listByClub(club.id, limit: 200)) ?? []
            guard !shots.isEmpty else { return nil }
            return (club, summarize(shots))
        }
    }

    // MARK: - Club card

    private func clubCard(club: Club, summary: ClubShotSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(club.name)
                    .font(DispersionType.ui(13, weight: .medium))
                Spacer()
                Text("\(summary.totalShots)")
                    .font(DispersionType.mono(10))
                    .foregroundStyle(DesignTokens.mutedForeground)
            }
            if let sd = summary.latestCarrySd {
                HStack {
                    Text("σ \(String(format: "%.1f", sd))")
                        .font(DispersionType.mono(10))
                        .foregroundStyle(DesignTokens.mutedForeground)
                    if let delta = summary.deltaCarrySd {
                        Text("\(delta < 0 ? "↓" : "↑")\(String(format: "%.1f", abs(delta)))")
                            .font(DispersionType.mono(10))
                            .foregroundStyle(delta < 0 ? DesignTokens.primary : DesignTokens.pPoor)
                    }
                }
            }
        }
        .padding(12)
        .frame(minWidth: 130, alignment: .leading)
        .background(ThemedCardFill(cornerRadius: 10))
    }

    // MARK: - Session row

    private func sessionRow(_ session: Session) -> some View {
        let shotCount = (try? ShotsRepo(context: modelContext).listBySession(session.id))?.count ?? 0
        return HStack(spacing: 12) {
            Circle()
                .fill(session.kind == .range ? accent : DesignTokens.pMarginal)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.label)
                    .font(DispersionType.ui(14, weight: .medium))
                HStack(spacing: 6) {
                    Text(formatSessionDate(session.createdAt))
                        .font(DispersionType.mono(10))
                        .foregroundStyle(DesignTokens.mutedForeground)
                    Text("·")
                        .foregroundStyle(DesignTokens.mutedForeground)
                    Text("\(shotCount) shots")
                        .font(DispersionType.mono(10))
                        .foregroundStyle(DesignTokens.mutedForeground)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11))
                .foregroundStyle(DesignTokens.mutedForeground.opacity(0.4))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(ThemedCardFill(cornerRadius: 12))
    }

    // MARK: - Helpers

    private func formatSessionDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Today \(date.formatted(.dateTime.hour().minute()))"
        }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

struct ClubShotSummary {
    var totalShots: Int
    var latestCarrySd: Double?
    var deltaCarrySd: Double?
}

private func summarize(_ shots: [Shot]) -> ClubShotSummary {
    let n = shots.count
    guard n >= 2 else {
        return ClubShotSummary(totalShots: n)
    }
    let points = shots.map { ShotXY(lat: $0.latDelta, long: $0.longDelta) }
    let stats = Sigma.dispersionFromShots(points)
    return ClubShotSummary(totalShots: n, latestCarrySd: stats.carrySd)
}
