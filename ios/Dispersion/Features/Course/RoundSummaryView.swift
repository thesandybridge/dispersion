// Post-round summary — score, front/back split, FIR/GIR/putts stats,
// strokes gained, best/worst holes.

import SwiftData
import SwiftUI

struct RoundSummaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeAccent) private var accent

    @State private var reviewOpen = false
    @Query private var recordedShots: [CourseShotModel]
    private var courseShots: [CourseShot] { recordedShots.filter { $0.sessionId == sessionId }.map { $0.toValue() } }

    var sessionId: String
    var courseName: String
    var onBack: () -> Void

    private var scores: [HoleScore] {
        // Try SwiftData first, fall back to UserDefaults for old rounds
        if let round = try? CoursesRepo(context: modelContext).round(id: sessionId),
           !round.scores.isEmpty {
            return round.scores.sorted { $0.hole < $1.hole }
        }
        guard let data = UserDefaults.standard.data(forKey: "roundScores.\(sessionId)"),
              let decoded = try? JSONDecoder().decode([HoleScore].self, from: data)
        else { return [] }
        return decoded.sorted { $0.hole < $1.hole }
    }

    private var shots: [Shot] {
        let raw = (try? ShotsRepo(context: modelContext).listBySession(sessionId)) ?? []
        return AppConfig.validShots(raw)
    }

    private var played: [HoleScore] { scores.filter { $0.score > 0 } }
    private var front9: [HoleScore] { played.filter { $0.hole <= 9 } }
    private var back9: [HoleScore] { played.filter { $0.hole > 9 } }

    private var totalScore: Int { played.reduce(0) { $0 + $1.score } }
    private var totalPar: Int { played.reduce(0) { $0 + $1.par } }
    private var toPar: Int { totalScore - totalPar }
    private var front9Score: Int { front9.reduce(0) { $0 + $1.score } }
    private var back9Score: Int { back9.reduce(0) { $0 + $1.score } }

    private var firPct: Double {
        let eligible = played.filter { $0.par >= 4 && $0.fairwayHit != nil }
        guard !eligible.isEmpty else { return 0 }
        return Double(eligible.filter { $0.fairwayHit == true }.count) / Double(eligible.count)
    }
    private var girPct: Double {
        let known = played.filter { $0.girHit != nil }
        guard !known.isEmpty else { return 0 }
        return Double(known.filter { $0.girHit == true }.count) / Double(known.count)
    }
    private var totalPutts: Int { played.compactMap(\.putts).reduce(0, +) }
    private var puttsPerHole: Double {
        let withPutts = played.filter { $0.putts != nil }
        guard !withPutts.isEmpty else { return 0 }
        return Double(totalPutts) / Double(withPutts.count)
    }
    private var upDownPct: Double {
        let attempts = played.filter { $0.girHit == false }
        guard !attempts.isEmpty else { return 0 }
        return Double(attempts.filter { $0.upAndDown == true }.count) / Double(attempts.count)
    }

    private var bestHole: HoleScore? { played.min(by: { $0.toPar < $1.toPar }) }
    private var worstHole: HoleScore? { played.max(by: { $0.toPar < $1.toPar }) }

    var body: some View {
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

                VStack(alignment: .leading, spacing: 4) {
                    Text(courseName).eyebrow()
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(totalScore)")
                            .font(DispersionType.display(48, weight: .regular))
                            .monospacedDigit()
                        Text(toPar == 0 ? "Even" : (toPar > 0 ? "+\(toPar)" : "\(toPar)"))
                            .font(DispersionType.display(24, weight: .regular))
                            .foregroundStyle(toPar < 0 ? DesignTokens.primary
                                             : toPar == 0 ? DesignTokens.foreground
                                             : DesignTokens.pPoor)
                    }
                    Text("\(played.count) holes played")
                        .font(DispersionType.mono(11))
                        .foregroundStyle(DesignTokens.mutedForeground)
                }

                if let round = try? CoursesRepo(context: modelContext).round(id: sessionId) {
                    Button { reviewOpen = true } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Your tracked round").font(.headline)
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            Text("\(courseShots.filter { !$0.isPenalty }.count) shots · \(scores.reduce(0) { $0 + $1.penaltyStrokes }) penalty strokes")
                                .font(.subheadline)
                            Text("Review the map, fill missing shots and correct clubs or penalties.")
                                .font(.caption).foregroundStyle(DesignTokens.mutedForeground)
                        }.foregroundStyle(DesignTokens.foreground)
                            .padding(18).background(ThemedCardFill())
                    }.buttonStyle(.plain)
                    .dispersionSheet(isPresented: $reviewOpen, detents: [.large], scrollable: false) {
                        CourseShotReview(sessionId: sessionId, courseId: round.courseId, initialHole: round.startHole)
                    }
                    .onAppear { try? CoursesRepo(context: modelContext).associateLegacyShots(sessionId: sessionId) }
                }

                // Front / Back split
                if !front9.isEmpty || !back9.isEmpty {
                    HStack(spacing: 0) {
                        if !front9.isEmpty {
                            splitCard("Front 9", score: front9Score, par: front9.reduce(0) { $0 + $1.par })
                        }
                        if !back9.isEmpty {
                            splitCard("Back 9", score: back9Score, par: back9.reduce(0) { $0 + $1.par })
                        }
                    }
                }

                // Key stats grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    statCard("FIR", value: played.contains { $0.fairwayHit != nil } ? "\(Int(firPct * 100))%" : "—", sub: "fairways hit")
                    statCard("GIR", value: played.contains { $0.girHit != nil } ? "\(Int(girPct * 100))%" : "—", sub: "greens in reg")
                    statCard("Putts", value: String(format: "%.1f", puttsPerHole), sub: "per hole · \(totalPutts) total")
                    statCard("Up & Down", value: "\(Int(upDownPct * 100))%", sub: "scrambling")
                }

                // Strokes gained
                let sg = StrokesGained.aggregate(shots)
                if sg.shotCount >= 2 {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Measured-shot strokes gained").eyebrow()
                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(format: "%+.2f", sg.avgSG))
                                    .font(DispersionType.display(28, weight: .regular))
                                    .foregroundStyle(sg.avgSG >= 0 ? DesignTokens.primary : DesignTokens.pPoor)
                                    .monospacedDigit()
                                Text("per shot")
                                    .font(DispersionType.mono(10))
                                    .foregroundStyle(DesignTokens.mutedForeground)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(format: "%+.1f", sg.totalSG))
                                    .font(DispersionType.display(28, weight: .regular))
                                    .foregroundStyle(sg.totalSG >= 0 ? DesignTokens.primary : DesignTokens.pPoor)
                                    .monospacedDigit()
                                Text("total · \(sg.shotCount) shots")
                                    .font(DispersionType.mono(10))
                                    .foregroundStyle(DesignTokens.mutedForeground)
                            }
                            Spacer()
                        }
                    }
                    .padding(14)
                    .background(ThemedCardFill(cornerRadius: 14))
                }

                // Best / Worst
                if let best = bestHole, let worst = worstHole {
                    HStack(spacing: 10) {
                        holeHighlight("Best", hole: best, color: DesignTokens.primary)
                        holeHighlight("Worst", hole: worst, color: DesignTokens.pPoor)
                    }
                }

                // Scorecard grid
                scorecardGrid
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .background(DesignTokens.background.ignoresSafeArea())
    }

    // MARK: - Components

    private func splitCard(_ label: String, score: Int, par: Int) -> some View {
        let tp = score - par
        return VStack(spacing: 4) {
            Text(label).eyebrow()
            Text("\(score)")
                .font(DispersionType.display(28, weight: .regular))
                .monospacedDigit()
            Text(tp == 0 ? "E" : (tp > 0 ? "+\(tp)" : "\(tp)"))
                .font(DispersionType.mono(11, weight: .medium))
                .foregroundStyle(tp < 0 ? DesignTokens.primary : tp == 0 ? DesignTokens.foreground : DesignTokens.pPoor)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(ThemedCardFill(cornerRadius: 14))
    }

    private func statCard(_ label: String, value: String, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).eyebrow()
            Text(value)
                .font(DispersionType.display(24, weight: .regular))
                .monospacedDigit()
            Text(sub)
                .font(DispersionType.mono(9))
                .foregroundStyle(DesignTokens.mutedForeground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(ThemedCardFill(cornerRadius: 14))
    }

    private func holeHighlight(_ label: String, hole: HoleScore, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).eyebrow()
            HStack(spacing: 6) {
                Text("Hole \(hole.hole)")
                    .font(DispersionType.ui(14, weight: .medium))
                Text(hole.label)
                    .font(DispersionType.mono(10, weight: .medium))
                    .foregroundStyle(color)
            }
            Text("Par \(hole.par) · \(hole.score) strokes")
                .font(DispersionType.mono(10))
                .foregroundStyle(DesignTokens.mutedForeground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(ThemedCardFill(cornerRadius: 14))
    }

    private var scorecardGrid: some View {
        VStack(spacing: 8) {
            Text("Scorecard").eyebrow()
            VStack(spacing: 2) {
                ForEach(played, id: \.hole) { hs in
                    HStack {
                        Text("\(hs.hole)")
                            .font(DispersionType.mono(11, weight: .medium))
                            .frame(width: 24, alignment: .center)
                        Text("Par \(hs.par)")
                            .font(DispersionType.mono(10))
                            .foregroundStyle(DesignTokens.mutedForeground)
                            .frame(width: 44)
                        Text("\(hs.score)")
                            .font(DispersionType.display(16, weight: .regular))
                            .foregroundStyle(hs.score < hs.par ? DesignTokens.primary
                                             : hs.score == hs.par ? DesignTokens.foreground
                                             : DesignTokens.pPoor)
                            .frame(width: 28, alignment: .center)
                        Text(hs.label)
                            .font(DispersionType.mono(9))
                            .foregroundStyle(DesignTokens.mutedForeground)
                        Spacer()
                        if let p = hs.putts {
                            Text("\(p)P").font(DispersionType.mono(9)).foregroundStyle(DesignTokens.mutedForeground)
                        }
                        if hs.fairwayHit == true {
                            Image(systemName: "checkmark").font(.system(size: 8)).foregroundStyle(DesignTokens.primary)
                        }
                        if hs.girHit == true {
                            Text("G").font(DispersionType.mono(9, weight: .medium)).foregroundStyle(DesignTokens.primary)
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                }
            }
            .background(ThemedCardFill(cornerRadius: 14))
        }
    }
}
