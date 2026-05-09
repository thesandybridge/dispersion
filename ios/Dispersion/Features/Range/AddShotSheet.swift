// Port of app/src/components/range/AddShotDialog.tsx. Manual shot entry
// with carry/lateral inputs and outcome tags.

import SwiftUI

struct AddShotSheet: View {
    var club: Club
    var targetYards: Double
    var onAdd: (ShotXY, Set<ShotOutcomeTag>) -> Void

    @State private var settings = SettingsStore.shared
    @State private var carry: Double = 0
    @State private var lateral: Double = 0
    @State private var side: Side = .right
    @State private var tags: Set<ShotOutcomeTag> = []

    enum Side { case left, right }

    private var unit: DistanceUnit { settings.unit }

    var body: some View {
        DSheetHeader(eyebrow: "Manual entry", title: "\(club.name)")

        VStack(alignment: .leading, spacing: 16) {
            // Carry
            fieldGroup(label: "Carry (\(unit.label))") {
                NumericField("", value: $carry, precision: 1)
            }

            // Lateral
            fieldGroup(label: "Lateral miss (\(unit.label))") {
                HStack(spacing: 8) {
                    NumericField("", value: $lateral, precision: 1)
                    HStack(spacing: 0) {
                        sideBtn("L", selected: side == .left) { side = .left }
                        sideBtn("R", selected: side == .right) { side = .right }
                    }
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(DesignTokens.border, lineWidth: 1))
                }
            }

            // Delta preview
            let longDelta = Units.toYards(carry - targetDisplay, from: unit)
            let latDelta = Units.toYards(side == .left ? -lateral : lateral, from: unit)
            Text("Δ \(longDelta >= 0 ? "+" : "")\(Int(longDelta)) long · \(latDelta >= 0 ? "R" : "L")\(Int(abs(latDelta)))")
                .font(DispersionType.mono(11))
                .foregroundStyle(DesignTokens.mutedForeground)

            // Outcome tags
            VStack(alignment: .leading, spacing: 8) {
                Text("Outcome").eyebrow()
                FlowLayout(spacing: 6, runSpacing: 6) {
                    ForEach(ShotOutcomeTag.allCases, id: \.self) { tag in
                        Button {
                            tags = Outcomes.toggle(in: tags, tag: tag)
                        } label: {
                            Text(tag.rawValue)
                                .font(DispersionType.ui(12, weight: .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule().fill(tags.contains(tag)
                                                   ? DesignTokens.primary.opacity(0.2)
                                                   : DesignTokens.muted.opacity(0.4))
                                )
                                .overlay(
                                    Capsule().strokeBorder(tags.contains(tag)
                                                           ? DesignTokens.primary.opacity(0.5)
                                                           : DesignTokens.border, lineWidth: 1)
                                )
                                .foregroundStyle(tags.contains(tag) ? DesignTokens.primary : DesignTokens.foreground)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button {
                let shot = ShotXY(
                    lat: Units.toYards(side == .left ? -lateral : lateral, from: unit),
                    long: Units.toYards(carry - targetDisplay, from: unit)
                )
                onAdd(shot, tags)
            } label: {
                Text("Log shot")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.dispersion(.primary, size: .lg))
        }
        .onAppear {
            carry = targetDisplay
            lateral = 0
            tags = []
        }
    }

    private var targetDisplay: Double {
        Units.roundForUnit(Units.from(yards: targetYards, in: unit), unit: unit)
    }

    private func fieldGroup<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(DispersionType.ui(13, weight: .medium))
                .foregroundStyle(DesignTokens.mutedForeground)
            content()
                .font(DispersionType.display(18))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(DesignTokens.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(DesignTokens.border, lineWidth: 1)
                        )
                )
        }
    }

    private func sideBtn(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(DispersionType.ui(12, weight: .medium))
                .foregroundStyle(selected ? DesignTokens.background : DesignTokens.mutedForeground)
                .frame(width: 32, height: 36)
                .background(selected ? DesignTokens.foreground : Color.clear)
        }
        .buttonStyle(.plain)
    }
}
