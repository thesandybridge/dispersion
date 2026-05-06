// Port of app/src/routes/range.tsx LiveRange. Polar radar field + floating
// session card + live stats overlay; actions in the persistent radial dial.

import SwiftData
import SwiftUI

public struct RangeScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClubModel.carryYards, order: .reverse) private var clubModels: [ClubModel]

    @State private var settings = SettingsStore.shared
    @State private var session  = SessionStore.shared
    @State private var dial     = DialStore.shared

    @State private var selectedClubId: String?
    @State private var taps: [ShotXY] = []
    @State private var targetYards: Double?
    @State private var error: String?

    @State private var switchClubOpen: Bool = false
    @State private var targetSheetOpen: Bool = false
    @State private var endConfirm: Bool = false
    @State private var saveConfirm: Bool = false

    public init() {}

    private var clubs: [Club] { clubModels.map { $0.toValue() } }
    private var club: Club? {
        clubs.first(where: { $0.id == selectedClubId }) ?? clubs.first
    }
    private var stats: DispersionStats { Sigma.dispersionFromShots(taps) }
    private var effectiveTarget: Double { targetYards ?? club?.carryYards ?? 150 }
    private var sessionId: String? {
        if let s = session.active, s.kind == .range { return s.id }
        return nil
    }

    public var body: some View {
        ZStack {
            DesignTokens.backgroundDeep.ignoresSafeArea()

            if let c = club {
                RangeRadarField(
                    targetYards: effectiveTarget,
                    referenceCarrySd: c.carrySd,
                    referenceLateralSd: c.lateralSd,
                    measured: stats,
                    shots: taps,
                    onTap: { p in handleTap(p) },
                    readOnly: false
                )
                .ignoresSafeArea()

                VStack {
                    HStack(alignment: .top) {
                        floatingSessionCard(c)
                        Spacer()
                        if taps.count >= 2 {
                            liveStatsCard(c)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
            } else {
                noClubsState
            }

            if let error {
                VStack {
                    Text("Failed to log shot: \(error)")
                        .font(DispersionType.ui(12))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(DesignTokens.destructive.opacity(0.18))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(DesignTokens.destructive.opacity(0.45), lineWidth: 1)
                                )
                        )
                        .foregroundStyle(DesignTokens.foreground)
                        .padding(.top, 80)
                    Spacer()
                }
            }
        }
        .preferredColorScheme(.dark)
        .dispersionSheet(isPresented: $switchClubOpen) { switchSheet }
        .dispersionSheet(isPresented: $targetSheetOpen) { targetSheet }
        .alert("End range session?", isPresented: $endConfirm) {
            Button("End", role: .destructive) {
                session.clear()
                taps = []
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Save measured σ to club?", isPresented: $saveConfirm) {
            Button("Save") { saveCalibration() }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let c = club {
                Text("Replaces \(c.name)'s σ values: σ↕ \(String(format: "%.1f", stats.carrySd)), σ↔ \(String(format: "%.1f", stats.lateralSd)).")
            }
        }
        .onAppear { registerDialActions() }
        .onChange(of: taps.count) { _, _ in registerDialActions() }
        .onChange(of: club?.id) { _, _ in registerDialActions() }
    }

    // MARK: floating cards

    private func floatingSessionCard(_ club: Club) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(sessionId != nil ? DesignTokens.primary : DesignTokens.mutedForeground.opacity(0.4))
                    .frame(width: 6, height: 6)
                Text(sessionId != nil
                     ? "Live · \(taps.count) shot\(taps.count == 1 ? "" : "s")"
                     : "Idle"
                ).eyebrow()
            }
            Text(club.name)
                .font(DispersionType.display(26, weight: .regular))
                .tracking(-0.65)
                .foregroundStyle(DesignTokens.foreground)
                .monospacedDigit()
            Text("Target \(Int(effectiveTarget))y")
                .font(DispersionType.mono(11))
                .foregroundStyle(DesignTokens.mutedForeground)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DesignTokens.card.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(DesignTokens.border, lineWidth: 1)
                )
        )
    }

    private func liveStatsCard(_ club: Club) -> some View {
        let measuredCarry = Int(club.carryYards + stats.longBias)
        return VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 4) {
                Circle().fill(DesignTokens.primary).frame(width: 4, height: 4)
                Text("Measured · \(taps.count)").eyebrow()
            }
            Text("\(measuredCarry)")
                .font(DispersionType.display(22, weight: .regular))
                .tracking(-0.44)
                .foregroundStyle(DesignTokens.foreground)
                .monospacedDigit() +
            Text("y")
                .font(DispersionType.ui(11))
                .foregroundStyle(DesignTokens.mutedForeground)
            HStack(spacing: 12) {
                deltaCell(label: "σ↕", value: stats.carrySd, delta: stats.carrySd - club.carrySd)
                deltaCell(label: "σ↔", value: stats.lateralSd, delta: stats.lateralSd - club.lateralSd)
            }
            .font(DispersionType.mono(11))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DesignTokens.card.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(DesignTokens.border, lineWidth: 1)
                )
        )
    }

    private func deltaCell(label: String, value: Double, delta: Double) -> some View {
        let tighter = delta < 0
        let color: Color = abs(delta) < 0.05 ? DesignTokens.mutedForeground
            : tighter ? DesignTokens.primary
            : DesignTokens.pPoor
        return HStack(spacing: 4) {
            Text(label).foregroundStyle(DesignTokens.mutedForeground)
            Text(String(format: "%.1f", value))
                .foregroundStyle(DesignTokens.foreground)
            Text("\(delta > 0 ? "+" : "")\(String(format: "%.1f", delta))")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(color)
        }
    }

    private var noClubsState: some View {
        VStack(spacing: 8) {
            Text("Add a club first")
                .font(DispersionType.display(28, weight: .regular))
                .foregroundStyle(DesignTokens.foreground)
            Text("Range mode logs shots against a club's expected carry.")
                .font(DispersionType.ui(13))
                .foregroundStyle(DesignTokens.mutedForeground)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    // MARK: handlers

    private func handleTap(_ shot: ShotXY) {
        guard let club else { return }
        error = nil
        let sid = ensureSession()
        taps.append(shot)
        Haptics.medium()
        do {
            try ShotsRepo(context: modelContext).create(Shot(
                id: UUID().uuidString.lowercased(),
                sessionId: sid,
                clubId: club.id,
                targetDistanceYards: effectiveTarget,
                longDelta: shot.long,
                latDelta: shot.lat
            ))
        } catch {
            taps.removeLast()
            self.error = String(describing: error)
            Haptics.error()
        }
    }

    private func ensureSession() -> String {
        if let id = sessionId { return id }
        let id = UUID().uuidString.lowercased()
        let s = Session(id: id, kind: .range, label: "Range session")
        try? SessionsRepo(context: modelContext).create(s)
        session.setActive(ActiveSession(id: id, kind: .range, label: s.label))
        return id
    }

    private func saveCalibration() {
        guard let club, taps.count >= 2 else { return }
        let repo = ClubsRepo(context: modelContext)
        try? repo.update(id: club.id, patch: .init(
            carryYards: club.carryYards + stats.longBias,
            carrySd: stats.carrySd,
            lateralSd: stats.lateralSd
        ))
    }

    // MARK: dial

    private func registerDialActions() {
        let canSave = taps.count >= 2 && club != nil
        dial.setActions([
            DialAction(id: "switch", label: "Club", systemImage: "arrow.triangle.2.circlepath") {
                switchClubOpen = true
            },
            DialAction(id: "target", label: "Target", systemImage: "scope") {
                targetSheetOpen = true
            },
            DialAction(id: "undo", label: "Undo", systemImage: "arrow.uturn.backward",
                       isDisabled: taps.isEmpty) {
                if !taps.isEmpty { taps.removeLast() }
            },
            DialAction(id: "save", label: "Calibrate", systemImage: "square.and.arrow.down",
                       tone: .primary, isDisabled: !canSave) {
                saveConfirm = true
            },
            DialAction(id: "end", label: "End", systemImage: "stop.circle.fill",
                       tone: .danger, isDisabled: sessionId == nil) {
                endConfirm = true
            },
        ])
    }

    // MARK: sheets

    @ViewBuilder
    private var switchSheet: some View {
        DSheetHeader(eyebrow: "Switch", title: "Pick a club")
        VStack(spacing: 8) {
            ForEach(clubs, id: \.id) { c in
                Button {
                    selectedClubId = c.id
                    taps = []
                    switchClubOpen = false
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(c.name).font(DispersionType.ui(14, weight: .medium))
                            Text("\(Int(c.carryYards))y · σ\(Int(c.carrySd))×\(Int(c.lateralSd))")
                                .font(DispersionType.mono(11))
                                .foregroundStyle(DesignTokens.mutedForeground)
                        }
                        Spacer()
                        if club?.id == c.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(DesignTokens.primary)
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(club?.id == c.id ? DesignTokens.primary.opacity(0.12) : DesignTokens.card)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(DesignTokens.border, lineWidth: 1)
                            )
                    )
                    .foregroundStyle(DesignTokens.foreground)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var targetSheet: some View {
        DSheetHeader(eyebrow: "Target", title: "How far is the flag?")
        if let c = club {
            let minV: Double = max(20, c.carryYards - 80)
            let maxV: Double = c.carryYards + 80

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Distance").eyebrow()
                    Spacer()
                    Text("\(Int(effectiveTarget))")
                        .font(DispersionType.display(40, weight: .regular))
                        .foregroundStyle(DesignTokens.foreground)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: effectiveTarget))
                        .animation(.spring(response: 0.4, dampingFraction: 0.78), value: effectiveTarget)
                }
                DSlider(
                    value: Binding(
                        get: { effectiveTarget },
                        set: { v in targetYards = v; if !taps.isEmpty { taps = [] } }
                    ),
                    in: minV...maxV,
                    step: 1
                )
                HStack {
                    Text("\(Int(minV))y").font(DispersionType.mono(10)).foregroundStyle(DesignTokens.mutedForeground)
                    Spacer()
                    Text("\(Int(maxV))y").font(DispersionType.mono(10)).foregroundStyle(DesignTokens.mutedForeground)
                }
            }

            HStack {
                Button("Use stored carry (\(Int(c.carryYards))y)") {
                    targetYards = nil
                    taps = []
                }
                .buttonStyle(.dispersion(.ghost, size: .sm))
                Spacer()
                Button("Done") { targetSheetOpen = false }
                    .buttonStyle(.dispersion(.solid))
            }
        }
    }
}
