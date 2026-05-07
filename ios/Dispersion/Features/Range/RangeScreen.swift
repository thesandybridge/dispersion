// Port of app/src/routes/range.tsx. Tab container (Live / History) + LiveRange.

import SwiftData
import SwiftUI

// MARK: - Tab container

public struct RangeScreen: View {
    @State private var tab: RangeTab = .live
    @State private var openSessionId: String?

    enum RangeTab { case live, history }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            if openSessionId == nil {
                rangeHeader
            }
            Group {
                switch tab {
                case .live:
                    LiveRangeView()
                case .history:
                    if let sid = openSessionId {
                        SessionDetailView(sessionId: sid) {
                            openSessionId = nil
                        }
                    } else {
                        ShotLogView { id in
                            openSessionId = id
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(
            (tab == .live ? DesignTokens.backgroundDeep : DesignTokens.background)
                .ignoresSafeArea()
        )
        .preferredColorScheme(tab == .live ? .dark : nil)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: tab)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: openSessionId)
        .onAppear {
            tab = .live
            openSessionId = nil
        }
    }

    private var rangeHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if tab == .live {
                        Circle().fill(DesignTokens.primary).frame(width: 6, height: 6)
                    }
                    Text(tab == .live ? "Range mode" : "Shot log").eyebrow()
                }
                Text(tab == .live ? "Practice" : "History")
                    .font(DispersionType.display(28, weight: .regular))
                    .tracking(-0.56)
                    .foregroundStyle(tab == .live ? DesignTokens.foreground : DesignTokens.foreground)
            }
            Spacer()
            HStack(spacing: 4) {
                tabButton("Live", isActive: tab == .live) { tab = .live; openSessionId = nil; Haptics.light() }
                tabButton("History", isActive: tab == .history) { tab = .history; openSessionId = nil; Haptics.light() }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) { DSeparator() }
    }

    private func tabButton(_ label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(DispersionType.ui(13, weight: .medium))
                .foregroundStyle(isActive ? DesignTokens.background : DesignTokens.mutedForeground)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(isActive ? DesignTokens.primary : DesignTokens.muted.opacity(0.4))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Live range (was RangeScreen)

struct LiveRangeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClubModel.carryYards, order: .reverse) private var clubModels: [ClubModel]

    @State private var settings = SettingsStore.shared
    @State private var session  = SessionStore.shared
    @State private var dial     = DialStore.shared

    @State private var selectedClubId: String?
    @State private var taps: [ShotXY] = []
    @State private var targetYards: Double?
    @State private var error: String?
    @State private var dragReadout: ShotXY?

    @State private var sessionGoal: Int = 20
    @State private var switchClubOpen: Bool = false
    @State private var targetSheetOpen: Bool = false
    @State private var addShotOpen: Bool = false
    @State private var pendingShot: ShotXY?
    @State private var pendingShotId: String?
    @State private var endConfirm: Bool = false
    @State private var saveConfirm: Bool = false

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

    var body: some View {
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
                    onDrag: { dragReadout = $0 },
                    readOnly: false
                )
                .padding(.bottom, 50)
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

            // Drag coordinate readout — rendered above everything
            if let ds = dragReadout {
                VStack(spacing: 2) {
                    Text("\(ds.long >= 0 ? "+" : "")\(Int(ds.long))y long")
                        .font(DispersionType.mono(16, weight: .semibold))
                    Text("\(ds.lat >= 0 ? "R" : "L") \(Int(abs(ds.lat)))y")
                        .font(DispersionType.mono(16, weight: .semibold))
                }
                .foregroundStyle(DesignTokens.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(DesignTokens.backgroundDeep.opacity(0.9))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(DesignTokens.primary.opacity(0.3), lineWidth: 1)
                        )
                )
                .frame(maxHeight: .infinity, alignment: .center)
                .allowsHitTesting(false)
            }

            // Bottom toolbar
            if club != nil {
                VStack {
                    Spacer()
                    rangeToolbar
                }
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
        .dispersionSheet(isPresented: $switchClubOpen) { switchSheet }
        .dispersionSheet(isPresented: $targetSheetOpen) { targetSheet }
        .dispersionSheet(isPresented: $addShotOpen) {
            if let c = club {
                AddShotSheet(club: c, targetYards: effectiveTarget) { shot, outcomes in
                    handleTap(shot)
                    addShotOpen = false
                }
            }
        }
        .dispersionSheet(isPresented: Binding(
            get: { pendingShot != nil },
            set: { if !$0 { pendingShot = nil; pendingShotId = nil } }
        ), detents: [.medium]) {
            if let shot = pendingShot {
                shotConfirmSheet(shot: shot)
            }
        }
        .alert("End range session?", isPresented: $endConfirm) {
            Button("End session", role: .destructive) {
                session.clear()
                taps = []
                Haptics.medium()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(taps.isEmpty ? "No shots to save." : "\(taps.count) shots stay in the log.")
        }
        .alert("Save measured σ?", isPresented: $saveConfirm) {
            Button("Save") { saveCalibration(); Haptics.success() }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let c = club {
                Text("Updates \(c.name)'s σ from \(taps.count) shots.")
            }
        }
    }

    // MARK: floating cards

    private func floatingSessionCard(_ club: Club) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(sessionId != nil ? DesignTokens.primary : DesignTokens.mutedForeground.opacity(0.4))
                    .frame(width: 6, height: 6)
                Text(sessionId != nil
                     ? "Live · \(taps.count)/\(sessionGoal)"
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

            // Goal progress bar
            if taps.count > 0 {
                GeometryReader { g in
                    Capsule().fill(DesignTokens.muted.opacity(0.4))
                    Capsule().fill(DesignTokens.primary)
                        .frame(width: g.size.width * min(1, Double(taps.count) / Double(sessionGoal)))
                }
                .frame(height: 3)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
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
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
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
        let shotId = UUID().uuidString.lowercased()
        taps.append(shot)
        do {
            try ShotsRepo(context: modelContext).create(Shot(
                id: shotId,
                sessionId: sid,
                clubId: club.id,
                targetDistanceYards: effectiveTarget,
                longDelta: shot.long,
                latDelta: shot.lat
            ))
            pendingShot = shot
            pendingShotId = shotId
        } catch {
            taps.removeLast()
            self.error = String(describing: error)
            Haptics.error()
        }
    }

    private func deletePendingShot() {
        guard let id = pendingShotId else { return }
        try? ShotsRepo(context: modelContext).delete(id: id)
        if !taps.isEmpty { taps.removeLast() }
        pendingShot = nil
        pendingShotId = nil
        Haptics.medium()
    }

    private func addFaceStrike(x: Double, y: Double) {
        guard let club else { return }
        let strike = FaceStrike(
            id: UUID().uuidString.lowercased(),
            clubId: club.id,
            x: x, y: y
        )
        _ = try? FaceStrikesRepo(context: modelContext).create(strike)
    }

    private func ensureSession() -> String {
        if let id = sessionId { return id }
        let id = UUID().uuidString.lowercased()
        let s = Session(id: id, kind: .range, label: "Range session")
        _ = try? SessionsRepo(context: modelContext).create(s)
        session.setActive(ActiveSession(id: id, kind: .range, label: s.label))
        return id
    }

    @State private var pendingStrikes: [FacePoint] = []

    @ViewBuilder
    private func shotConfirmSheet(shot: ShotXY) -> some View {
        DSheetHeader(eyebrow: "Shot logged", title: "\(club?.name ?? "Club")")

        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Long").eyebrow()
                Text("\(shot.long >= 0 ? "+" : "")\(Int(shot.long))y")
                    .font(DispersionType.display(32, weight: .regular))
                    .monospacedDigit()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Lateral").eyebrow()
                Text("\(shot.lat >= 0 ? "R" : "L") \(Int(abs(shot.lat)))y")
                    .font(DispersionType.display(32, weight: .regular))
                    .monospacedDigit()
            }
            Spacer()
        }

        // Face impact
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Tap face to mark impact").eyebrow()
                Spacer()
                if !pendingStrikes.isEmpty {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DesignTokens.primary)
                        .font(.system(size: 14))
                }
            }
            ClubFaceViz(
                strikes: pendingStrikes,
                onTap: { point in
                    pendingStrikes = [point]
                    addFaceStrike(x: point.x, y: point.y)
                    Haptics.light()
                }
            )
            .frame(height: 200)
        }

        HStack(spacing: 12) {
            Button {
                deletePendingShot()
                pendingStrikes = []
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "trash").font(.system(size: 12))
                    Text("Delete shot")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.dispersion(.destructive))

            Button {
                pendingShot = nil
                pendingShotId = nil
                pendingStrikes = []
                Haptics.success()
            } label: {
                Text("Done")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.dispersion(.primary))
        }
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

    @Environment(\.themeAccent) private var accent

    private var rangeToolbar: some View {
        HStack(spacing: 10) {
            toolbarBtn("arrow.triangle.2.circlepath", label: "Club") { switchClubOpen = true }
            toolbarBtn("scope", label: "Target") { targetSheetOpen = true }
            toolbarBtn("pencil", label: "Manual") { addShotOpen = true }

            if !taps.isEmpty {
                toolbarBtn("arrow.uturn.backward", label: "Undo") {
                    taps.removeLast(); Haptics.light()
                }
            }

            if taps.count >= 2 {
                toolbarBtn("square.and.arrow.down", label: "Save", tint: accent) {
                    saveConfirm = true
                }
            }

            if sessionId != nil {
                toolbarBtn("stop.circle.fill", label: "End", tint: DesignTokens.destructive) {
                    endConfirm = true
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private func toolbarBtn(_ icon: String, label: String, tint: Color = DesignTokens.foreground, action: @escaping () -> Void) -> some View {
        Button { action(); Haptics.light() } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(tint)
                Text(label)
                    .font(DispersionType.mono(8, weight: .medium))
                    .foregroundStyle(DesignTokens.mutedForeground)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
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
