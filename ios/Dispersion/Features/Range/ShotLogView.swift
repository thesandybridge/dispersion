// Port of app/src/components/range/ShotLogContent.tsx. Lists sessions with
// per-club sigma cards, tapping a session opens SessionDetailView.

import SwiftData
import SwiftUI

struct ShotLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClubModel.carryYards, order: .reverse) private var clubModels: [ClubModel]

    var onOpenSession: (String) -> Void

    private var clubs: [Club] { clubModels.map { $0.toValue() } }

    private var sessions: [Session] {
        (try? SessionsRepo(context: modelContext).list()) ?? []
    }

    private var totalShots: Int {
        (try? ShotsRepo(context: modelContext).countAll()) ?? 0
    }

    private var last30DayShots: Int {
        let since = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
        return (try? ShotsRepo(context: modelContext).count(since: since)) ?? 0
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                clubCards
                sessionsSection
            }
        }
    }

    // MARK: header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(totalShots) shot\(totalShots == 1 ? "" : "s")")
                    .font(DispersionType.display(28, weight: .regular))
                    .tracking(-0.56)
                Spacer()
                Text("\(last30DayShots) last 30d")
                    .font(DispersionType.mono(12))
                    .foregroundStyle(DesignTokens.mutedForeground)
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 12)

            DSeparator()
        }
    }

    // MARK: per-club cards

    @ViewBuilder
    private var clubCards: some View {
        let summaries = clubs.compactMap { club -> (Club, ClubShotSummary)? in
            let shots = (try? ShotsRepo(context: modelContext).listByClub(club.id, limit: 200)) ?? []
            guard !shots.isEmpty else { return nil }
            return (club, summarize(shots))
        }
        if !summaries.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Per club")
                    .eyebrow()
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(summaries, id: \.0.id) { club, summary in
                            clubCard(club: club, summary: summary)
                        }
                    }
                    .padding(.horizontal, 18)
                }
            }
        }
    }

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
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(DesignTokens.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(DesignTokens.border, lineWidth: 1)
                )
        )
    }

    // MARK: sessions list

    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Sessions")
                .eyebrow()
                .padding(.horizontal, 18)
                .padding(.top, 20)
                .padding(.bottom, 8)

            if sessions.isEmpty {
                Text("No sessions yet. Start a Range session or log a shot from the Calculator to begin.")
                    .font(DispersionType.ui(13))
                    .foregroundStyle(DesignTokens.mutedForeground)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 40)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(sessions, id: \.id) { session in
                    Button { onOpenSession(session.id) } label: {
                        sessionRow(session)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func sessionRow(_ session: Session) -> some View {
        let accent = session.kind == .range ? DesignTokens.primary : DesignTokens.pMarginal
        return HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 2)
                .fill(accent)
                .frame(width: 4, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.label)
                    .font(DispersionType.ui(13, weight: .medium))
                Text("\(formatSessionDate(session.createdAt)) · \(session.kind.rawValue)")
                    .font(DispersionType.mono(11))
                    .foregroundStyle(DesignTokens.mutedForeground)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(DesignTokens.mutedForeground.opacity(0.6))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .overlay(alignment: .top) {
            DSeparator()
        }
    }

    // MARK: helpers

    private func formatSessionDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            return "Today · \(date.formatted(.dateTime.hour().minute()))"
        }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

// MARK: - Shot summary helpers

struct ClubShotSummary {
    var totalShots: Int
    var latestCarrySd: Double?
    var deltaCarrySd: Double?
}

private func summarize(_ shots: [Shot]) -> ClubShotSummary {
    let n = shots.count
    guard n >= 2 else {
        return ClubShotSummary(totalShots: n, latestCarrySd: nil, deltaCarrySd: nil)
    }
    let points = shots.map { ShotXY(lat: $0.latDelta, long: $0.longDelta) }
    let stats = Sigma.dispersionFromShots(points)
    return ClubShotSummary(
        totalShots: n,
        latestCarrySd: stats.carrySd,
        deltaCarrySd: nil
    )
}
