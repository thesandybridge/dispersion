// Club detail view — shows key stats, dispersion viz, shot trends,
// miss pattern, strokes gained, outcomes, and face strikes.

import SwiftData
import SwiftUI

struct ClubDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeAccent) private var accent
    @State private var settings = SettingsStore.shared

    var club: Club
    var onBack: () -> Void
    var onEdit: () -> Void

    @State private var saveConfirm = false
    @State private var pendingStrike: FacePoint?
    @State private var selectedStrikeId: String?
    @State private var deleteStrikeConfirm = false

    private var unit: DistanceUnit { settings.unit }
    private var isPutter: Bool {
        ClubCategoryRegistry.categorize(name: club.name, carryYards: club.carryYards) == .putter
    }

    // All valid shots (for total count, outcomes, etc)
    private var allShots: [Shot] {
        let raw = (try? ShotsRepo(context: modelContext).listByClub(club.id, limit: 500)) ?? []
        return raw.filter { abs($0.longDelta) < 100 && abs($0.latDelta) < 100 }
    }

    // Recent 20 shots with landing data — DECADE recommends this window for dispersion
    private var taps: [ShotXY] {
        allShots
            .filter { !($0.longDelta == 0 && $0.latDelta == 0) }
            .prefix(20)
            .map { ShotXY(lat: $0.latDelta, long: $0.longDelta) }
    }

    private var stats: DispersionStats { Sigma.dispersionFromShots(taps) }
    private var haveStats: Bool { taps.count >= 2 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                statsCard
                if !isPutter { dispersionSection }
                if !isPutter { trendSection }
                if !isPutter { missPatternSection }
                strokesGainedSection
                outcomeBreakdown
                if !isPutter { faceSection }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .background(DesignTokens.background.ignoresSafeArea())
        .enableInteractivePop()
        .alert("Update \(club.name) with measured σ?", isPresented: $saveConfirm) {
            Button("Update") { applyMeasured() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("σ↕ \(String(format: "%.1f", stats.carrySd)) · σ↔ \(String(format: "%.1f", stats.lateralSd)) from \(taps.count) shots")
        }
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

    // MARK: - Stats card (single, clean)

    private var statsCard: some View {
        let cat = ClubCategoryRegistry.categorize(name: club.name, carryYards: club.carryYards)
        let style = ClubCategoryRegistry.style(for: cat)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearGradient(gradient: style.gradient, startPoint: .top, endPoint: .bottom))
                    .frame(width: 4, height: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(club.name)
                        .font(DispersionType.display(24, weight: .regular))
                        .foregroundStyle(DesignTokens.foreground)
                    Text(style.label)
                        .font(DispersionType.mono(9, weight: .medium))
                        .tracking(1.5)
                        .textCase(.uppercase)
                        .foregroundStyle(style.accentDeep)
                }
                Spacer()
            }

            if isPutter {
                HStack(spacing: 0) {
                    statCol("Shots", "\(allShots.count)")
                    Spacer()
                }
            } else {
                // Show stored values (calibration updates these)
                // Sigma uses measured when available for more accuracy
                let displayCarry = club.carryYards
                let displayCarrySd = haveStats ? stats.carrySd : club.carrySd
                let displayLatSd = haveStats ? stats.lateralSd : club.lateralSd

                HStack(spacing: 0) {
                    statCol("Carry", "\(Int(Units.from(yards: displayCarry, in: unit)))\(unit.label)")
                    Spacer()
                    statCol("σ long", "\(String(format: "%.1f", Units.from(yards: displayCarrySd, in: unit)))\(unit.label)")
                    Spacer()
                    statCol("σ lateral", "\(String(format: "%.1f", Units.from(yards: displayLatSd, in: unit)))\(unit.label)")
                    Spacer()
                    statCol("Shots", "\(allShots.count)")
                }

                if haveStats {
                    Text("Based on last \(taps.count) shots")
                        .font(DispersionType.mono(9))
                        .foregroundStyle(DesignTokens.mutedForeground.opacity(0.6))
                }
            }
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

    // MARK: - Dispersion viz

    private var dispersionSection: some View {
        let cSd = haveStats ? stats.carrySd : club.carrySd
        let lSd = haveStats ? stats.lateralSd : club.lateralSd
        return DispersionViz(
            carry: club.carryYards,
            carrySd: cSd,
            lateralSd: lSd,
            distanceToTarget: club.carryYards,
            contours: 5,
            facets: 28,
            background: .clear
        )
        .aspectRatio(1.5, contentMode: .fit)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(
                    colors: [DesignTokens.ink, DesignTokens.pine, DesignTokens.ink],
                    startPoint: .top, endPoint: .bottom
                ))
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Trend

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
                        .foregroundStyle(DesignTokens.foreground.opacity(0.5))
                }
                TrendChart(
                    points: summary.sessionPoints.map { TrendPoint(date: $0.date, value: $0.carrySd) },
                    label: "σ↕ carry",
                    referenceValue: club.carrySd,
                    referenceLabel: "stored"
                )
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(DesignTokens.ink)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    // MARK: - Miss pattern

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
                            .foregroundStyle(DesignTokens.foreground.opacity(0.4))
                        missBar(label: "Short", pct: analysis.pctShort, color: DesignTokens.pPoor)
                    }
                    Spacer()
                    missBar(label: "Right", pct: analysis.pctRight, color: DesignTokens.pPoor)
                }

                if analysis.dominantMiss != "centered" {
                    HStack(spacing: 8) {
                        Image(systemName: "scope")
                            .font(.system(size: 12))
                            .foregroundStyle(accent)
                        let latDir = analysis.aimOffsetLat < 0 ? "left" : "right"
                        Text("Aim \(Int(abs(analysis.aimOffsetLat)))y \(latDir)")
                            .font(DispersionType.mono(11))
                            .foregroundStyle(DesignTokens.foreground.opacity(0.7))
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(accent.opacity(0.08))
                    )
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(DesignTokens.card)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(DesignTokens.border, lineWidth: 1))
            )
        }
    }

    private func missBar(label: String, pct: Double, color: Color) -> some View {
        VStack(spacing: 3) {
            Text("\(Int(pct * 100))%")
                .font(DispersionType.mono(12, weight: .medium))
                .foregroundStyle(pct > 0.3 ? color : DesignTokens.foreground.opacity(0.5))
            Text(label)
                .font(DispersionType.mono(8))
                .foregroundStyle(DesignTokens.foreground.opacity(0.4))
        }
        .frame(minWidth: 44)
    }

    // MARK: - Strokes gained

    @ViewBuilder
    private var strokesGainedSection: some View {
        let sg = StrokesGained.aggregate(allShots)
        if sg.shotCount >= 2 {
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Strokes gained").eyebrow()
                    Text(String(format: "%+.2f", sg.avgSG))
                        .font(DispersionType.display(24, weight: .regular))
                        .foregroundStyle(sg.avgSG >= 0 ? DesignTokens.primary : DesignTokens.pPoor)
                        .monospacedDigit()
                    Text("per shot · \(sg.shotCount) shots")
                        .font(DispersionType.mono(10))
                        .foregroundStyle(DesignTokens.foreground.opacity(0.5))
                }
                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(DesignTokens.card)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(DesignTokens.border, lineWidth: 1))
            )
        }
    }

    // MARK: - Outcomes

    @ViewBuilder
    private var outcomeBreakdown: some View {
        let withOutcomes = allShots.filter { !$0.outcomes.isEmpty }
        if !withOutcomes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Outcomes · \(withOutcomes.count) shots").eyebrow()
                let counts = outcomeCounts(withOutcomes)
                ForEach(counts, id: \.tag) { entry in
                    HStack(spacing: 10) {
                        Text(entry.tag.uppercased())
                            .font(DispersionType.mono(10, weight: .medium))
                            .tracking(1.5)
                            .foregroundStyle(outcomeColor(entry.tag))
                            .frame(width: 60, alignment: .leading)
                        GeometryReader { g in
                            Capsule().fill(outcomeColor(entry.tag).opacity(0.25))
                            Capsule().fill(outcomeColor(entry.tag))
                                .frame(width: g.size.width * entry.fraction)
                        }
                        .frame(height: 6)
                        Text("\(Int(entry.fraction * 100))%")
                            .font(DispersionType.mono(10))
                            .foregroundStyle(DesignTokens.foreground.opacity(0.6))
                            .frame(width: 36, alignment: .trailing)
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(DesignTokens.card)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(DesignTokens.border, lineWidth: 1))
            )
        }
    }

    // MARK: - Face strikes

    @ViewBuilder
    private var faceSection: some View {
        let strikes = (try? FaceStrikesRepo(context: modelContext).listByClub(club.id)) ?? []
        let displayStrikes = strikes.map { FacePoint(id: $0.id, x: $0.x, y: $0.y) }
            + (pendingStrike.map { [$0] } ?? [])

        VStack(alignment: .leading, spacing: 8) {
            Text("Face strikes · \(strikes.count)").eyebrow()
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

            HStack(spacing: 12) {
                if let _ = pendingStrike {
                    Button { savePendingStrike() } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark").font(.system(size: 11, weight: .semibold))
                            Text("Save")
                        }
                    }
                    .buttonStyle(.dispersion(.primary, size: .sm))
                    Button { pendingStrike = nil } label: { Text("Cancel") }
                        .buttonStyle(.dispersion(.ghost, size: .sm))
                } else if let _ = selectedStrikeId {
                    Button { deleteStrikeConfirm = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash").font(.system(size: 11))
                            Text("Delete")
                        }
                    }
                    .buttonStyle(.dispersion(.destructive, size: .sm))
                    Button { selectedStrikeId = nil } label: { Text("Deselect") }
                        .buttonStyle(.dispersion(.ghost, size: .sm))
                } else {
                    Text("Tap the face to place a strike")
                        .font(DispersionType.ui(11))
                        .foregroundStyle(DesignTokens.foreground.opacity(0.45))
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
        _ = try? FaceStrikesRepo(context: modelContext).create(
            FaceStrike(id: p.id, clubId: club.id, x: p.x, y: p.y)
        )
        pendingStrike = nil
    }

    // MARK: - Actions

    private func applyMeasured() {
        try? ClubsRepo(context: modelContext).update(id: club.id, patch: .init(
            carryYards: club.carryYards + stats.longBias,
            carrySd: stats.carrySd,
            lateralSd: stats.lateralSd
        ))
        Haptics.success()
    }

    // MARK: - Helpers

    private struct OutcomeCount: Equatable {
        var tag: String; var count: Int; var fraction: Double
    }

    private func outcomeCounts(_ shots: [Shot]) -> [OutcomeCount] {
        let total = shots.count
        var tally: [String: Int] = [:]
        for shot in shots { for tag in shot.outcomes { tally[tag.rawValue, default: 0] += 1 } }
        return ["in", "short", "long", "left", "right", "penalty"].compactMap { tag in
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
