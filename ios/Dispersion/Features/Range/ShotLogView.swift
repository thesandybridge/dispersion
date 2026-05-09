// History tab — sessions, per-club performance, and a stats hero.
// Mirrors the Bag screen shape (List + heroCard + sectioned full-width
// rows) so the two surfaces feel like siblings.

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
            // Stats hero — same shape Bag uses.
            Section { heroCard }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

            // Sessions — primary content. Section header uses the same
            // .eyebrow() chrome as Bag's "Putter" / Calculator's section labels.
            if sessions.isEmpty {
                Section { emptyState }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            } else {
                Section {
                    ForEach(sessions, id: \.id) { session in
                        Button { onOpenSession(session.id) } label: {
                            sessionRow(session)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 16))
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
                    sectionHeader("Sessions", count: sessions.count)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            // Per-club performance — full-width rows, same skeleton as Bag's
            // club rows. Was a horizontal scroll, which felt cramped.
            if !clubSummaries.isEmpty {
                Section {
                    ForEach(clubSummaries, id: \.0.id) { club, summary in
                        clubPerformanceRow(club: club, summary: summary)
                            .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 16))
                    }
                } header: {
                    sectionHeader("Per club", count: clubSummaries.count)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            // Bottom padding so the last row clears the tab bar.
            Section { Color.clear.frame(height: 60) }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(DesignTokens.background)
        .onAppear { refreshData() }
        .onChange(of: clubModels.count) { _, _ in refreshData() }
    }

    // MARK: - Hero card

    private var heroCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(totalShots)")
                    .font(DispersionType.display(40, weight: .regular))
                    .monospacedDigit()
                    .foregroundStyle(DesignTokens.foreground)
                Text("total shots")
                    .font(DispersionType.mono(10))
                    .foregroundStyle(DesignTokens.mutedForeground)
            }
            DSeparator(.vertical).frame(height: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(last30DayShots)")
                    .font(DispersionType.mono(13, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(accent)
                Text("last \(AppConfig.recentActivityDays)d")
                    .font(DispersionType.mono(10))
                    .foregroundStyle(DesignTokens.mutedForeground)
            }
            DSeparator(.vertical).frame(height: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(sessions.count)")
                    .font(DispersionType.mono(13, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(DesignTokens.foreground)
                Text("sessions")
                    .font(DispersionType.mono(10))
                    .foregroundStyle(DesignTokens.mutedForeground)
            }
            Spacer()
        }
        .padding(16)
        .background(ThemedCardFill(cornerRadius: 16))
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

    // MARK: - Session row

    private func sessionRow(_ session: Session) -> some View {
        let shotCount = (try? ShotsRepo(context: modelContext).listBySession(session.id))?.count ?? 0
        let kindAccent: Color = session.kind == .range ? accent : DesignTokens.pMarginal
        let kindLabel = session.kind == .range ? "RANGE" : "ROUND"
        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(kindAccent)
                .frame(width: 3, height: 36)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(kindLabel)
                        .font(DispersionType.mono(9, weight: .medium))
                        .tracking(1.4)
                        .foregroundStyle(kindAccent)
                    Text(session.label)
                        .font(DispersionType.ui(15, weight: .medium))
                        .foregroundStyle(DesignTokens.foreground)
                        .lineLimit(1)
                }
                Text("\(formatSessionDate(session.createdAt)) · \(shotCount) shots")
                    .font(DispersionType.mono(10))
                    .foregroundStyle(DesignTokens.mutedForeground)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DesignTokens.mutedForeground.opacity(0.5))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(ThemedCardFill(cornerRadius: 14))
    }

    // MARK: - Per-club row

    /// Vertical full-width row matching Bag's clubRow skeleton — accent strip,
    /// name + sigma sub-line, glyph, count.
    private func clubPerformanceRow(club: Club, summary: ClubShotSummary) -> some View {
        let cat = ClubCategoryRegistry.categorize(name: club.name, carryYards: club.carryYards)
        let style = ClubCategoryRegistry.style(for: cat)
        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(LinearGradient(gradient: style.gradient, startPoint: .top, endPoint: .bottom))
                .frame(width: 3, height: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(club.name)
                    .font(DispersionType.ui(15, weight: .medium))
                    .foregroundStyle(DesignTokens.foreground)
                if let sd = summary.latestCarrySd {
                    HStack(spacing: 6) {
                        Text("σ↕\(String(format: "%.1f", sd))")
                            .font(DispersionType.mono(10))
                            .foregroundStyle(DesignTokens.mutedForeground)
                        if let delta = summary.deltaCarrySd, abs(delta) >= 0.05 {
                            Text("\(delta < 0 ? "↓" : "↑")\(String(format: "%.1f", abs(delta)))")
                                .font(DispersionType.mono(10, weight: .medium))
                                .foregroundStyle(delta < 0 ? DesignTokens.primary : DesignTokens.pPoor)
                        }
                    }
                } else {
                    Text("not enough shots yet")
                        .font(DispersionType.mono(10))
                        .foregroundStyle(DesignTokens.mutedForeground.opacity(0.6))
                }
            }
            Spacer()
            DispersionGlyph(
                carrySd: summary.latestCarrySd ?? club.carrySd,
                lateralSd: club.lateralSd,
                fill: style.accent.opacity(0.3),
                stroke: style.accentDeep
            )
            .frame(width: 28, height: 20)
            Text("\(summary.totalShots)")
                .font(DispersionType.display(22, weight: .regular))
                .monospacedDigit()
                .foregroundStyle(DesignTokens.foreground)
            Text("shots")
                .font(DispersionType.mono(10))
                .foregroundStyle(DesignTokens.mutedForeground)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(ThemedCardFill(cornerRadius: 14))
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "scope")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(DesignTokens.mutedForeground.opacity(0.6))
            Text("No sessions yet")
                .font(DispersionType.display(20, weight: .regular))
                .foregroundStyle(DesignTokens.foreground)
            Text("Start a Range session or log a shot from the Calculator and it'll show up here.")
                .font(DispersionType.ui(13))
                .foregroundStyle(DesignTokens.mutedForeground)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(ThemedCardFill(cornerRadius: 16))
    }

    // MARK: - Data

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
