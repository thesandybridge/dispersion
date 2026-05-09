// Port of app/src/routes/range.tsx. Tab container (Live / History) + LiveRange.

import SwiftData
import SwiftUI

// MARK: - Tab container

public struct RangeScreen: View {
    @State private var tab: RangeTab = .live
    @State private var historyPath = NavigationPath()

    enum RangeTab { case live, history }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            rangeHeader
            Group {
                switch tab {
                case .live:
                    LiveRangeView()
                case .history:
                    NavigationStack(path: $historyPath) {
                        ShotLogView { id in
                            historyPath.append(id)
                        }
                        .toolbar(.hidden, for: .navigationBar)
                        .navigationDestination(for: String.self) { sid in
                            SessionDetailView(sessionId: sid) {
                                historyPath.removeLast()
                            }
                            .toolbar(.hidden, for: .navigationBar)
                            .enableInteractivePop()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(DesignTokens.background.ignoresSafeArea())
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: tab)
        .onAppear {
            tab = .live
            historyPath = NavigationPath()
        }
    }

    private var rangeHeader: some View {
        HStack(alignment: .center) {
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
                    .foregroundStyle(DesignTokens.foreground)
            }
            Spacer()
            tabPill
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) { DSeparator() }
    }

    // MARK: - Tab pill (drag-select)

    private static let tabChipMinWidth: CGFloat = 56
    private static let tabChipSpacing: CGFloat = 4
    private static let tabClusterHPad: CGFloat = 4

    private var tabPill: some View {
        HStack(spacing: Self.tabChipSpacing) {
            tabChip("Live", tab: .live)
            tabChip("History", tab: .history)
        }
        .padding(.horizontal, Self.tabClusterHPad)
        .padding(.vertical, 4)
        .background(Capsule().fill(DesignTokens.popover.opacity(0.92)))
        .overlay(Capsule().strokeBorder(DesignTokens.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
        .contentShape(Capsule())
        .gesture(tabDragGesture)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Range mode")
        .accessibilityValue(tab == .live ? "Live" : "History")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                if tab == .live { switchTab(.history) }
            case .decrement:
                if tab == .history { switchTab(.live) }
            @unknown default: break
            }
        }
    }

    private func tabChip(_ label: String, tab target: RangeTab) -> some View {
        let isActive = tab == target
        return Text(label)
            .font(DispersionType.ui(12, weight: .medium))
            .foregroundStyle(isActive ? DesignTokens.primaryForeground : DesignTokens.foreground)
            .frame(minWidth: Self.tabChipMinWidth)
            .padding(.vertical, 6)
            .background(Capsule().fill(isActive ? DesignTokens.primary : Color.clear))
    }

    private var tabDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let stepWidth = Self.tabChipMinWidth + Self.tabChipSpacing
                let firstCenter = Self.tabClusterHPad + Self.tabChipMinWidth / 2
                let raw = Int(((value.location.x - firstCenter) / stepWidth).rounded())
                let target: RangeTab = raw >= 1 ? .history : .live
                if tab != target { switchTab(target) }
            }
    }

    private func switchTab(_ next: RangeTab) {
        tab = next
        historyPath = NavigationPath()
        Haptics.light()
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
    @State private var pendingSwingType: SwingType = .full
    @State private var pendingOutcomes: Set<ShotOutcomeTag> = []
    @State private var endConfirm: Bool = false
    @State private var saveConfirm: Bool = false

    // Per-session bests, used for the "personal best" callout in shot-confirm.
    @State private var sessionBestCarrySd: Double?
    @State private var sessionBestLateralSd: Double?
    @State private var sessionLongestCarry: Double?
    /// Which best (if any) was set or improved by the most recent shot.
    @State private var lastShotPB: ShotPersonalBest?

    enum ShotPersonalBest {
        case tightestCarrySd, tightestLateralSd, longestCarry

        var label: String {
            switch self {
            case .tightestCarrySd:    return "Tightest σ↕ this session"
            case .tightestLateralSd:  return "Tightest σ↔ this session"
            case .longestCarry:       return "Longest carry this session"
            }
        }
    }

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
            DesignTokens.background.ignoresSafeArea()

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
                .allowsHitTesting(false)
            } else {
                noClubsState
            }

            // Drag coordinate readout — rendered above everything
            if let ds = dragReadout {
                VStack(spacing: 2) {
                    Text("\(Int(abs(ds.long)))y \(ds.long >= 0 ? "long" : "short")")
                        .font(DispersionType.mono(16, weight: .semibold))
                    Text("\(Int(abs(ds.lat)))y \(ds.lat >= 0 ? "right" : "left")")
                        .font(DispersionType.mono(16, weight: .semibold))
                }
                .foregroundStyle(DesignTokens.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(DesignTokens.background.opacity(0.9))
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
        ), detents: [.large]) {
            if let shot = pendingShot {
                shotConfirmSheet(shot: shot)
            }
        }
        .alert("End range session?", isPresented: $endConfirm) {
            Button("End session", role: .destructive) {
                // Delete empty session
                if taps.isEmpty, let id = sessionId {
                    try? SessionsRepo(context: modelContext).delete(id: id)
                }
                session.clear()
                taps = []
                resetSessionBests()
                Haptics.medium()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(taps.isEmpty ? "No shots to save." : "\(taps.count) shots stay in the log.")
        }
        .dispersionSheet(isPresented: $saveConfirm, detents: [.large]) {
            if let c = club {
                CalibrationSheet(
                    club: c,
                    measuredCarry: effectiveTarget + stats.longBias,
                    stats: stats,
                    unit: settings.unit,
                    onSave: {
                        saveCalibration()
                        saveConfirm = false
                    },
                    onCancel: { saveConfirm = false }
                )
            }
        }
    }

    // MARK: floating cards

    private func floatingSessionCard(_ club: Club) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(sessionId != nil ? DesignTokens.primary : DesignTokens.mutedForeground.opacity(0.4))
                .frame(width: 6, height: 6)
            Text(club.name)
                .font(DispersionType.ui(13, weight: .medium))
            Text("\(Int(effectiveTarget))y")
                .font(DispersionType.mono(11))
                .foregroundStyle(DesignTokens.mutedForeground)
            if taps.count > 0 {
                Text("· \(taps.count)")
                    .font(DispersionType.mono(11))
                    .foregroundStyle(DesignTokens.primary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(DesignTokens.popover)
                        )
    }

    private func liveStatsCard(_ club: Club) -> some View {
        let measuredCarry = Int(club.carryYards + stats.longBias)
        let confidence = CalibrationConfidence.from(shotCount: taps.count)
        let confidenceColor: Color = {
            switch confidence {
            case .insufficient: return DesignTokens.destructive
            case .low:          return DesignTokens.pMarginal
            case .good, .high:  return DesignTokens.primary
            }
        }()
        return HStack(spacing: 8) {
            Text("\(measuredCarry)y")
                .font(DispersionType.mono(13, weight: .medium))
            Text("σ↕\(String(format: "%.1f", stats.carrySd))")
                .font(DispersionType.mono(10))
                .foregroundStyle(DesignTokens.mutedForeground)
            Text("σ↔\(String(format: "%.1f", stats.lateralSd))")
                .font(DispersionType.mono(10))
                .foregroundStyle(DesignTokens.mutedForeground)
            HStack(spacing: 4) {
                Circle().fill(confidenceColor).frame(width: 5, height: 5)
                Text("\(taps.count)")
                    .font(DispersionType.mono(9, weight: .medium))
                    .foregroundStyle(confidenceColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(DesignTokens.popover)
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
            pendingSwingType = .full
            pendingOutcomes = autoDetectOutcomes(longDelta: shot.long, latDelta: shot.lat)
            lastShotPB = detectPersonalBest(after: shot)
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
        pendingOutcomes = []
        pendingSwingType = .full
        lastShotPB = nil
        Haptics.medium()
    }

    private func resetSessionBests() {
        sessionBestCarrySd = nil
        sessionBestLateralSd = nil
        sessionLongestCarry = nil
        lastShotPB = nil
    }

    /// Initial outcome chip selection seeded from the recorded delta. Users
    /// can override via the chip row.
    private func autoDetectOutcomes(longDelta: Double, latDelta: Double) -> Set<ShotOutcomeTag> {
        var tags: Set<ShotOutcomeTag> = []
        let onTarget = AppConfig.onTargetYards
        if abs(longDelta) <= onTarget && abs(latDelta) <= onTarget {
            tags.insert(.in)
        } else {
            if longDelta < -onTarget { tags.insert(.short) }
            if longDelta > onTarget { tags.insert(.long) }
            if latDelta < -onTarget { tags.insert(.left) }
            if latDelta > onTarget { tags.insert(.right) }
        }
        return tags
    }

    /// Inspect the just-appended shot and current `taps` to see if we crossed
    /// any session bests. Returns the most notable one for the callout.
    private func detectPersonalBest(after shot: ShotXY) -> ShotPersonalBest? {
        // Need a sample of >=3 to make σ meaningful as a "best" claim.
        guard taps.count >= 3 else {
            // Even with too few samples for σ, longest-carry is still trackable.
            let absoluteCarry = effectiveTarget + shot.long
            if let best = sessionLongestCarry, absoluteCarry > best {
                sessionLongestCarry = absoluteCarry
                return .longestCarry
            } else if sessionLongestCarry == nil {
                sessionLongestCarry = absoluteCarry
            }
            return nil
        }

        let s = Sigma.dispersionFromShots(taps)
        var pb: ShotPersonalBest?

        // Carry σ improvement
        if let prev = sessionBestCarrySd, s.carrySd < prev - 0.05 {
            sessionBestCarrySd = s.carrySd
            pb = .tightestCarrySd
        } else if sessionBestCarrySd == nil {
            sessionBestCarrySd = s.carrySd
        }

        // Lateral σ improvement
        if let prev = sessionBestLateralSd, s.lateralSd < prev - 0.05 {
            sessionBestLateralSd = s.lateralSd
            // Carry σ tightening is the more impressive event; don't override.
            if pb == nil { pb = .tightestLateralSd }
        } else if sessionBestLateralSd == nil {
            sessionBestLateralSd = s.lateralSd
        }

        // Longest carry of the session — only crowned if it actually exceeds
        // the prior longest by a margin (avoids triggering on noise).
        let absoluteCarry = effectiveTarget + shot.long
        if let best = sessionLongestCarry, absoluteCarry > best + 1.0 {
            sessionLongestCarry = absoluteCarry
            // Long carry takes priority over σ events — it's the showy one.
            pb = .longestCarry
        } else if sessionLongestCarry == nil || (sessionLongestCarry ?? 0) < absoluteCarry {
            sessionLongestCarry = absoluteCarry
        }

        return pb
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

        if let pb = lastShotPB {
            personalBestBanner(pb)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.35, dampingFraction: 0.78), value: lastShotPB)
        }

        sessionStatsStrip

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

        swingTypeRow
        outcomeChipRow

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
            .frame(maxWidth: .infinity)
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
                lastShotPB = nil
                Haptics.success()
            } label: {
                Text("Done")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.dispersion(.primary))
        }
    }

    // MARK: - Shot-confirm subviews

    private func personalBestBanner(_ pb: ShotPersonalBest) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 16))
                .foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 1) {
                Text("Personal best")
                    .font(DispersionType.mono(9, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(accent)
                Text(pb.label)
                    .font(DispersionType.ui(13, weight: .medium))
                    .foregroundStyle(DesignTokens.foreground)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(accent.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(accent.opacity(0.4), lineWidth: 1)
                )
        )
    }

    /// Compact row showing how this shot affected session σ. Computes "before"
    /// stats from `taps` minus the most recent shot so we can label deltas.
    private var sessionStatsStrip: some View {
        let after = stats
        let before: DispersionStats = taps.count >= 2
            ? Sigma.dispersionFromShots(Array(taps.dropLast()))
            : .empty
        let dCarry = after.carrySd - before.carrySd
        let dLat = after.lateralSd - before.lateralSd

        return HStack(spacing: 0) {
            statCell(label: "shots", value: "\(taps.count)", deltaText: nil, deltaTighter: nil)
            DSeparator(.vertical).frame(height: 30)
            statCell(
                label: "σ↕",
                value: String(format: "%.1f", after.carrySd),
                deltaText: taps.count >= 3 ? deltaString(dCarry) : nil,
                deltaTighter: dCarry < 0
            )
            DSeparator(.vertical).frame(height: 30)
            statCell(
                label: "σ↔",
                value: String(format: "%.1f", after.lateralSd),
                deltaText: taps.count >= 3 ? deltaString(dLat) : nil,
                deltaTighter: dLat < 0
            )
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DesignTokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(DesignTokens.border, lineWidth: 1)
                )
        )
    }

    private func deltaString(_ d: Double) -> String {
        if abs(d) < 0.05 { return "→0.0" }
        return d < 0 ? "↓\(String(format: "%.1f", abs(d)))" : "↑\(String(format: "%.1f", d))"
    }

    private func statCell(
        label: String,
        value: String,
        deltaText: String?,
        deltaTighter: Bool?
    ) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(DispersionType.display(20, weight: .regular))
                .monospacedDigit()
                .foregroundStyle(DesignTokens.foreground)
            HStack(spacing: 4) {
                Text(label)
                    .font(DispersionType.mono(9, weight: .medium))
                    .foregroundStyle(DesignTokens.mutedForeground)
                if let deltaText {
                    let color: Color = (deltaTighter ?? false)
                        ? DesignTokens.primary
                        : (abs(deltaTextValue(deltaText)) < 0.05
                            ? DesignTokens.mutedForeground
                            : DesignTokens.pPoor)
                    Text(deltaText)
                        .font(DispersionType.mono(9, weight: .medium))
                        .foregroundStyle(color)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Parse the trailing numeric portion of a delta string for color routing.
    private func deltaTextValue(_ s: String) -> Double {
        Double(s.dropFirst()) ?? 0
    }

    private var swingTypeRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Swing type").eyebrow()
            HStack(spacing: 6) {
                ForEach(SwingType.allCases, id: \.self) { type in
                    swingChip(type)
                }
            }
        }
    }

    private func swingChip(_ type: SwingType) -> some View {
        let isActive = pendingSwingType == type
        return Button {
            pendingSwingType = type
            persistPendingShotEdit()
            Haptics.light()
        } label: {
            Text(type.label)
                .font(DispersionType.mono(11, weight: .medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(isActive ? accent : DesignTokens.surface)
                )
                .foregroundStyle(isActive ? DesignTokens.primaryForeground : DesignTokens.foreground)
                .overlay(
                    Capsule().strokeBorder(
                        isActive ? Color.clear : DesignTokens.border,
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Tag as \(type.label) swing")
    }

    private var outcomeChipRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Outcome").eyebrow()
            FlowLayout(spacing: 6, runSpacing: 6) {
                ForEach(ShotOutcomeTag.allCases, id: \.self) { tag in
                    outcomeChip(tag)
                }
            }
        }
    }

    private func outcomeChip(_ tag: ShotOutcomeTag) -> some View {
        let isActive = pendingOutcomes.contains(tag)
        let tone: Color = {
            switch tag {
            case .penalty:               return DesignTokens.destructive
            case .in:                    return DesignTokens.primary
            case .left, .right:          return DesignTokens.pMarginal
            default:                     return DesignTokens.foreground
            }
        }()
        return Button {
            pendingOutcomes = Outcomes.toggle(in: pendingOutcomes, tag: tag)
            persistPendingShotEdit()
            Haptics.light()
        } label: {
            Text(tag.rawValue)
                .font(DispersionType.ui(11, weight: .medium))
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(isActive ? tone.opacity(0.18) : DesignTokens.surface)
                )
                .overlay(
                    Capsule().strokeBorder(
                        isActive ? tone.opacity(0.5) : DesignTokens.border,
                        lineWidth: 1
                    )
                )
                .foregroundStyle(isActive ? tone : DesignTokens.foreground)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(isActive ? "Remove" : "Tag as") \(tag.rawValue)")
    }

    /// Push pendingSwingType + pendingOutcomes back into SwiftData for the
    /// just-logged shot.
    private func persistPendingShotEdit() {
        guard let id = pendingShotId else { return }
        try? ShotsRepo(context: modelContext).update(
            id: id,
            outcomes: pendingOutcomes,
            swingType: pendingSwingType
        )
    }

    private func saveCalibration() {
        guard let club, taps.count >= 2 else { return }
        // Absolute measured carry = target + mean long delta
        let measuredCarry = effectiveTarget + stats.longBias
        let repo = ClubsRepo(context: modelContext)
        do {
            try repo.update(id: club.id, patch: .init(
                carryYards: measuredCarry,
                carrySd: stats.carrySd,
                lateralSd: stats.lateralSd
            ))
        } catch {
            self.error = "Failed to save calibration: \(error.localizedDescription)"
        }
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
                .fill(DesignTokens.popover)
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
