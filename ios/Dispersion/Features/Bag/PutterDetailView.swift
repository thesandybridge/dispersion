// Putter detail view — putter-specific stats. Mirrors the shape of
// ClubDetailView (header + stats card + sectioned cards) so the surface
// feels familiar, but the content is putter-only: make rate by distance
// bracket, lag-putt proximity, recent putt log.

import SwiftData
import SwiftUI

struct PutterDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeAccent) private var accent

    var putter: Putter
    var onBack: () -> Void
    var onEdit: () -> Void

    @State private var putts: [Putt] = []
    @State private var stats: PutterStats = .empty

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                statsCard
                if stats.totalPutts > 0 {
                    bracketBreakdown
                    recentPuttsSection
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .background(DesignTokens.background.ignoresSafeArea())
        .enableInteractivePop()
        .onAppear { loadData() }
        .onChange(of: putter.id) { _, _ in loadData() }
    }

    // MARK: - Header

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
            Button { onEdit() } label: {
                Text("Edit")
                    .font(DispersionType.ui(13, weight: .medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(DesignTokens.foreground))
                    .foregroundStyle(DesignTokens.background)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Stats card

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearGradient(
                        colors: [accent, accent.opacity(0.6)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .frame(width: 4, height: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(putter.name)
                        .font(DispersionType.display(24, weight: .regular))
                        .foregroundStyle(DesignTokens.foreground)
                    Text("PUTTER · \(putter.headType.label.uppercased())")
                        .font(DispersionType.mono(9, weight: .medium))
                        .tracking(1.5)
                        .foregroundStyle(accent)
                }
                Spacer()
            }

            HStack(spacing: 0) {
                statCol("Putts", "\(stats.totalPutts)")
                Spacer()
                statCol("Make %", "\(Int((stats.overallMakePct * 100).rounded()))%")
                Spacer()
                if let avg = stats.avgLagProximity {
                    statCol("Avg lag", String(format: "%.1f ft", avg))
                    Spacer()
                }
                statCol("Sessions", "\(stats.sessionsCount)")
            }

            HStack(spacing: 10) {
                Text("\(Int(putter.lengthInches))″")
                Text("· \(String(format: "%.1f", putter.loftDegrees))° loft")
            }
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

    // MARK: - Bracket breakdown

    private var bracketBreakdown: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Make rate by distance").eyebrow()
            VStack(spacing: 6) {
                ForEach(PuttDistanceBracket.allCases, id: \.self) { bracket in
                    bracketRow(bracket)
                }
            }
            .padding(14)
            .background(ThemedCardFill(cornerRadius: 14))
        }
    }

    private func bracketRow(_ bracket: PuttDistanceBracket) -> some View {
        let s = stats.bracketStats[bracket]
        let attempts = s?.attempts ?? 0
        let makes = s?.makes ?? 0
        let pct = s?.makePct ?? 0

        return HStack(spacing: 10) {
            Text(bracket.shortLabel)
                .font(DispersionType.mono(10, weight: .medium))
                .frame(width: 50, alignment: .leading)
                .foregroundStyle(DesignTokens.mutedForeground)

            // Bar: filled portion = make rate
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(DesignTokens.border)
                    if attempts > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(barColor(pct: pct))
                            .frame(width: max(4, geo.size.width * pct))
                    }
                }
            }
            .frame(height: 8)

            HStack(spacing: 4) {
                Text("\(makes)/\(attempts)")
                    .font(DispersionType.mono(10))
                    .foregroundStyle(DesignTokens.mutedForeground)
                Text("\(Int((pct * 100).rounded()))%")
                    .font(DispersionType.mono(11, weight: .medium))
                    .foregroundStyle(attempts > 0 ? DesignTokens.foreground : DesignTokens.mutedForeground.opacity(0.4))
                    .frame(width: 38, alignment: .trailing)
                    .monospacedDigit()
            }
        }
    }

    private func barColor(pct: Double) -> Color {
        switch pct {
        case 0.7...:    return DesignTokens.primary
        case 0.45..<0.7: return DesignTokens.pFavored
        case 0.20..<0.45: return DesignTokens.pMarginal
        default:        return DesignTokens.pPoor
        }
    }

    // MARK: - Recent putts

    private var recentPuttsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent putts").eyebrow()
            VStack(spacing: 6) {
                ForEach(putts.prefix(8), id: \.id) { putt in
                    puttRow(putt)
                }
            }
        }
    }

    private func puttRow(_ putt: Putt) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(putt.made ? accent : DesignTokens.pPoor)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(formatDistance(putt.distanceFeet)) · \(putt.made ? "made" : "missed")")
                    .font(DispersionType.ui(13, weight: .medium))
                    .foregroundStyle(DesignTokens.foreground)
                HStack(spacing: 6) {
                    if !putt.made, let r = putt.residualFeet {
                        Text(missDescription(putt: putt, residual: r))
                            .font(DispersionType.mono(10))
                            .foregroundStyle(DesignTokens.mutedForeground)
                    }
                    Text(formatTimestamp(putt.timestamp))
                        .font(DispersionType.mono(10))
                        .foregroundStyle(DesignTokens.mutedForeground.opacity(0.7))
                }
            }
            Spacer()
            Text(putt.context == .practice ? "PRACTICE" : "ROUND")
                .font(DispersionType.mono(8, weight: .medium))
                .tracking(1.2)
                .foregroundStyle(DesignTokens.mutedForeground.opacity(0.6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(ThemedCardFill(cornerRadius: 12))
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "scope")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(DesignTokens.mutedForeground.opacity(0.6))
            Text("No putts logged yet")
                .font(DispersionType.display(20, weight: .regular))
                .foregroundStyle(DesignTokens.foreground)
            Text("Open the Putt tab in Range mode and start logging makes and misses by distance.")
                .font(DispersionType.ui(13))
                .foregroundStyle(DesignTokens.mutedForeground)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .background(ThemedCardFill(cornerRadius: 16))
    }

    // MARK: - Data

    private func loadData() {
        let repo = PuttsRepo(context: modelContext)
        let raw = (try? repo.list(putterId: putter.id)) ?? []
        putts = raw
        stats = PutterStatsEngine.compute(raw)
    }

    private func formatDistance(_ feet: Double) -> String {
        if feet < 10 { return String(format: "%.1f ft", feet) }
        return "\(Int(feet)) ft"
    }

    /// "X.X ft past" / "X.X ft short" / "X.X ft right" / "X.X ft left" /
    /// "X.X ft from cup" depending on which axis dominates the miss. The
    /// original "left X.X ft" wording read as "missed left" — rewriting
    /// against the actual landing coordinates removes the ambiguity.
    private func missDescription(putt: Putt, residual: Double) -> String {
        guard let x = putt.landingX, let y = putt.landingY else {
            return String(format: "%.1f ft from cup", residual)
        }
        let dx = abs(x), dy = abs(y)
        let primary: String
        if dx > dy * 1.2 {
            primary = x >= 0 ? "right" : "left"
        } else if dy > dx * 1.2 {
            primary = y >= 0 ? "past" : "short"
        } else {
            return String(format: "%.1f ft from cup", residual)
        }
        return String(format: "%.1f ft %@", residual, primary)
    }

    private func formatTimestamp(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return date.formatted(.dateTime.hour().minute())
        }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}
