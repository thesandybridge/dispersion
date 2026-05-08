// Round history with trend charts — score, GIR%, putts, strokes gained.

import SwiftData
import SwiftUI

struct RoundHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeAccent) private var accent
    var onBack: () -> Void
    var onSelectRound: (String) -> Void

    @State private var rounds: [RoundSummary] = []
    @State private var selectedTab: StatTab = .score

    enum StatTab: String, CaseIterable {
        case score = "Score"
        case gir = "GIR"
        case putts = "Putts"
        case sg = "SG"
    }

    var body: some View {
        ZStack {
            DesignTokens.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack {
                        Button { onBack() } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left").font(.system(size: 12))
                                Text("Back")
                            }
                            .font(DispersionType.mono(12))
                            .foregroundStyle(DesignTokens.mutedForeground)
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }

                    Text("Round History")
                        .font(DispersionType.display(28, weight: .regular))
                        .tracking(-0.5)

                    if rounds.count >= 2 {
                        trendSection
                    }

                    if rounds.isEmpty {
                        VStack(spacing: 8) {
                            Spacer().frame(height: 40)
                            Text("No rounds yet")
                                .font(DispersionType.display(20, weight: .regular))
                            Text("Finish a round on a course to see your history.")
                                .font(DispersionType.ui(13))
                                .foregroundStyle(DesignTokens.mutedForeground)
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        // Averages
                        if rounds.count >= 2 {
                            averagesRow
                        }

                        // Round list
                        VStack(spacing: 8) {
                            ForEach(rounds) { round in
                                roundRow(round)
                            }
                        }
                    }

                    Spacer().frame(height: 80)
                }
                .padding(.horizontal, 20)
            }
        }
                .onAppear { loadRounds() }
    }

    // MARK: - Trends

    private var trendSection: some View {
        VStack(spacing: 8) {
            // Tab selector
            HStack(spacing: 4) {
                ForEach(StatTab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                        Haptics.light()
                    } label: {
                        Text(tab.rawValue)
                            .font(DispersionType.mono(10, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(selectedTab == tab ? accent : DesignTokens.surface))
                            .foregroundStyle(selectedTab == tab ? DesignTokens.primaryForeground : DesignTokens.foreground)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Chart
            Group {
                switch selectedTab {
                case .score:
                    TrendChart(
                        points: rounds.reversed().map { TrendPoint(date: $0.completedAt, value: Double($0.totalScore)) },
                        accent: accent, label: "Score", suffix: ""
                    )
                case .gir:
                    TrendChart(
                        points: rounds.reversed().map { TrendPoint(date: $0.completedAt, value: $0.girPct * 100) },
                        accent: DesignTokens.primary, label: "GIR", suffix: "%"
                    )
                case .putts:
                    TrendChart(
                        points: rounds.reversed().map { TrendPoint(date: $0.completedAt, value: $0.puttsPerHole) },
                        accent: DesignTokens.pMarginal, label: "Putts/hole", suffix: ""
                    )
                case .sg:
                    TrendChart(
                        points: rounds.reversed().map { TrendPoint(date: $0.completedAt, value: $0.sgTotal) },
                        accent: DesignTokens.primary, label: "Strokes Gained", suffix: ""
                    )
                }
            }
            .frame(height: 140)
            .padding(12)
            .background(ThemedCardFill(cornerRadius: 14))
        }
    }

    // MARK: - Averages

    private var averagesRow: some View {
        HStack(spacing: 0) {
            let avgScore = rounds.map(\.totalScore).reduce(0, +) / max(rounds.count, 1)
            let avgGir = rounds.map(\.girPct).reduce(0, +) / Double(max(rounds.count, 1))
            let avgPutts = rounds.map(\.puttsPerHole).reduce(0, +) / Double(max(rounds.count, 1))

            avgCell("Avg Score", value: "\(avgScore)")
            avgCell("GIR", value: "\(Int(avgGir * 100))%")
            avgCell("Putts/hole", value: String(format: "%.1f", avgPutts))
            avgCell("Rounds", value: "\(rounds.count)")
        }
        .padding(.vertical, 12)
        .background(ThemedCardFill(cornerRadius: 12))
    }

    private func avgCell(_ label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(DispersionType.display(18, weight: .regular))
                .monospacedDigit()
            Text(label)
                .font(DispersionType.mono(8, weight: .medium))
                .foregroundStyle(DesignTokens.mutedForeground)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Round row

    private func roundRow(_ round: RoundSummary) -> some View {
        Button { onSelectRound(round.id) } label: {
            HStack(spacing: 12) {
                // Score circle
                ZStack {
                    Circle()
                        .fill(round.toPar < 0 ? DesignTokens.primary.opacity(0.15)
                              : round.toPar == 0 ? DesignTokens.surface
                              : DesignTokens.pPoor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Text("\(round.totalScore)")
                        .font(DispersionType.display(18, weight: .regular))
                        .monospacedDigit()
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(round.courseName)
                        .font(DispersionType.ui(14, weight: .medium))
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        Text(round.toPar == 0 ? "E" : (round.toPar > 0 ? "+\(round.toPar)" : "\(round.toPar)"))
                            .font(DispersionType.mono(11, weight: .medium))
                            .foregroundStyle(round.toPar < 0 ? DesignTokens.primary
                                             : round.toPar == 0 ? DesignTokens.foreground
                                             : DesignTokens.pPoor)
                        Text("\(round.holesPlayed) holes")
                            .font(DispersionType.mono(10))
                            .foregroundStyle(DesignTokens.mutedForeground)
                        if round.sgShotCount > 0 {
                            Text("SG \(String(format: "%+.1f", round.sgTotal))")
                                .font(DispersionType.mono(10))
                                .foregroundStyle(round.sgTotal >= 0 ? DesignTokens.primary : DesignTokens.pPoor)
                        }
                    }
                }
                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(round.completedAt.formatted(.dateTime.month(.abbreviated).day()))
                        .font(DispersionType.mono(10))
                        .foregroundStyle(DesignTokens.mutedForeground)
                    if round.greensTotal > 0 {
                        Text("GIR \(Int(round.girPct * 100))%")
                            .font(DispersionType.mono(9))
                            .foregroundStyle(DesignTokens.mutedForeground)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(ThemedCardFill(cornerRadius: 12))
            .foregroundStyle(DesignTokens.foreground)
        }
        .buttonStyle(.plain)
    }

    private func loadRounds() {
        rounds = (try? CoursesRepo(context: modelContext).rounds()) ?? []
    }
}
