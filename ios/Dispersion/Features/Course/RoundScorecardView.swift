// Scorecard grid + round summary stats. Used both as a mid-round sheet
// and as the end-of-round completion overlay.

import SwiftUI

struct RoundScorecardView: View {
    var scores: [Int: HoleScore]
    var holeCount: Int
    var courseName: String
    var pars: [Int: Int]  // hole → par from scorecard
    var isComplete: Bool
    var totalPutts: Int
    var fairwaysHit: Int
    var fairwaysTotal: Int
    var greensHit: Int
    var greensTotal: Int
    var upAndDowns: Int
    var upAndDownAttempts: Int
    var onDone: (() -> Void)?

    @Environment(\.themeAccent) private var accent
    @State private var appeared = false

    private var played: [HoleScore] {
        (1...holeCount).compactMap { scores[$0] }.filter { $0.score > 0 }
    }
    private var totalScore: Int { played.reduce(0) { $0 + $1.score } }
    private var totalPar: Int { played.reduce(0) { $0 + $1.par } }
    private var toPar: Int { totalScore - totalPar }

    private var front9: [HoleScore] {
        (1...min(9, holeCount)).compactMap { scores[$0] }
    }
    private var back9: [HoleScore] {
        guard holeCount > 9 else { return [] }
        return (10...holeCount).compactMap { scores[$0] }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isComplete {
                    heroScore
                }

                if !isComplete {
                    DSheetHeader(eyebrow: courseName, title: "Scorecard")
                }

                if played.count > 0 {
                    statsGrid
                }

                scorecardGrid

                if let onDone {
                    Button { onDone() } label: {
                        Text("Done").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.dispersion(.primary, size: .lg))
                }
            }
            .padding(.horizontal, isComplete ? 24 : 0)
            .padding(.bottom, 40)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                appeared = true
            }
        }
    }

    // MARK: - Hero score (end of round)

    private var heroScore: some View {
        VStack(spacing: 8) {
            Text(courseName.uppercased())
                .font(DispersionType.mono(11, weight: .medium))
                .tracking(2)
                .foregroundStyle(DesignTokens.mutedForeground)

            Text("\(totalScore)")
                .font(DispersionType.display(72, weight: .regular))
                .monospacedDigit()
                .foregroundStyle(DesignTokens.foreground)
                .scaleEffect(appeared ? 1 : 0.5)
                .opacity(appeared ? 1 : 0)

            Text(toParLabel)
                .font(DispersionType.display(24, weight: .regular))
                .foregroundStyle(toParColor)
                .opacity(appeared ? 1 : 0)

            Text("\(played.count) holes")
                .font(DispersionType.mono(11))
                .foregroundStyle(DesignTokens.mutedForeground)
        }
        .padding(.top, 20)
    }

    private var toParLabel: String {
        if toPar == 0 { return "Even" }
        return toPar > 0 ? "+\(toPar)" : "\(toPar)"
    }

    private var toParColor: Color {
        toPar < 0 ? DesignTokens.primary : toPar == 0 ? DesignTokens.foreground : DesignTokens.pPoor
    }

    // MARK: - Stats grid

    private var statsGrid: some View {
        HStack(spacing: 0) {
            if fairwaysTotal > 0 {
                statCell("FIR", value: "\(fairwaysHit)/\(fairwaysTotal)")
            }
            if greensTotal > 0 {
                statCell("GIR", value: "\(greensHit)/\(greensTotal)")
            }
            statCell("Putts", value: "\(totalPutts)")
            if upAndDownAttempts > 0 {
                statCell("U&D", value: "\(upAndDowns)/\(upAndDownAttempts)")
            }
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DesignTokens.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(DesignTokens.border, lineWidth: 1)
                )
        )
        .opacity(appeared || !isComplete ? 1 : 0)
        .offset(y: appeared || !isComplete ? 0 : 20)
    }

    private func statCell(_ label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(DispersionType.display(18, weight: .regular))
                .monospacedDigit()
            Text(label)
                .font(DispersionType.mono(9, weight: .medium))
                .foregroundStyle(DesignTokens.mutedForeground)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Scorecard grid

    private var scorecardGrid: some View {
        VStack(spacing: 0) {
            if holeCount >= 9 {
                nineHoleBlock(holes: Array(1...min(9, holeCount)), label: "OUT")
            }
            if holeCount > 9 {
                DSeparator()
                nineHoleBlock(holes: Array(10...holeCount), label: "IN")
                DSeparator()
                totalRow
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DesignTokens.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(DesignTokens.border, lineWidth: 1)
                )
        )
        .opacity(appeared || !isComplete ? 1 : 0)
        .offset(y: appeared || !isComplete ? 0 : 30)
    }

    private func nineHoleBlock(holes: [Int], label: String) -> some View {
        let blockScores = holes.compactMap { scores[$0] }.filter { $0.score > 0 }
        let blockTotal = blockScores.reduce(0) { $0 + $1.score }
        let blockPar = holes.reduce(0) { $0 + (pars[$1] ?? scores[$1]?.par ?? 4) }

        return VStack(spacing: 0) {
            // Hole numbers
            HStack(spacing: 0) {
                Text("HOLE")
                    .font(DispersionType.mono(7, weight: .medium))
                    .foregroundStyle(DesignTokens.mutedForeground)
                    .frame(width: 36, alignment: .leading)
                ForEach(holes, id: \.self) { h in
                    Text("\(h)")
                        .font(DispersionType.mono(9, weight: .medium))
                        .foregroundStyle(DesignTokens.mutedForeground)
                        .frame(maxWidth: .infinity)
                }
                Text(label)
                    .font(DispersionType.mono(8, weight: .bold))
                    .foregroundStyle(DesignTokens.mutedForeground)
                    .frame(width: 34, alignment: .trailing)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            // Par row
            HStack(spacing: 0) {
                Text("PAR")
                    .font(DispersionType.mono(7, weight: .medium))
                    .foregroundStyle(DesignTokens.mutedForeground)
                    .frame(width: 36, alignment: .leading)
                ForEach(holes, id: \.self) { h in
                    let par = pars[h] ?? scores[h]?.par ?? 4
                    Text("\(par)")
                        .font(DispersionType.mono(9))
                        .foregroundStyle(DesignTokens.mutedForeground)
                        .frame(maxWidth: .infinity)
                }
                Text("\(blockPar)")
                    .font(DispersionType.mono(9, weight: .bold))
                    .foregroundStyle(DesignTokens.mutedForeground)
                    .frame(width: 34, alignment: .trailing)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(DesignTokens.surface.opacity(0.5))

            // Score row
            HStack(spacing: 0) {
                Text("")
                    .frame(width: 36, alignment: .leading)
                ForEach(holes, id: \.self) { h in
                    let hs = scores[h]
                    let par = pars[h] ?? hs?.par ?? 4
                    let s = hs?.score ?? 0
                    Text(s > 0 ? "\(s)" : "·")
                        .font(DispersionType.mono(11, weight: .semibold))
                        .foregroundStyle(scoreColor(score: s, par: par))
                        .frame(maxWidth: .infinity)
                }
                Text(blockTotal > 0 ? "\(blockTotal)" : "")
                    .font(DispersionType.mono(10, weight: .bold))
                    .frame(width: 34, alignment: .trailing)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
    }

    private var totalRow: some View {
        HStack {
            Spacer()
            HStack(spacing: 16) {
                Text("TOTAL")
                    .font(DispersionType.mono(9, weight: .bold))
                    .foregroundStyle(DesignTokens.mutedForeground)
                Text("\(totalScore)")
                    .font(DispersionType.display(22, weight: .regular))
                    .monospacedDigit()
                Text(toParLabel)
                    .font(DispersionType.mono(12, weight: .medium))
                    .foregroundStyle(toParColor)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
    }

    private func scoreColor(score: Int, par: Int) -> Color {
        guard score > 0 else { return DesignTokens.mutedForeground }
        if score <= par - 2 { return DesignTokens.primary }
        if score < par { return DesignTokens.primary }
        if score == par { return DesignTokens.foreground }
        if score == par + 1 { return DesignTokens.pMarginal }
        return DesignTokens.pPoor
    }
}
