// Port of app/src/routes/range.tsx. Tab container (Live / History) + LiveRange.

import SwiftData
import SwiftUI

// MARK: - Tab container

public struct RangeScreen: View {
    @State private var tab: RangeTab = .live
    @State private var historyPath = NavigationPath()

    enum RangeTab { case live, putt, history }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            rangeHeader
            Group {
                switch tab {
                case .live:
                    LiveRangeView()
                case .putt:
                    PutterRangeView()
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
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(headerEyebrow).eyebrow()
                    Text(headerTitle)
                        .font(DispersionType.display(32))
                        .foregroundStyle(DesignTokens.foreground)
                }
                Spacer()
                BrandMark().foregroundStyle(DesignTokens.primary)
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
            }
            Picker("Practice mode", selection: $tab) {
                Text("Full swing").tag(RangeTab.live)
                Text("Putting").tag(RangeTab.putt)
                Text("History").tag(RangeTab.history)
            }
            .pickerStyle(.segmented)
            .onChange(of: tab) { _, _ in
                historyPath = NavigationPath()
                Haptics.light()
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    private var headerEyebrow: String {
        switch tab {
        case .live: return "Range mode"
        case .putt: return "Putting practice"
        case .history: return "Shot log"
        }
    }

    private var headerTitle: String {
        switch tab {
        case .live: return "Practice"
        case .putt: return "Putting"
        case .history: return "History"
        }
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
    /// What swing the user is practicing right now. Logged shots adopt
    /// this swing type; Save calibration writes to the corresponding
    /// Club variant slot (or the full-swing primary fields).
    @State private var practiceSwing: SwingType = .full
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
            // Base background + a soft warm wash that extends into the area
            // below the radar (under the toolbar) so there's no visible edge
            // where the canvas ends.
            DesignTokens.background.ignoresSafeArea()
            LinearGradient(
                colors: [
                    DesignTokens.bentgrass.opacity(0.08),
                    DesignTokens.bentgrass.opacity(0.02),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

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

            // Drag coordinate readout — anchored to the top of the radar so
            // the user's finger and the dispersion contours aren't covered
            // by the live readout. Same floating pill chrome as the rest of
            // the range UI.
            if let ds = dragReadout {
                VStack {
                    dragReadoutBadge(ds)
                    Spacer()
                }
                .padding(.top, 12)
                .frame(maxWidth: .infinity)
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
        HStack(spacing: 6) {
            Circle()
                .fill(sessionId != nil ? DesignTokens.primary : DesignTokens.mutedForeground.opacity(0.4))
                .frame(width: 6, height: 6)
            Text(club.name)
                .font(DispersionType.ui(13, weight: .medium))
                .foregroundStyle(DesignTokens.foreground)
            Text("\(Int(effectiveTarget))y")
                .font(DispersionType.mono(11))
                .foregroundStyle(DesignTokens.mutedForeground)
            if taps.count > 0 {
                Text("· \(taps.count)")
                    .font(DispersionType.mono(11, weight: .medium))
                    .foregroundStyle(DesignTokens.primary)
            }

            // Swing-type chip — tap to cycle Full → 3/4 → Half. The
            // chip is bordered when the user is practicing a partial
            // swing so it reads as a deliberate choice.
            Button {
                guard taps.isEmpty else { return }
                practiceSwing = nextSwing(after: practiceSwing)
                Haptics.light()
            } label: {
                Text(practiceSwing.label.uppercased())
                    .font(DispersionType.mono(9, weight: .semibold))
                    .tracking(0.8)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .foregroundStyle(
                        practiceSwing == .full
                            ? DesignTokens.mutedForeground
                            : accent
                    )
                    .background(
                        Capsule().fill(
                            practiceSwing == .full
                                ? DesignTokens.surface
                                : accent.opacity(0.18)
                        )
                    )
                    .overlay(
                        Capsule().strokeBorder(
                            practiceSwing == .full
                                ? DesignTokens.border
                                : accent.opacity(0.6),
                            lineWidth: 0.8
                        )
                    )
            }
            .buttonStyle(.plain)
            .disabled(!taps.isEmpty)
            .opacity(taps.isEmpty ? 1 : 0.6)
            .accessibilityLabel("Swing type: \(practiceSwing.label)")
            .accessibilityHint(taps.isEmpty
                               ? "Tap to cycle to next swing type"
                               : "Locked while shots are logged in this session")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(DesignTokens.popover)
                .overlay(Capsule().strokeBorder(DesignTokens.border, lineWidth: 1))
                .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        )
    }

    private func nextSwing(after s: SwingType) -> SwingType {
        switch s {
        case .full: return .threeQuarter
        case .threeQuarter: return .half
        case .half: return .full
        }
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
                .foregroundStyle(DesignTokens.foreground)
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
                .overlay(Capsule().strokeBorder(DesignTokens.border, lineWidth: 1))
                .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
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
                latDelta: shot.lat,
                outcomes: [],
                timestamp: .now,
                swingType: practiceSwing
            ))
            pendingShot = shot
            pendingShotId = shotId
            pendingSwingType = practiceSwing
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
        let profile = SwingProfile(
            carryYards: measuredCarry,
            carrySd: stats.carrySd,
            lateralSd: stats.lateralSd,
            sampleCount: taps.count
        )
        do {
            switch practiceSwing {
            case .full:
                try repo.update(id: club.id, patch: .init(
                    carryYards: measuredCarry,
                    carrySd: stats.carrySd,
                    lateralSd: stats.lateralSd
                ))
            case .threeQuarter:
                try repo.update(id: club.id, patch: .init(threeQuarter: .some(profile)))
            case .half:
                try repo.update(id: club.id, patch: .init(half: .some(profile)))
            }
        } catch {
            self.error = "Failed to save calibration: \(error.localizedDescription)"
        }
    }

    // MARK: dial

    @Environment(\.themeAccent) private var accent

    // Bottom toolbar — discrete floating pills, same chrome as the
    // Course editor (MapBuilderView). Each action is its own capsule
    // with `floatingPillStyle()`; primary state-changing actions
    // (Save, End) get a tinted border so they read as decisions, not
    // utility actions. The dark color scheme is enforced because the
    // pills sit on the radar field, where light text on dark popover
    // reads in both light and dark mode.
    /// Two-row toolbar.
    /// Row 1 — per-shot utility actions (always present, identical set so
    /// they never reflow). Row 2 — session-level actions (Save / End) that
    /// appear only when the session has earned them. Splitting onto two
    /// rows keeps the per-shot pills stable as Save/End come and go.
    private var rangeToolbar: some View {
        VStack(spacing: 10) {
            // Row 2 (session actions) sits ABOVE the utility row so the most
            // contextual / decision-shaped pills get more visual prominence.
            if taps.count >= 2 || sessionId != nil {
                HStack(spacing: 8) {
                    if taps.count >= 2 {
                        rangePillTinted("square.and.arrow.down", "Save calibration", tint: accent) {
                            saveConfirm = true
                        }
                    }
                    if sessionId != nil {
                        rangePillTinted("stop.circle.fill", "End session", tint: DesignTokens.destructive) {
                            endConfirm = true
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            // Row 1 — per-shot utility actions. Undo flips in/out but
            // doesn't move the others because the row is centered as a unit.
            HStack(spacing: 8) {
                rangePill("arrow.triangle.2.circlepath", "Club") { switchClubOpen = true }
                rangePill("scope", "Target") { targetSheetOpen = true }
                rangePill("pencil", "Manual") { addShotOpen = true }
                if !taps.isEmpty {
                    rangePill("arrow.uturn.backward", "Undo") {
                        taps.removeLast(); Haptics.light()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: taps.count)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: sessionId)
        .environment(\.colorScheme, .dark)
    }

    private func rangePill(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button { action(); Haptics.light() } label: {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11))
                Text(label).font(DispersionType.ui(13, weight: .medium))
            }
            .floatingPillStyle()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func rangePillTinted(_ icon: String, _ label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button { action(); Haptics.light() } label: {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold))
                Text(label).font(DispersionType.ui(13, weight: .medium))
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(DesignTokens.popover.opacity(0.92))
                    .overlay(Capsule().strokeBorder(tint.opacity(0.45), lineWidth: 1))
            )
            .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// Live drag-coordinate pill — anchors to the top of the radar so the
    /// dispersion contours stay visible while the user is hunting. Same
    /// floating-pill chrome family as the toolbar and tab pill.
    private func dragReadoutBadge(_ ds: ShotXY) -> some View {
        let longLabel = "\(Int(abs(ds.long)))y \(ds.long >= 0 ? "long" : "short")"
        let latLabel = abs(ds.lat) < 1
            ? "on line"
            : "\(Int(abs(ds.lat)))y \(ds.lat >= 0 ? "right" : "left")"
        return HStack(spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: ds.long >= 0 ? "arrow.up" : "arrow.down")
                    .font(.system(size: 10, weight: .semibold))
                    .opacity(0.7)
                Text(longLabel)
                    .font(DispersionType.mono(12, weight: .semibold))
                    .monospacedDigit()
            }
            Capsule()
                .fill(.white.opacity(0.25))
                .frame(width: 1, height: 12)
            HStack(spacing: 5) {
                if abs(ds.lat) >= 1 {
                    Image(systemName: ds.lat >= 0 ? "arrow.right" : "arrow.left")
                        .font(.system(size: 10, weight: .semibold))
                        .opacity(0.7)
                }
                Text(latLabel)
                    .font(DispersionType.mono(12, weight: .semibold))
                    .monospacedDigit()
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(DesignTokens.popover.opacity(0.92))
                .overlay(Capsule().strokeBorder(accent.opacity(0.45), lineWidth: 1))
        )
        .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
        .environment(\.colorScheme, .dark)
        .transition(.opacity.combined(with: .move(edge: .top)))
        .animation(.spring(response: 0.30, dampingFraction: 0.85), value: ds.long)
        .animation(.spring(response: 0.30, dampingFraction: 0.85), value: ds.lat)
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
