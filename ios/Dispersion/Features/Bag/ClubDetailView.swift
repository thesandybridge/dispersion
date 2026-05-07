// Port of ClubDetail from app/src/routes/clubs.tsx. Shows stored stats,
// measured dispersion from logged shots, outcome breakdown, and an edit
// action that opens ClubEditSheet.

import SwiftData
import SwiftUI

struct ClubDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var settings = SettingsStore.shared

    var club: Club
    var onBack: () -> Void
    var onEdit: () -> Void

    @State private var saveConfirm = false
    @State private var pendingStrike: FacePoint?
    @State private var selectedStrikeId: String?
    @State private var deleteStrikeConfirm = false

    private var unit: DistanceUnit { settings.unit }
    private var u: String { unit.label }

    private var allShots: [Shot] {
        (try? ShotsRepo(context: modelContext).listByClub(club.id, limit: 500)) ?? []
    }

    private var taps: [ShotXY] {
        allShots
            .filter { !($0.longDelta == 0 && $0.latDelta == 0) }
            .map { ShotXY(lat: $0.latDelta, long: $0.longDelta) }
    }

    private var stats: DispersionStats { Sigma.dispersionFromShots(taps) }
    private var haveStats: Bool { taps.count >= 2 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                storedStatsCard
                loggedShotsHeader
                dispersionSection
                if haveStats { measuredComparison }
                trendSection
                missPatternSection
                strokesGainedSection
                outcomeBreakdown
                faceSection
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .background(DesignTokens.fairway50.ignoresSafeArea())
        .alert("Replace \(club.name)'s σ with measured?", isPresented: $saveConfirm) {
            Button("Update club") { applyMeasured() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Updates carry to \(String(format: "%.1f", club.carryYards + stats.longBias))y, σ↕ \(String(format: "%.1f", stats.carrySd)), σ↔ \(String(format: "%.1f", stats.lateralSd)) from \(taps.count) tracked shots.")
        }
    }

    // MARK: header

    private var header: some View {
        HStack {
            Button { onBack() } label: {
                Text("← Back")
                    .font(DispersionType.mono(12))
                    .tracking(1.6)
                    .textCase(.uppercase)
                    .foregroundStyle(DesignTokens.soil900.opacity(0.6))
            }
            .buttonStyle(.plain)
            Spacer()
            Button { onEdit() } label: {
                Text("Edit")
                    .font(DispersionType.ui(13, weight: .medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(DesignTokens.soil900))
                    .foregroundStyle(DesignTokens.fairway50)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: stored stats

    private var storedStatsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Stored").eyebrow(color: DesignTokens.cream.opacity(0.5))
            HStack(spacing: 0) {
                statColumn(label: "Carry", value: "\(Int(Units.from(yards: club.carryYards, in: unit)))\(u)")
                Spacer()
                statColumn(label: "σ↕ long", value: "\(String(format: "%.1f", Units.from(yards: club.carrySd, in: unit)))\(u)")
                Spacer()
                statColumn(label: "σ↔ lat", value: "\(String(format: "%.1f", Units.from(yards: club.lateralSd, in: unit)))\(u)")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DesignTokens.backgroundDeep)
        )
    }

    private func statColumn(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(DispersionType.mono(10, weight: .medium))
                .tracking(1.8)
                .textCase(.uppercase)
                .foregroundStyle(DesignTokens.cream.opacity(0.5))
            Text(value)
                .font(DispersionType.display(28, weight: .regular))
                .tracking(-0.56)
                .foregroundStyle(DesignTokens.cream)
                .monospacedDigit()
        }
    }

    // MARK: logged shots

    private var loggedShotsHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Logged shots").eyebrow()
                Text("\(allShots.count) total · \(taps.count) with landing data")
                    .font(DispersionType.mono(12))
                    .foregroundStyle(DesignTokens.soil900.opacity(0.6))
            }
            Spacer()
            if haveStats {
                Button { saveConfirm = true } label: {
                    Text("Use measured σ")
                        .font(DispersionType.mono(11))
                        .tracking(1.6)
                        .textCase(.uppercase)
                        .foregroundStyle(DesignTokens.primary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: dispersion viz

    @ViewBuilder
    private var dispersionSection: some View {
        if haveStats {
            DispersionViz(
                carry: club.carryYards,
                carrySd: stats.carrySd,
                lateralSd: stats.lateralSd,
                distanceToTarget: club.carryYards,
                contours: 6,
                facets: 28,
                background: DesignTokens.backgroundDeep
            )
            .aspectRatio(1.5, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            Text("Log shots in Range mode to see real dispersion here.")
                .font(DispersionType.ui(13))
                .foregroundStyle(DesignTokens.soil900.opacity(0.55))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(DesignTokens.soil900.opacity(0.04))
                )
        }
    }

    // MARK: measured comparison

    private var measuredComparison: some View {
        HStack(spacing: 12) {
            deltaColumn(
                label: "Carry",
                stored: Units.from(yards: club.carryYards, in: unit),
                measured: Units.from(yards: club.carryYards + stats.longBias, in: unit)
            )
            Spacer()
            deltaColumn(
                label: "σ↕",
                stored: Units.from(yards: club.carrySd, in: unit),
                measured: Units.from(yards: stats.carrySd, in: unit)
            )
            Spacer()
            deltaColumn(
                label: "σ↔",
                stored: Units.from(yards: club.lateralSd, in: unit),
                measured: Units.from(yards: stats.lateralSd, in: unit)
            )
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DesignTokens.soil900.opacity(0.04))
        )
    }

    private func deltaColumn(label: String, stored: Double, measured: Double) -> some View {
        let delta = measured - stored
        let color: Color = abs(delta) < 0.05 ? DesignTokens.soil900.opacity(0.5)
            : delta < 0 ? DesignTokens.primary
            : DesignTokens.pPoor
        return VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(DispersionType.mono(10, weight: .medium))
                .tracking(1.8)
                .textCase(.uppercase)
                .foregroundStyle(DesignTokens.soil900.opacity(0.5))
            HStack(spacing: 4) {
                Text(String(format: "%.1f", measured))
                    .font(DispersionType.display(18, weight: .regular))
                    .foregroundStyle(DesignTokens.soil900)
                    .monospacedDigit()
                Text("\(delta >= 0 ? "+" : "")\(String(format: "%.1f", delta))")
                    .font(DispersionType.mono(10))
                    .foregroundStyle(color)
            }
        }
    }

    // MARK: outcome breakdown

    @ViewBuilder
    private var outcomeBreakdown: some View {
        let withOutcomes = allShots.filter { !$0.outcomes.isEmpty }
        if !withOutcomes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Outcomes").eyebrow()
                    .padding(.top, 8)
                let counts = outcomeCounts(withOutcomes)
                ForEach(counts, id: \.tag) { entry in
                    HStack(spacing: 10) {
                        Text(entry.tag.uppercased())
                            .font(DispersionType.mono(10, weight: .medium))
                            .tracking(1.5)
                            .foregroundStyle(outcomeColor(entry.tag))
                            .frame(width: 60, alignment: .leading)
                        GeometryReader { g in
                            Capsule()
                                .fill(outcomeColor(entry.tag).opacity(0.25))
                                .frame(width: g.size.width)
                                .overlay(alignment: .leading) {
                                    Capsule()
                                        .fill(outcomeColor(entry.tag))
                                        .frame(width: g.size.width * entry.fraction)
                                }
                        }
                        .frame(height: 6)
                        Text("\(Int(entry.fraction * 100))%")
                            .font(DispersionType.mono(10))
                            .foregroundStyle(DesignTokens.soil900.opacity(0.6))
                            .frame(width: 36, alignment: .trailing)
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(DesignTokens.soil900.opacity(0.04))
            )
        }
    }

    // MARK: trend

    @ViewBuilder
    private var trendSection: some View {
        let summary = ShotStatsEngine.summarize(allShots)
        if let summary, summary.sessionPoints.count >= 2 {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("σ trend").eyebrow()
                    Spacer()
                    Text("\(summary.sessionCount) sessions")
                        .font(DispersionType.mono(10))
                        .foregroundStyle(DesignTokens.soil900.opacity(0.5))
                }
                TrendChart(
                    points: summary.sessionPoints.map { TrendPoint(date: $0.date, value: $0.carrySd) },
                    accent: DesignTokens.fairwayShadow,
                    fill: DesignTokens.bentgrass,
                    label: "σ↕ carry",
                    suffix: "y",
                    referenceValue: club.carrySd,
                    referenceLabel: "stored"
                )
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(DesignTokens.ink)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.top, 8)
        }
    }

    // MARK: miss pattern

    @ViewBuilder
    private var missPatternSection: some View {
        if let analysis = MissPattern.analyze(allShots) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Miss pattern").eyebrow()
                    Spacer()
                    Text(analysis.dominantMiss)
                        .font(DispersionType.mono(10, weight: .medium))
                        .foregroundStyle(analysis.dominantMiss == "centered"
                                         ? DesignTokens.primary : DesignTokens.pPoor)
                }
                .padding(.top, 8)

                // Directional grid
                HStack(spacing: 0) {
                    missBar(label: "Left", pct: analysis.pctLeft, color: DesignTokens.pPoor)
                    Spacer()
                    VStack(spacing: 4) {
                        missBar(label: "Long", pct: analysis.pctLong, color: DesignTokens.pMarginal)
                        Text("\(Int(analysis.pctInZone * 100))%")
                            .font(DispersionType.mono(14, weight: .medium))
                            .foregroundStyle(DesignTokens.primary)
                        Text("on target")
                            .font(DispersionType.mono(8))
                            .foregroundStyle(DesignTokens.soil900.opacity(0.4))
                        missBar(label: "Short", pct: analysis.pctShort, color: DesignTokens.pPoor)
                    }
                    Spacer()
                    missBar(label: "Right", pct: analysis.pctRight, color: DesignTokens.pPoor)
                }
                .padding(.vertical, 8)

                // Aim recommendation
                if analysis.dominantMiss != "centered" {
                    HStack(spacing: 8) {
                        Image(systemName: "scope")
                            .font(.system(size: 12))
                            .foregroundStyle(DesignTokens.primary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Aim recommendation").font(DispersionType.ui(12, weight: .medium))
                            let latDir = analysis.aimOffsetLat < 0 ? "left" : "right"
                            let longDir = analysis.aimOffsetLong > 0 ? "club up" : ""
                            Text("Aim \(Int(abs(analysis.aimOffsetLat)))y \(latDir)\(longDir.isEmpty ? "" : ", \(longDir)")")
                                .font(DispersionType.mono(11))
                                .foregroundStyle(DesignTokens.soil900.opacity(0.6))
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(DesignTokens.primary.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(DesignTokens.primary.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(DesignTokens.soil900.opacity(0.04))
            )
        }
    }

    private func missBar(label: String, pct: Double, color: Color) -> some View {
        VStack(spacing: 3) {
            Text("\(Int(pct * 100))%")
                .font(DispersionType.mono(12, weight: .medium))
                .foregroundStyle(pct > 0.3 ? color : DesignTokens.soil900.opacity(0.5))
            Text(label)
                .font(DispersionType.mono(8))
                .foregroundStyle(DesignTokens.soil900.opacity(0.4))
        }
        .frame(minWidth: 44)
    }

    // MARK: strokes gained

    @ViewBuilder
    private var strokesGainedSection: some View {
        let sg = StrokesGained.aggregate(allShots)
        if sg.shotCount >= 2 {
            VStack(alignment: .leading, spacing: 8) {
                Text("Strokes gained").eyebrow()
                    .padding(.top, 8)
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Per shot")
                            .font(DispersionType.mono(9))
                            .foregroundStyle(DesignTokens.soil900.opacity(0.5))
                        Text(String(format: "%+.2f", sg.avgSG))
                            .font(DispersionType.display(24, weight: .regular))
                            .foregroundStyle(sg.avgSG >= 0 ? DesignTokens.primary : DesignTokens.pPoor)
                            .monospacedDigit()
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Total (\(sg.shotCount) shots)")
                            .font(DispersionType.mono(9))
                            .foregroundStyle(DesignTokens.soil900.opacity(0.5))
                        Text(String(format: "%+.1f", sg.totalSG))
                            .font(DispersionType.display(24, weight: .regular))
                            .foregroundStyle(sg.totalSG >= 0 ? DesignTokens.primary : DesignTokens.pPoor)
                            .monospacedDigit()
                    }
                    Spacer()
                }
                Text("vs. PGA Tour approach baseline")
                    .font(DispersionType.ui(10))
                    .foregroundStyle(DesignTokens.soil900.opacity(0.4))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(DesignTokens.soil900.opacity(0.04))
            )
        }
    }

    // MARK: face strikes

    @ViewBuilder
    private var faceSection: some View {
        let strikes = (try? FaceStrikesRepo(context: modelContext).listByClub(club.id)) ?? []
        let displayStrikes = strikes.map { FacePoint(id: $0.id, x: $0.x, y: $0.y) }
            + (pendingStrike.map { [$0] } ?? [])

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Face strikes").eyebrow()
                Spacer()
                Text("\(strikes.count)")
                    .font(DispersionType.mono(10))
                    .foregroundStyle(DesignTokens.soil900.opacity(0.5))
            }
            .padding(.top, 8)

            ClubFaceViz(
                strikes: displayStrikes,
                selectedId: pendingStrike?.id ?? selectedStrikeId,
                onTap: { point in
                    pendingStrike = point
                    selectedStrikeId = nil
                },
                onSelect: { id in
                    if pendingStrike != nil { return }
                    selectedStrikeId = selectedStrikeId == id ? nil : id
                }
            )

            // Action bar
            HStack(spacing: 12) {
                if let _ = pendingStrike {
                    Button {
                        savePendingStrike()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark").font(.system(size: 11, weight: .semibold))
                            Text("Save")
                        }
                    }
                    .buttonStyle(.dispersion(.primary, size: .sm))

                    Button {
                        pendingStrike = nil
                    } label: {
                        Text("Cancel")
                    }
                    .buttonStyle(.dispersion(.ghost, size: .sm))
                } else if let _ = selectedStrikeId {
                    Button {
                        deleteStrikeConfirm = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash").font(.system(size: 11, weight: .medium))
                            Text("Delete")
                        }
                    }
                    .buttonStyle(.dispersion(.destructive, size: .sm))

                    Button {
                        selectedStrikeId = nil
                    } label: {
                        Text("Deselect")
                    }
                    .buttonStyle(.dispersion(.ghost, size: .sm))
                } else {
                    Text("Tap the face to place a strike.")
                        .font(DispersionType.ui(11))
                        .foregroundStyle(DesignTokens.soil900.opacity(0.45))
                }
                Spacer()
            }
        }
        .alert("Delete this strike?", isPresented: $deleteStrikeConfirm) {
            Button("Delete", role: .destructive) {
                if let id = selectedStrikeId {
                    try? FaceStrikesRepo(context: modelContext).delete(id: id)
                    selectedStrikeId = nil
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func savePendingStrike() {
        guard let p = pendingStrike else { return }
        let strike = FaceStrike(
            id: p.id,
            clubId: club.id,
            x: p.x,
            y: p.y
        )
        _ = try? FaceStrikesRepo(context: modelContext).create(strike)
        pendingStrike = nil
    }

    // MARK: actions

    private func applyMeasured() {
        let repo = ClubsRepo(context: modelContext)
        try? repo.update(id: club.id, patch: .init(
            carryYards: club.carryYards + stats.longBias,
            carrySd: stats.carrySd,
            lateralSd: stats.lateralSd
        ))
    }

    // MARK: helpers

    private struct OutcomeCount: Equatable {
        var tag: String
        var count: Int
        var fraction: Double
    }

    private func outcomeCounts(_ shots: [Shot]) -> [OutcomeCount] {
        let total = shots.count
        var tally: [String: Int] = [:]
        for shot in shots {
            for tag in shot.outcomes {
                tally[tag.rawValue, default: 0] += 1
            }
        }
        let order = ["in", "short", "long", "left", "right", "penalty"]
        return order.compactMap { tag in
            guard let c = tally[tag], c > 0 else { return nil }
            return OutcomeCount(tag: tag, count: c, fraction: Double(c) / Double(total))
        }
    }

    private func outcomeColor(_ tag: String) -> Color {
        switch tag {
        case "in": return DesignTokens.primary
        case "penalty": return DesignTokens.destructive
        case "left", "right": return DesignTokens.pPoor
        default: return DesignTokens.pMarginal
        }
    }
}
