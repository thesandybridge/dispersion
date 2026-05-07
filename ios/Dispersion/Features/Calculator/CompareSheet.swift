// Side-by-side club comparison for the current target distance.
// Shows overlapping dispersion ellipses and stat comparison.

import SwiftData
import SwiftUI

struct CompareSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClubModel.carryYards, order: .reverse) private var clubModels: [ClubModel]
    @Environment(\.themeAccent) private var accent

    var baseClub: Club
    var baseResult: ClubResult
    var scenario: ShotScenario

    @State private var compareId: String?

    private var clubs: [Club] { clubModels.map { $0.toValue() } }
    private var compareClub: Club? {
        guard let id = compareId else { return nil }
        return clubs.first { $0.id == id }
    }
    private var compareResult: ClubResult? {
        guard let club = compareClub else { return nil }
        return ClubResult(
            clubId: club.id,
            probabilityInZone: Probability.probabilityInZone(club: club, scenario: scenario),
            probabilityPenalty: 0,
            expectedCarry: club.carryYards
        )
    }

    var body: some View {
        DSheetHeader(eyebrow: "Compare", title: "\(baseClub.name) vs...")

        // Club picker
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(clubs.filter { $0.id != baseClub.id }, id: \.id) { c in
                    Button { compareId = c.id; Haptics.light() } label: {
                        Text(c.name)
                            .font(DispersionType.ui(12, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(compareId == c.id
                                               ? accent.opacity(0.2) : Color.white.opacity(0.06))
                            )
                            .overlay(
                                Capsule().strokeBorder(compareId == c.id
                                                       ? accent.opacity(0.4) : DesignTokens.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }

        if let comp = compareClub, let compResult = compareResult {
            // Overlapping dispersion viz
            ZStack {
                DispersionViz(
                    carry: baseClub.carryYards,
                    carrySd: baseClub.carrySd,
                    lateralSd: baseClub.lateralSd,
                    distanceToTarget: scenario.distanceToTargetYards,
                    zoneWidth: scenario.safeZoneWidthYards,
                    zoneDepth: scenario.safeZoneDepthYards,
                    contours: 5,
                    facets: 28,
                    background: DesignTokens.backgroundDeep
                )
                .opacity(0.6)

                DispersionViz(
                    carry: comp.carryYards,
                    carrySd: comp.carrySd,
                    lateralSd: comp.lateralSd,
                    distanceToTarget: scenario.distanceToTargetYards,
                    contours: 5,
                    facets: 28,
                    background: .clear
                )
                .opacity(0.5)
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            // Stat comparison table
            VStack(spacing: 0) {
                compareRow("Club", baseClub.name, comp.name)
                DSeparator()
                compareRow("Carry", "\(Int(baseClub.carryYards))y", "\(Int(comp.carryYards))y")
                DSeparator()
                compareRow("σ long", String(format: "%.1f", baseClub.carrySd), String(format: "%.1f", comp.carrySd))
                DSeparator()
                compareRow("σ lateral", String(format: "%.1f", baseClub.lateralSd), String(format: "%.1f", comp.lateralSd))
                DSeparator()
                compareRow("P(zone)",
                           "\(Int(baseResult.probabilityInZone * 100))%",
                           "\(Int(compResult.probabilityInZone * 100))%",
                           highlight: true)
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
        } else {
            Text("Pick a club to compare")
                .font(DispersionType.ui(13))
                .foregroundStyle(DesignTokens.mutedForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        }
    }

    private func compareRow(_ label: String, _ a: String, _ b: String, highlight: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(DispersionType.mono(10))
                .foregroundStyle(DesignTokens.mutedForeground)
                .frame(width: 70, alignment: .leading)
            Spacer()
            Text(a)
                .font(highlight ? DispersionType.display(18, weight: .regular) : DispersionType.mono(12, weight: .medium))
                .foregroundStyle(DesignTokens.foreground)
                .frame(maxWidth: .infinity, alignment: .center)
            Text(b)
                .font(highlight ? DispersionType.display(18, weight: .regular) : DispersionType.mono(12, weight: .medium))
                .foregroundStyle(accent)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.vertical, 8)
    }
}
