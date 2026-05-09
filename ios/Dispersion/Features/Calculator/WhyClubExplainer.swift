// "Why this club" — explains the tradeoff between an alternative club and
// the current recommendation. Surfaces 3 axes the math actually cares
// about: carry fit, σ↕ tightness, σ↔ tightness, and the final P(zone).
//
// Goal: turn the ranked list from a black box into a teaching moment.

import SwiftUI

struct WhyClubExplainer: View {
    let recommended: ClubResult
    let recommendedClub: Club
    let viewing: ClubResult
    let viewingClub: Club
    let scenario: ShotScenario

    private var isRecommended: Bool { viewing.clubId == recommended.clubId }

    private var viewingExpectedCarry: Double { viewing.expectedCarry }
    private var recExpectedCarry: Double { recommended.expectedCarry }

    private var carryFit: Double { viewingExpectedCarry - scenario.distanceToTargetYards }
    private var recCarryFit: Double { recExpectedCarry - scenario.distanceToTargetYards }

    private var viewingCarrySd: Double {
        viewingClub.carrySd * viewing.swingType.sigmaMultiplier
    }
    private var recCarrySd: Double {
        recommendedClub.carrySd * recommended.swingType.sigmaMultiplier
    }
    private var viewingLateralSd: Double {
        viewingClub.lateralSd * viewing.swingType.sigmaMultiplier
    }
    private var recLateralSd: Double {
        recommendedClub.lateralSd * recommended.swingType.sigmaMultiplier
    }

    private var probDelta: Double {
        viewing.probabilityInZone - recommended.probabilityInZone
    }

    var body: some View {
        if isRecommended {
            EmptyView()
        } else {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Why \(recommendedClub.name)?")
                    .eyebrow()
                Spacer()
                probBadge
            }

            VStack(spacing: 6) {
                row(
                    label: "Carry fit",
                    viewingValue: carryDescription(carryFit),
                    recValue: carryDescription(recCarryFit),
                    viewingBetter: abs(carryFit) < abs(recCarryFit)
                )
                row(
                    label: "σ↕ long",
                    viewingValue: String(format: "%.1f", viewingCarrySd),
                    recValue: String(format: "%.1f", recCarrySd),
                    viewingBetter: viewingCarrySd < recCarrySd
                )
                row(
                    label: "σ↔ lateral",
                    viewingValue: String(format: "%.1f", viewingLateralSd),
                    recValue: String(format: "%.1f", recLateralSd),
                    viewingBetter: viewingLateralSd < recLateralSd
                )
            }

            if let summary = oneLineSummary {
                Text(summary)
                    .font(DispersionType.ui(11))
                    .foregroundStyle(DesignTokens.mutedForeground)
                    .padding(.top, 2)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DesignTokens.popover)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(DesignTokens.border, lineWidth: 1)
                )
        )
    }

    private var probBadge: some View {
        let pct = Int(probDelta * 100)
        let isWorse = probDelta < -0.005
        let label = isWorse ? "−\(abs(pct))% P(zone)" : "+\(pct)% P(zone)"
        let color = isWorse ? DesignTokens.pPoor : DesignTokens.primary
        return Text(label)
            .font(DispersionType.mono(10, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(color.opacity(0.14))
                    .overlay(Capsule().strokeBorder(color.opacity(0.3), lineWidth: 1))
            )
    }

    private func row(label: String, viewingValue: String, recValue: String, viewingBetter: Bool) -> some View {
        HStack {
            Text(label)
                .font(DispersionType.mono(10))
                .foregroundStyle(DesignTokens.mutedForeground)
                .frame(width: 90, alignment: .leading)
            HStack(spacing: 4) {
                Text(viewingClub.name)
                    .font(DispersionType.mono(10))
                    .foregroundStyle(DesignTokens.mutedForeground)
                Text(viewingValue)
                    .font(DispersionType.mono(11, weight: viewingBetter ? .bold : .regular))
                    .foregroundStyle(viewingBetter ? DesignTokens.primary : DesignTokens.foreground)
            }
            Spacer()
            HStack(spacing: 4) {
                Text(recommendedClub.name)
                    .font(DispersionType.mono(10))
                    .foregroundStyle(DesignTokens.mutedForeground)
                Text(recValue)
                    .font(DispersionType.mono(11, weight: viewingBetter ? .regular : .bold))
                    .foregroundStyle(viewingBetter ? DesignTokens.foreground : DesignTokens.primary)
            }
        }
    }

    private func carryDescription(_ delta: Double) -> String {
        let v = Int(delta.rounded())
        if v == 0 { return "on target" }
        return v > 0 ? "+\(v)y long" : "\(v)y short"
    }

    /// Plain-English summary highlighting the dominant tradeoff.
    private var oneLineSummary: String? {
        let carryLeader = abs(carryFit) < abs(recCarryFit) ? viewingClub.name : recommendedClub.name
        let sigmaLeader = viewingCarrySd < recCarrySd ? viewingClub.name : recommendedClub.name

        if probDelta < -0.10 {
            return "\(recommendedClub.name) wins decisively on probability."
        }
        if abs(probDelta) < 0.02 {
            return "Almost a coin flip — \(recommendedClub.name) edges out by carry-fit."
        }
        if carryLeader == viewingClub.name && sigmaLeader != viewingClub.name {
            return "\(viewingClub.name) is closer in distance, but \(recommendedClub.name) is tighter."
        }
        if carryLeader != viewingClub.name && sigmaLeader == viewingClub.name {
            return "\(viewingClub.name) is tighter, but \(recommendedClub.name) carries closer to the target."
        }
        return nil
    }
}
