// Round scoring mode. Log hole-by-hole scores during a round.
// Tracks par, score, fairways, GIR, and putts.

import SwiftUI

struct ScorecardView: View {
    @Environment(\.themeAccent) private var accent
    @State private var holes: [HoleScore] = (1...18).map { HoleScore(hole: $0) }
    @State private var currentHole: Int = 1
    @State private var courseName: String = ""

    private var totalScore: Int { holes.reduce(0) { $0 + $1.score } }
    private var totalPar: Int { holes.reduce(0) { $0 + $1.par } }
    private var toPar: Int { totalScore - totalPar }
    private var holesPlayed: Int { holes.filter { $0.score > 0 }.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Scorecard").eyebrow()
                    if holesPlayed > 0 {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(totalScore)")
                                .font(DispersionType.display(48, weight: .regular))
                                .monospacedDigit()
                            Text(toPar == 0 ? "E" : (toPar > 0 ? "+\(toPar)" : "\(toPar)"))
                                .font(DispersionType.display(24, weight: .regular))
                                .foregroundStyle(toPar < 0 ? DesignTokens.primary
                                                 : toPar == 0 ? DesignTokens.foreground
                                                 : DesignTokens.pPoor)
                            Spacer()
                            Text("\(holesPlayed) holes")
                                .font(DispersionType.mono(11))
                                .foregroundStyle(DesignTokens.mutedForeground)
                        }
                    }
                }

                // Hole entry
                holeEntry

                // Scorecard grid
                if holesPlayed > 0 {
                    scorecardGrid
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Hole entry

    private var holeEntry: some View {
        let hole = holes[currentHole - 1]
        return VStack(spacing: 16) {
            // Hole selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(1...18, id: \.self) { h in
                        Button { currentHole = h; Haptics.light() } label: {
                            Text("\(h)")
                                .font(DispersionType.mono(12, weight: .medium))
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle().fill(currentHole == h ? accent
                                                  : holes[h - 1].score > 0 ? Color.white.opacity(0.1)
                                                  : Color.clear)
                                )
                                .overlay(Circle().strokeBorder(DesignTokens.border, lineWidth: 0.5))
                                .foregroundStyle(currentHole == h ? DesignTokens.primaryForeground : DesignTokens.foreground)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Par selector
            HStack {
                Text("Par").eyebrow()
                Spacer()
                ForEach([3, 4, 5], id: \.self) { p in
                    Button {
                        holes[currentHole - 1].par = p
                        Haptics.light()
                    } label: {
                        Text("\(p)")
                            .font(DispersionType.mono(14, weight: .medium))
                            .frame(width: 40, height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(hole.par == p ? accent : DesignTokens.surface)
                            )
                            .foregroundStyle(hole.par == p ? DesignTokens.primaryForeground : DesignTokens.foreground)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Score stepper
            HStack {
                Text("Score").eyebrow()
                Spacer()
                Button { if holes[currentHole - 1].score > 0 { holes[currentHole - 1].score -= 1; Haptics.light() } } label: {
                    Image(systemName: "minus").frame(width: 36, height: 36)
                        .background(Circle().fill(DesignTokens.surface))
                }
                .buttonStyle(.plain)

                Text("\(hole.score)")
                    .font(DispersionType.display(32, weight: .regular))
                    .monospacedDigit()
                    .frame(width: 50, alignment: .center)
                    .foregroundStyle(scoreColor(hole))

                Button { holes[currentHole - 1].score += 1; Haptics.light() } label: {
                    Image(systemName: "plus").frame(width: 36, height: 36)
                        .background(Circle().fill(DesignTokens.surface))
                }
                .buttonStyle(.plain)
            }

            // Quick stats
            HStack(spacing: 12) {
                toggleStat("FW", value: $holes[currentHole - 1].fairwayHit)
                toggleStat("GIR", value: $holes[currentHole - 1].girHit)
                puttsStepper
            }

            // Next hole
            if currentHole < 18 {
                Button {
                    currentHole += 1
                    Haptics.light()
                } label: {
                    Text("Next hole →")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.dispersion(.primary))
            }
        }
        .padding(16)
        .background(ThemedCardFill(cornerRadius: 16))
    }

    private func toggleStat(_ label: String, value: Binding<Bool?>) -> some View {
        Button {
            switch value.wrappedValue {
            case nil: value.wrappedValue = true
            case true: value.wrappedValue = false
            case false: value.wrappedValue = nil
            }
            Haptics.light()
        } label: {
            HStack(spacing: 4) {
                Text(label).font(DispersionType.mono(10, weight: .medium))
                Image(systemName: value.wrappedValue == true ? "checkmark.circle.fill"
                      : value.wrappedValue == false ? "xmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(value.wrappedValue == true ? DesignTokens.primary
                                    : value.wrappedValue == false ? DesignTokens.pPoor
                                    : DesignTokens.mutedForeground)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8).fill(DesignTokens.surface))
        }
        .buttonStyle(.plain)
    }

    private var puttsStepper: some View {
        HStack(spacing: 4) {
            Text("Putts").font(DispersionType.mono(10, weight: .medium))
            Button {
                let cur = holes[currentHole - 1].putts ?? 2
                holes[currentHole - 1].putts = max(0, cur - 1)
                Haptics.light()
            } label: {
                Image(systemName: "minus").font(.system(size: 10))
            }
            .buttonStyle(.plain)

            Text("\(holes[currentHole - 1].putts ?? 2)")
                .font(DispersionType.mono(12, weight: .medium))
                .frame(width: 20, alignment: .center)

            Button {
                let cur = holes[currentHole - 1].putts ?? 2
                holes[currentHole - 1].putts = cur + 1
                Haptics.light()
            } label: {
                Image(systemName: "plus").font(.system(size: 10))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(DesignTokens.surface))
    }

    // MARK: - Scorecard grid

    private var scorecardGrid: some View {
        VStack(spacing: 2) {
            // Front 9
            nineGrid(range: 1...9, label: "Out")
            // Back 9
            if holes.contains(where: { $0.hole > 9 && $0.score > 0 }) {
                nineGrid(range: 10...18, label: "In")
            }
        }
    }

    private func nineGrid(range: ClosedRange<Int>, label: String) -> some View {
        VStack(spacing: 0) {
            // Hole numbers
            HStack(spacing: 0) {
                Text("Hole").font(DispersionType.mono(8)).foregroundStyle(DesignTokens.mutedForeground)
                    .frame(width: 30, alignment: .leading)
                ForEach(range, id: \.self) { h in
                    Text("\(h)").font(DispersionType.mono(9, weight: .medium))
                        .frame(maxWidth: .infinity)
                }
                Text(label).font(DispersionType.mono(8, weight: .medium))
                    .frame(width: 30, alignment: .trailing)
            }
            .padding(.vertical, 4)
            .background(DesignTokens.surface)

            // Par row
            HStack(spacing: 0) {
                Text("Par").font(DispersionType.mono(8)).foregroundStyle(DesignTokens.mutedForeground)
                    .frame(width: 30, alignment: .leading)
                ForEach(range, id: \.self) { h in
                    Text("\(holes[h - 1].par)").font(DispersionType.mono(9))
                        .foregroundStyle(DesignTokens.mutedForeground)
                        .frame(maxWidth: .infinity)
                }
                Text("\(range.map { holes[$0 - 1].par }.reduce(0, +))")
                    .font(DispersionType.mono(9, weight: .medium))
                    .frame(width: 30, alignment: .trailing)
            }
            .padding(.vertical, 3)

            // Score row
            HStack(spacing: 0) {
                Text("Score").font(DispersionType.mono(8)).foregroundStyle(DesignTokens.mutedForeground)
                    .frame(width: 30, alignment: .leading)
                ForEach(range, id: \.self) { h in
                    let hole = holes[h - 1]
                    Text(hole.score > 0 ? "\(hole.score)" : "-")
                        .font(DispersionType.mono(10, weight: .medium))
                        .foregroundStyle(hole.score == 0 ? DesignTokens.mutedForeground : scoreColor(hole))
                        .frame(maxWidth: .infinity)
                }
                let total = range.map { holes[$0 - 1].score }.reduce(0, +)
                Text(total > 0 ? "\(total)" : "-")
                    .font(DispersionType.mono(10, weight: .medium))
                    .frame(width: 30, alignment: .trailing)
            }
            .padding(.vertical, 3)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(DesignTokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(DesignTokens.border, lineWidth: 1)
                )
        )
    }

    private func scoreColor(_ hole: HoleScore) -> Color {
        guard hole.score > 0 else { return DesignTokens.foreground }
        switch hole.toPar {
        case ..<0: return DesignTokens.primary
        case 0: return DesignTokens.foreground
        default: return DesignTokens.pPoor
        }
    }
}
