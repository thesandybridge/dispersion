// Calibration save sheet — replaces the bare "Save calibration?" alert
// with a confidence-gated preview showing stored σ vs measured σ side
// by side. Lets users see how the math will change before committing.

import SwiftUI

struct CalibrationSheet: View {
    let club: Club
    let measuredCarry: Double
    let stats: DispersionStats
    let unit: DistanceUnit
    let onSave: () -> Void
    let onCancel: () -> Void

    private var confidence: CalibrationConfidence {
        CalibrationConfidence.from(shotCount: stats.n)
    }

    private var newCarryYards: Double { measuredCarry }
    private var newCarrySd: Double { stats.carrySd }
    private var newLateralSd: Double { stats.lateralSd }

    private var carryDelta: Double { newCarryYards - club.carryYards }
    private var carrySdDelta: Double { newCarrySd - club.carrySd }
    private var lateralSdDelta: Double { newLateralSd - club.lateralSd }

    var body: some View {
        DSheetHeader(eyebrow: "Calibrate", title: club.name)

        confidenceCard

        // Side-by-side ellipses
        HStack(spacing: 12) {
            ellipseCard(
                title: "Stored",
                color: DesignTokens.mutedForeground,
                carry: club.carryYards,
                carrySd: club.carrySd,
                lateralSd: club.lateralSd
            )
            ellipseCard(
                title: "Measured",
                color: DesignTokens.primary,
                carry: newCarryYards,
                carrySd: newCarrySd,
                lateralSd: newLateralSd
            )
        }

        // Numeric diff
        VStack(spacing: 0) {
            diffRow("Carry", before: club.carryYards, after: newCarryYards, suffix: unit.label)
            DSeparator()
            diffRow("σ↕ long", before: club.carrySd, after: newCarrySd, suffix: unit.label, decimals: 1)
            DSeparator()
            diffRow("σ↔ lateral", before: club.lateralSd, after: newLateralSd, suffix: unit.label, decimals: 1)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DesignTokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(DesignTokens.border, lineWidth: 1)
                )
        )

        // Action buttons
        HStack(spacing: 10) {
            Button { onCancel(); Haptics.light() } label: {
                Text("Cancel").frame(maxWidth: .infinity)
            }
            .buttonStyle(.dispersion(.ghost, size: .lg))

            Button {
                onSave()
                Haptics.success()
            } label: {
                Text("Save calibration").frame(maxWidth: .infinity)
            }
            .buttonStyle(.dispersion(.primary, size: .lg))
            .disabled(confidence == .insufficient)
        }
    }

    // MARK: - Confidence card

    private var confidenceCard: some View {
        HStack(spacing: 12) {
            Image(systemName: confidenceIcon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(confidenceColor)
                .frame(width: 36, height: 36)
                .background(Circle().fill(confidenceColor.opacity(0.15)))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(confidence.label)
                        .font(DispersionType.ui(13, weight: .medium))
                        .foregroundStyle(DesignTokens.foreground)
                    Text("\(stats.n) shots")
                        .font(DispersionType.mono(10))
                        .foregroundStyle(DesignTokens.mutedForeground)
                }
                Text(confidence.description)
                    .font(DispersionType.ui(11))
                    .foregroundStyle(DesignTokens.mutedForeground)
            }

            Spacer()

            // Sample size dots (10 dots, filled by ratio of n / high threshold)
            sampleDots
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(confidenceColor.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(confidenceColor.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private var sampleDots: some View {
        let total = 10
        let ratio = min(1.0, Double(stats.n) / Double(AppConfig.highCalibrationSize))
        let filled = Int((ratio * Double(total)).rounded())
        return HStack(spacing: 3) {
            ForEach(0..<total, id: \.self) { i in
                Circle()
                    .fill(i < filled ? confidenceColor : DesignTokens.mutedForeground.opacity(0.2))
                    .frame(width: 5, height: 5)
            }
        }
    }

    private var confidenceIcon: String {
        switch confidence {
        case .insufficient: return "exclamationmark.triangle.fill"
        case .low:          return "chart.bar.fill"
        case .good:         return "checkmark.seal.fill"
        case .high:         return "checkmark.seal.fill"
        }
    }

    private var confidenceColor: Color {
        switch confidence {
        case .insufficient: return DesignTokens.destructive
        case .low:          return DesignTokens.pMarginal
        case .good, .high:  return DesignTokens.primary
        }
    }

    // MARK: - Ellipse card

    private func ellipseCard(
        title: String,
        color: Color,
        carry: Double,
        carrySd: Double,
        lateralSd: Double
    ) -> some View {
        VStack(spacing: 8) {
            Text(title).eyebrow(color: color)

            DispersionViz(
                carry: carry,
                carrySd: carrySd,
                lateralSd: lateralSd,
                distanceToTarget: carry,
                contours: 4,
                facets: 24,
                background: DesignTokens.backgroundDeep
            )
            .frame(height: 110)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            HStack(spacing: 8) {
                statTag("\(Int(Units.from(yards: carry, in: unit)))\(unit.label)")
                statTag("σ\(String(format: "%.1f", carrySd))×\(String(format: "%.1f", lateralSd))")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DesignTokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(DesignTokens.border, lineWidth: 1)
                )
        )
    }

    private func statTag(_ text: String) -> some View {
        Text(text)
            .font(DispersionType.mono(9, weight: .medium))
            .foregroundStyle(DesignTokens.mutedForeground)
    }

    // MARK: - Diff row

    private func diffRow(_ label: String, before: Double, after: Double, suffix: String, decimals: Int = 0) -> some View {
        let delta = after - before
        let changed = abs(delta) > 0.01
        let arrow: String
        let arrowColor: Color
        if !changed {
            arrow = "→"
            arrowColor = DesignTokens.mutedForeground
        } else if label.contains("σ") {
            // For σ, lower is better (tighter)
            arrow = delta < 0 ? "↓" : "↑"
            arrowColor = delta < 0 ? DesignTokens.primary : DesignTokens.pPoor
        } else {
            arrow = delta > 0 ? "↑" : "↓"
            arrowColor = DesignTokens.foreground
        }

        return HStack {
            Text(label)
                .font(DispersionType.mono(10))
                .foregroundStyle(DesignTokens.mutedForeground)
                .frame(width: 80, alignment: .leading)
            Spacer()
            Text(format(before, decimals: decimals) + suffix)
                .font(DispersionType.mono(12))
                .foregroundStyle(DesignTokens.mutedForeground)
            Image(systemName: "arrow.right")
                .font(.system(size: 9))
                .foregroundStyle(DesignTokens.mutedForeground.opacity(0.5))
            Text(format(after, decimals: decimals) + suffix)
                .font(DispersionType.mono(12, weight: .medium))
                .foregroundStyle(DesignTokens.foreground)
            Text(arrow)
                .font(DispersionType.mono(11, weight: .bold))
                .foregroundStyle(arrowColor)
                .frame(width: 14)
        }
        .padding(.vertical, 8)
    }

    private func format(_ value: Double, decimals: Int) -> String {
        decimals == 0 ? "\(Int(Units.from(yards: value, in: unit)))" :
            String(format: "%.\(decimals)f", Units.from(yards: value, in: unit))
    }
}
