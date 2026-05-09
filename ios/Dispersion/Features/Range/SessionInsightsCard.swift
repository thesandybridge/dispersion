// Visual card for SessionInsights. One card per club used in the session.
// Surfaces the metrics that matter: σ, deltas vs stored & vs previous,
// miss direction (lateral/long bias).

import SwiftUI

struct SessionInsightsCard: View {
    let insights: [SessionClubInsight]
    let unit: DistanceUnit
    var onCompare: ((String) -> Void)? = nil

    var body: some View {
        if insights.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Session insights").eyebrow()

                VStack(spacing: 8) {
                    ForEach(insights) { insight in
                        clubRow(insight)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func clubRow(_ insight: SessionClubInsight) -> some View {
        let canCompare = insight.carrySdDeltaVsPrevious != nil

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(insight.clubName)
                    .font(DispersionType.ui(14, weight: .medium))
                    .foregroundStyle(DesignTokens.foreground)
                Text("\(insight.shotCount) shots")
                    .font(DispersionType.mono(10))
                    .foregroundStyle(DesignTokens.mutedForeground)
                Spacer()
                if canCompare, let onCompare {
                    Button { onCompare(insight.clubId); Haptics.light() } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "rectangle.split.2x1")
                                .font(.system(size: 10))
                            Text("Compare")
                                .font(DispersionType.mono(10, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(DesignTokens.surface))
                        .foregroundStyle(DesignTokens.foreground)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Sigma row + deltas
            HStack(spacing: 14) {
                sigmaCell(label: "σ↕", value: insight.stats.carrySd,
                          deltaVsStored: insight.carrySdDeltaVsStored,
                          deltaVsPrevious: insight.carrySdDeltaVsPrevious)
                sigmaCell(label: "σ↔", value: insight.stats.lateralSd,
                          deltaVsStored: insight.lateralSdDeltaVsStored,
                          deltaVsPrevious: insight.lateralSdDeltaVsPrevious)
                Spacer()
                missDirectionTag(insight)
            }
        }
        .padding(12)
        .background(ThemedCardFill(cornerRadius: 12))
    }

    private func sigmaCell(label: String, value: Double, deltaVsStored: Double, deltaVsPrevious: Double?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(label)
                    .font(DispersionType.mono(10))
                    .foregroundStyle(DesignTokens.mutedForeground)
                Text(String(format: "%.1f", value))
                    .font(DispersionType.display(20, weight: .regular))
                    .monospacedDigit()
                    .foregroundStyle(DesignTokens.foreground)
            }
            HStack(spacing: 6) {
                deltaPill(label: "vs stored", delta: deltaVsStored)
                if let dp = deltaVsPrevious {
                    deltaPill(label: "vs prev", delta: dp)
                }
            }
        }
    }

    private func deltaPill(label: String, delta: Double) -> some View {
        let tighter = delta < -0.05
        let looser = delta > 0.05
        let color: Color = tighter ? DesignTokens.primary
            : looser ? DesignTokens.pPoor
            : DesignTokens.mutedForeground
        let arrow = tighter ? "↓" : (looser ? "↑" : "→")
        return HStack(spacing: 2) {
            Text("\(arrow)\(String(format: "%.1f", abs(delta)))")
                .font(DispersionType.mono(9, weight: .medium))
            Text(label)
                .font(DispersionType.mono(8))
                .foregroundStyle(DesignTokens.mutedForeground)
        }
        .foregroundStyle(color)
    }

    private func missDirectionTag(_ insight: SessionClubInsight) -> some View {
        let lat = insight.lateralBias
        let lon = insight.longBias
        // Use slightly higher thresholds than 0 to avoid "noise" tags
        let lateralLabel: String? = abs(lat) < 1.0 ? nil
            : (lat < 0 ? "leans L \(Int(abs(lat)))y" : "leans R \(Int(abs(lat)))y")
        let longLabel: String? = abs(lon) < 1.0 ? nil
            : (lon < 0 ? "short \(Int(abs(lon)))y" : "long \(Int(abs(lon)))y")
        let pieces = [lateralLabel, longLabel].compactMap { $0 }
        guard !pieces.isEmpty else {
            return AnyView(
                Text("on target")
                    .font(DispersionType.mono(10, weight: .medium))
                    .foregroundStyle(DesignTokens.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(DesignTokens.primary.opacity(0.15)))
            )
        }
        return AnyView(
            HStack(spacing: 4) {
                ForEach(pieces, id: \.self) { piece in
                    Text(piece)
                        .font(DispersionType.mono(10))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(DesignTokens.surface))
                        .foregroundStyle(DesignTokens.mutedForeground)
                }
            }
        )
    }
}
