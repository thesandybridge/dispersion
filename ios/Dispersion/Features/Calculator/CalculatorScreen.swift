// Port of app/src/routes/calculator.tsx. Full-bleed dispersion + hero
// distance + recommended-club card + alts rail + zone sheet.
//
// Diff from the React version: actions live in the persistent radial dial
// (Zone, Log, Reset conditions) rather than inline buttons.

import SwiftData
import SwiftUI

public struct CalculatorScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClubModel.carryYards, order: .reverse) private var clubModels: [ClubModel]

    @State private var scenario = ScenarioStore.shared
    @State private var settings = SettingsStore.shared
    @State private var session  = SessionStore.shared
    @State private var dial     = DialStore.shared
    @State private var tuning   = CalculatorTuningStore.shared
    @Environment(\.themeAccent) private var accent
    @Environment(\.palette) private var palette

    @State private var zoneOpen: Bool = false
    @State private var logOpen: Bool = false
    @State private var compareOpen: Bool = false
    @State private var logFlash: String?
    @State private var viewClubId: String?

    public init() {}

    private var clubs: [Club] { clubModels.map { $0.toValue() } }

    private var playingDistance: Double {
        Conditions.effectiveDistance(
            target: scenario.distance + scenario.pinPosition.distanceAdjustment,
            windMph: scenario.windMph,
            elevationFt: scenario.elevationFt,
            windYardsPerMph: tuning.windYardsPerMph,
            elevYardsPerFoot: tuning.elevYardsPerFoot
        )
    }

    private var lieMul: Double { LieMultiplierStore.shared.multiplier(for: scenario.lie) }

    /// What kind of target is the user aiming at — drives the visual
    /// treatment in DispersionViz (flag pin for greens, aim crosshair for
    /// fairway corridors) and whether the pin-position pill is shown.
    private var currentZoneKind: ZoneKind {
        Presets.kind(
            presetId: scenario.presetId,
            width: scenario.width,
            depth: scenario.depth
        )
    }

    private var adjustedClubs: [Club] {
        let dist = playingDistance
        return clubs.map {
            var c = $0
            if lieMul != 1 {
                c.carrySd *= lieMul
                c.lateralSd *= lieMul
            }
            if let pref = ClubPreferences.preference(for: c.id, at: dist) {
                c.carrySd *= pref.sigmaMultiplier
                c.lateralSd *= pref.sigmaMultiplier
            }
            return c
        }
    }

    private var activePreference: ClubPreference? {
        ClubPreferences.activePreference(at: playingDistance)
    }

    private var rankings: [ClubResult] {
        let s = ShotScenario(
            distanceToTargetYards: playingDistance,
            safeZoneWidthYards: scenario.width,
            safeZoneDepthYards: scenario.depth,
            aimLateralYards: scenario.aimLateralYards
        )
        return Probability.rankClubs(
            adjustedClubs,
            scenario: s,
            shortSideBias: tuning.shortSideBias
        )
    }

    private var qualifying: [ClubResult] {
        scenario.minProbability <= 0
            ? rankings
            : rankings.filter { $0.probabilityInZone >= scenario.minProbability }
    }

    private var noneQualify: Bool {
        scenario.minProbability > 0 && qualifying.isEmpty
    }

    private var listed: [ClubResult] {
        scenario.minProbability > 0 && !qualifying.isEmpty ? qualifying : rankings
    }

    private var recommended: ClubResult? { listed.first }
    private var alts: [ClubResult] { Array(listed.dropFirst().prefix(5)) }

    private var clubMap: [String: Club] {
        Dictionary(uniqueKeysWithValues: adjustedClubs.map { ($0.id, $0) })
    }

    private var viewedResult: ClubResult? {
        if let id = viewClubId, let r = rankings.first(where: { $0.id == id }) {
            return r
        }
        return recommended
    }

    private var viewedClub: Club? {
        guard let r = viewedResult else { return nil }
        return clubMap[r.clubId]
    }

    private var recommendedClub: Club? {
        guard let r = recommended else { return nil }
        return clubMap[r.clubId]
    }

    private var isViewingRecommended: Bool {
        viewedResult?.clubId == recommended?.clubId
    }


    public var body: some View {
        ZStack {
            // Background — dark fairway
            LinearGradient(
                colors: [DesignTokens.ink, DesignTokens.pine, DesignTokens.ink],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            // Full-bleed dispersion — drag vertically to change distance,
            // horizontally to bias lateral aim. Live P(zone) badge floats
            // beside the pin on the green.
            if let club = viewedClub, let vr = viewedResult {
                DispersionViz(
                    carry: vr.expectedCarry,
                    carrySd: club.carrySd * vr.swingType.sigmaMultiplier,
                    lateralSd: club.lateralSd * vr.swingType.sigmaMultiplier,
                    distanceToTarget: scenario.distance,
                    zoneWidth: scenario.width,
                    zoneDepth: scenario.depth,
                    aimLateralYards: scenario.aimLateralYards,
                    pinPosition: scenario.pinPosition,
                    zoneKind: currentZoneKind,
                    liveProbability: vr.probabilityInZone,
                    contours: 7,
                    facets: 28,
                    background: .clear,
                    onPinTap: currentZoneKind == .green ? cyclePinPosition : nil
                )
                .ignoresSafeArea()
                .overlay {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(targetDragGesture)
                        .onTapGesture(count: 2) {
                            // Double-tap → reset aim if any.
                            if scenario.aimLateralYards != 0 {
                                scenario.update(.init(aimLateralYards: 0))
                                Haptics.medium()
                            }
                        }
                }
            }


            // Top scrim — pinned to top edge
            VStack {
                LinearGradient(
                    colors: [DesignTokens.backgroundDeep.opacity(0.9), .clear],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 180)
                Spacer()
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // Top header
            VStack {
                topHeader
                    .padding(.horizontal, 20)
                Spacer()
            }

            // Bottom: recommended card + drawer
            VStack(spacing: 0) {
                Spacer()

                // Conditions badges (if any)
                VStack(alignment: .leading, spacing: 8) {
                    conditionsRow
                    if !isViewingRecommended,
                       let club = viewedClub,
                       let result = viewedResult,
                       let recClub = recommendedClub,
                       let recResult = recommended {
                        viewingBanner(club: club, prob: result.probabilityInZone)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        WhyClubExplainer(
                            recommended: recResult,
                            recommendedClub: recClub,
                            viewing: result,
                            viewingClub: club,
                            scenario: ShotScenario(
                                distanceToTargetYards: playingDistance,
                                safeZoneWidthYards: scenario.width,
                                safeZoneDepthYards: scenario.depth,
                                aimLateralYards: scenario.aimLateralYards
                            )
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 20)

                // Recommended card
                Group {
                    if let result = recommended, let club = clubMap[result.clubId] {
                        recommendedCard(club: club, result: result)
                    } else {
                        emptyRecommendation
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // Alternatives - horizontal scroll
                if !alts.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(alts, id: \.id) { r in
                                if let club = clubMap[r.clubId] {
                                    altChip(result: r, club: club)
                                }
                            }
                        }
                        .padding(.leading, 16)
                        .padding(.trailing, 80)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.bottom, 8)
        }
                .dispersionSheet(isPresented: $zoneOpen) {
            ZoneSheet()
        }
        .dispersionSheet(isPresented: $logOpen, detents: [.large]) {
            if let club = recommendedClub {
                QuickLogSheet(club: club, distance: scenario.distance) { outcomes, landing in
                    handleLog(club: club, outcomes: outcomes, landing: landing)
                }
            }
        }
        .dispersionSheet(isPresented: $compareOpen, detents: [.large]) {
            if let club = recommendedClub, let result = recommended {
                CompareSheet(
                    baseClub: club,
                    baseResult: result,
                    scenario: ShotScenario(
                        distanceToTargetYards: playingDistance,
                        safeZoneWidthYards: scenario.width,
                        safeZoneDepthYards: scenario.depth,
                        aimLateralYards: scenario.aimLateralYards
                    )
                )
            }
        }
        .overlay(alignment: .top) {
            if let flash = logFlash {
                Text("Logged · \(flash)")
                    .font(DispersionType.ui(12, weight: .semibold))
                    .foregroundStyle(DesignTokens.primaryForeground)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(accent))
                    .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                    .padding(.top, 80)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: logFlash)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: viewClubId)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: recommended?.clubId)
        .onAppear { registerDialActions() }
        .onChange(of: recommended?.clubId) { _, _ in registerDialActions() }
        .onChange(of: scenario.windMph) { _, _ in registerDialActions() }
    }

    // MARK: chrome

    private var topHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let active = session.active {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(active.kind == .range ? accent : DesignTokens.pMarginal)
                            .frame(width: 6, height: 6)
                        Text("Active · \(active.kind.rawValue)").eyebrow()
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "scope")
                            .font(.system(size: 10))
                            .foregroundStyle(DesignTokens.mutedForeground)
                        Text("Calculator").eyebrow()
                    }
                }
                Spacer()
            }

            distanceDisplay

            // Pin position + zone preset, side by side as floating capsules.
            // Pin pill only renders for green-kind zones (front/middle/back
            // is meaningless for a fairway corridor).
            HStack(spacing: 8) {
                if currentZoneKind == .green {
                    pinPositionPill
                }
                Spacer()
                zonePresetPill
            }
            .environment(\.colorScheme, .dark)
            .padding(.top, 4)
        }
        .padding(.top, 8)
    }

    // MARK: - Pin position pill (drag-select)

    private static let pinChipMinWidth: CGFloat = 38
    private static let pinChipSpacing: CGFloat = 4
    private static let pinClusterHPad: CGFloat = 6

    private var pinPositionPill: some View {
        HStack(spacing: Self.pinChipSpacing) {
            ForEach(PinPosition.allCases, id: \.self) { pin in
                pinChip(pin)
            }
        }
        .padding(.horizontal, Self.pinClusterHPad)
        .padding(.vertical, 4)
        .background(Capsule().fill(DesignTokens.popover.opacity(0.92)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
        .contentShape(Capsule())
        .gesture(pinDragGesture)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pin position")
        .accessibilityValue(scenario.pinPosition.label)
        .accessibilityAdjustableAction { direction in
            let cases = PinPosition.allCases
            guard let i = cases.firstIndex(of: scenario.pinPosition) else { return }
            switch direction {
            case .increment:
                if i + 1 < cases.count {
                    scenario.pinPosition = cases[i + 1]
                    Haptics.light()
                }
            case .decrement:
                if i > 0 {
                    scenario.pinPosition = cases[i - 1]
                    Haptics.light()
                }
            @unknown default: break
            }
        }
    }

    private func pinChip(_ pin: PinPosition) -> some View {
        let isActive = scenario.pinPosition == pin
        return Text(pin.label)
            .font(DispersionType.mono(10, weight: .medium))
            .foregroundStyle(isActive ? DesignTokens.primaryForeground : .white)
            .frame(minWidth: Self.pinChipMinWidth)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Capsule().fill(isActive ? accent : Color.clear))
    }

    private var pinDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let cases = PinPosition.allCases
                let stepWidth = Self.pinChipMinWidth + Self.pinChipSpacing + 16
                let firstCenter = Self.pinClusterHPad + Self.pinChipMinWidth / 2 + 8
                let raw = Int(((value.location.x - firstCenter) / stepWidth).rounded())
                let clamped = max(0, min(cases.count - 1, raw))
                let candidate = cases[clamped]
                if scenario.pinPosition != candidate {
                    scenario.pinPosition = candidate
                    Haptics.light()
                }
            }
    }

    // MARK: - Zone preset pill

    private var zonePresetPill: some View {
        Button { zoneOpen = true; Haptics.light() } label: {
            let presetName = Presets.all.first(where: { $0.id == scenario.presetId })?.label ?? "Custom"
            let w = Int(Units.from(yards: scenario.width, in: settings.unit))
            let d = Int(Units.from(yards: scenario.depth, in: settings.unit))
            HStack(spacing: 6) {
                Image(systemName: "scope")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                Text(presetName)
                    .font(DispersionType.ui(11, weight: .medium))
                Text("\(w)×\(d)")
                    .font(DispersionType.mono(9))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .floatingPillStyle()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Zone — \(scenario.width.formatted()) by \(scenario.depth.formatted()). Tap to adjust.")
    }

    @State private var dragStartYards: Double = 0

    /// Cycle through PinPosition cases — invoked when the user taps the
    /// pin glyph rendered inside DispersionViz.
    private func cyclePinPosition() {
        let cases = PinPosition.allCases
        guard let i = cases.firstIndex(of: scenario.pinPosition) else { return }
        scenario.pinPosition = cases[(i + 1) % cases.count]
        Haptics.light()
    }

    private var distanceDisplay: some View {
        let display = Units.roundForUnit(
            Units.from(yards: scenario.distance, in: settings.unit),
            unit: settings.unit
        )
        return Button { zoneOpen = true } label: {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(Int(display))")
                    .font(DispersionType.display(72, weight: .regular))
                    .tracking(-2.5)
                    .foregroundStyle(DesignTokens.foreground)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: display))
                    .animation(.spring(response: 0.4, dampingFraction: 0.78), value: display)
                Text(settings.unit.label.uppercased())
                    .font(DispersionType.display(20, weight: .regular))
                    .foregroundStyle(DesignTokens.foreground.opacity(0.5))
            }
        }
        .buttonStyle(.plain)
    }

    private func aimAdvice(for club: Club) -> String? {
        let shots = (try? ShotsRepo(context: modelContext).listByClub(club.id, limit: 50)) ?? []
        guard let analysis = MissPattern.analyze(shots) else { return nil }
        guard analysis.dominantMiss != "centered" else { return nil }

        var parts: [String] = []
        if abs(analysis.aimOffsetLat) >= 2 {
            let dir = analysis.aimOffsetLat < 0 ? "left" : "right"
            parts.append("aim \(Int(abs(analysis.aimOffsetLat)))y \(dir)")
        }
        guard !parts.isEmpty else { return nil }
        return "↳ " + parts.joined(separator: ", ")
    }

    @State private var dragStartAim: Double = 0
    @State private var dragHasStarted: Bool = false

    private var targetDragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                if !dragHasStarted {
                    dragStartYards = scenario.distance
                    dragStartAim = scenario.aimLateralYards
                    dragHasStarted = true
                }

                // Vertical drag → distance. Up = farther.
                let ptsPerYardVert: CGFloat = 5
                let deltaDist = Double(-value.translation.height / ptsPerYardVert)
                let newDist = (dragStartYards + deltaDist).rounded()
                let clampedDist = max(20, min(400, newDist))
                if clampedDist != scenario.distance {
                    Haptics.light()
                    scenario.update(.init(distance: clampedDist))
                }

                // Horizontal drag → lateral aim. Right = aim right.
                let ptsPerYardHoriz: CGFloat = 6
                let deltaAim = Double(value.translation.width / ptsPerYardHoriz)
                let newAim = (dragStartAim + deltaAim).rounded()
                if newAim != scenario.aimLateralYards {
                    scenario.update(.init(aimLateralYards: newAim))
                }
            }
            .onEnded { _ in
                dragStartYards = 0
                dragStartAim = 0
                dragHasStarted = false
            }
    }

    /// Condition chips — wind, elevation, lie, probability threshold, plus
    /// the lateral aim status when non-zero. Each renders as its own
    /// floating pill, sitting in the bottom panel above the recommended
    /// card so it's always visible above the system tab bar.
    private var conditionsRow: some View {
        let items = activeConditionItems
        return Group {
            if items.isEmpty {
                EmptyView()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(items, id: \.key) { item in
                            conditionChip(item: item)
                        }
                    }
                }
                .scrollClipDisabled()  // let shadows overflow the scrollview
                .environment(\.colorScheme, .dark)
            }
        }
    }

    private struct ConditionItem {
        let key: String
        let label: String
        let icon: String
        let alert: Bool
        /// Action to fire when the chip is tapped. Most chips open the
        /// zone sheet; the aim chip resets the aim instead.
        let action: () -> Void
    }

    private var activeConditionItems: [ConditionItem] {
        var items: [ConditionItem] = []
        if scenario.windMph != 0 {
            items.append(.init(
                key: "wind",
                label: scenario.windMph > 0
                    ? "+\(Int(scenario.windMph)) tail"
                    : "\(Int(abs(scenario.windMph))) head",
                icon: "wind",
                alert: false,
                action: { zoneOpen = true }
            ))
        }
        if scenario.elevationFt != 0 {
            items.append(.init(
                key: "elev",
                label: scenario.elevationFt > 0
                    ? "+\(Int(scenario.elevationFt))ft"
                    : "\(Int(abs(scenario.elevationFt)))ft↓",
                icon: "mountain.2",
                alert: false,
                action: { zoneOpen = true }
            ))
        }
        if scenario.lie != .fairway && scenario.lie != .tee {
            items.append(.init(
                key: "lie",
                label: scenario.lie.label,
                icon: "leaf",
                alert: false,
                action: { zoneOpen = true }
            ))
        }
        if abs(scenario.aimLateralYards) > 0.5 {
            let yards = Int(abs(scenario.aimLateralYards).rounded())
            let direction = scenario.aimLateralYards < 0 ? "left" : "right"
            let icon = scenario.aimLateralYards < 0 ? "arrow.left" : "arrow.right"
            items.append(.init(
                key: "aim",
                label: "Aim \(yards)y \(direction) · clear",
                icon: icon,
                alert: false,
                action: {
                    scenario.update(.init(aimLateralYards: 0))
                    Haptics.medium()
                }
            ))
        }
        if scenario.minProbability > 0 {
            let pct = Int((scenario.minProbability * 100).rounded())
            items.append(.init(
                key: "thresh",
                label: noneQualify ? "≥\(pct)% · none qualify" : "≥\(pct)%",
                icon: "percent",
                alert: noneQualify,
                action: { zoneOpen = true }
            ))
        }
        return items
    }

    private func conditionChip(item: ConditionItem) -> some View {
        Button {
            item.action()
            if item.key != "aim" { Haptics.light() }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: item.icon)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(item.alert ? DesignTokens.destructive : .white.opacity(0.7))
                Text(item.label)
                    .font(DispersionType.mono(10, weight: .medium))
                    .foregroundStyle(item.alert ? DesignTokens.destructive : .white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(DesignTokens.popover.opacity(0.92))
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                item.alert ? DesignTokens.destructive.opacity(0.45) : .white.opacity(0.08),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.key == "aim" ? "\(item.label). Tap to clear aim." : item.label)
    }

    private func viewingBanner(club: Club, prob: Double) -> some View {
        let isPreferred = ClubPreferences.preference(for: club.id, at: playingDistance) != nil
        return HStack {
            HStack(spacing: 6) {
                Text("Viewing").eyebrow(color: DesignTokens.destructive)
                Text(club.name)
                    .font(DispersionType.ui(13, weight: .medium))
                Text("\(Int(prob * 100))%")
                    .font(DispersionType.mono(11))
                    .foregroundStyle(DesignTokens.mutedForeground)
            }
            Spacer()
            if isPreferred {
                Button {
                    ClubPreferences.remove(clubId: club.id, near: playingDistance)
                    Haptics.medium()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pin.slash").font(.system(size: 10))
                        Text("Clear")
                    }
                    .font(DispersionType.mono(10, weight: .medium))
                    .foregroundStyle(DesignTokens.destructive)
                }
            } else {
                Button {
                    ClubPreferences.set(ClubPreference(clubId: club.id, distanceYards: playingDistance))
                    Haptics.success()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pin.fill").font(.system(size: 10))
                        Text("Prefer here")
                    }
                    .font(DispersionType.mono(10, weight: .medium))
                    .foregroundStyle(accent)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isPreferred ? accent.opacity(0.1) : DesignTokens.destructive.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(isPreferred ? accent.opacity(0.4) : DesignTokens.destructive.opacity(0.4), lineWidth: 1)
                )
        )
    }

    private func recommendedCard(club: Club, result: ClubResult) -> some View {
        let lbl = ProbLabelRegistry.of(result.probabilityInZone, palette: palette)
        let isActive = isViewingRecommended
        let isPreferred = ClubPreferences.preference(for: club.id, at: playingDistance) != nil
        return Button { viewClubId = nil } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Circle().fill(lbl.color).frame(width: 5, height: 5)
                        if isPreferred {
                            HStack(spacing: 4) {
                                Text("Recommended")
                                    .eyebrow(color: lbl.color)
                                Image(systemName: "pin.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(accent)
                            }
                        } else {
                            Text("Recommended · \(lbl.label.lowercased())")
                                .eyebrow(color: lbl.color)
                        }
                    }
                    HStack(spacing: 6) {
                        Text(club.name)
                            .font(DispersionType.display(28, weight: .regular))
                            .tracking(-0.5)
                            .foregroundStyle(DesignTokens.foreground)
                            .lineLimit(1)
                        if result.swingType != .full {
                            Text(result.swingType.label)
                                .font(DispersionType.mono(10, weight: .medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(lbl.color.opacity(0.2)))
                                .foregroundStyle(lbl.color)
                        }
                    }
                    HStack(spacing: 10) {
                        Text("EXP \(Int(result.expectedCarry))y")
                        Text("σ↕ \(String(format: "%.1f", club.carrySd))")
                        Text("σ↔ \(String(format: "%.1f", club.lateralSd))")
                    }
                    .font(DispersionType.mono(10))
                    .foregroundStyle(DesignTokens.mutedForeground)

                    // Aim recommendation from miss data
                    if let aim = aimAdvice(for: club) {
                        Text(aim)
                            .font(DispersionType.mono(10, weight: .medium))
                            .foregroundStyle(accent)
                            .padding(.top, 2)
                    }
                }
                Spacer()
                ProbabilityDial(value: result.probabilityInZone, color: lbl.color, diameter: 64, trackThickness: 5)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ThemedCardFill(cornerRadius: 16, opacity: 0.9)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                isActive ? lbl.color.opacity(0.4) : DesignTokens.border,
                                lineWidth: 1
                            )
                    )
                    .shadow(color: isActive ? lbl.color.opacity(0.12) : .clear, radius: 8)
            )
        }
        .buttonStyle(.plain)
    }

    private var emptyRecommendation: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No clubs").eyebrow()
            Text("Add a club to get a recommendation.")
                .font(DispersionType.ui(13))
                .foregroundStyle(DesignTokens.mutedForeground)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ThemedCardFill(cornerRadius: 18, opacity: 0.7))
    }

    private func altChip(result: ClubResult, club: Club) -> some View {
        let lbl = ProbLabelRegistry.of(result.probabilityInZone, palette: palette)
        let active = viewClubId == result.id
        return Button { viewClubId = active ? nil : result.id; Haptics.light() } label: {
            HStack(spacing: 8) {
                // Probability dot — same color as the probability label
                Circle().fill(lbl.color).frame(width: 6, height: 6)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(club.name)
                            .font(DispersionType.ui(13, weight: .medium))
                            .lineLimit(1)
                            .foregroundStyle(.white)
                        if result.swingType != .full {
                            Text(result.swingType.label)
                                .font(DispersionType.mono(9, weight: .medium))
                                .foregroundStyle(lbl.color)
                        }
                    }
                    HStack(spacing: 6) {
                        Text("\(Int(result.expectedCarry))y")
                            .font(DispersionType.mono(10))
                            .foregroundStyle(.white.opacity(0.55))
                        Text("\(Int(result.probabilityInZone * 100))%")
                            .font(DispersionType.mono(11, weight: .medium))
                            .foregroundStyle(lbl.color)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(active ? accent.opacity(0.18) : DesignTokens.popover.opacity(0.92))
                    .overlay(
                        Capsule().strokeBorder(
                            active ? accent.opacity(0.45) : .white.opacity(0.08),
                            lineWidth: 1
                        )
                    )
            )
            .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .environment(\.colorScheme, .dark)
        .accessibilityLabel("\(club.name) at \(Int(result.probabilityInZone * 100)) percent")
    }

    // MARK: logging

    private func ensureRoundSession() -> String {
        if let active = session.active, active.kind == .round {
            return active.id
        }
        let id = UUID().uuidString.lowercased()
        let s = Session(id: id, kind: .round, label: "Course session")
        _ = try? SessionsRepo(context: modelContext).create(s)
        session.setActive(ActiveSession(id: id, kind: .round, label: s.label))
        return id
    }

    private func handleLog(
        club: Club,
        outcomes: Set<ShotOutcomeTag>,
        landing: QuickLogSheet.LandingDelta?
    ) {
        Haptics.medium()
        let sid = ensureRoundSession()
        let shot = Shot(
            id: UUID().uuidString.lowercased(),
            sessionId: sid,
            clubId: club.id,
            targetDistanceYards: scenario.distance,
            longDelta: landing?.long ?? 0,
            latDelta: landing?.lat ?? 0,
            outcomes: outcomes
        )
        do {
            try ShotsRepo(context: modelContext).create(shot)
            logOpen = false
            let label = outcomes.isEmpty
                ? "logged"
                : outcomes.map(\.rawValue).sorted().joined(separator: " · ")
            let landingNote: String
            if let l = landing {
                let lSign = l.long >= 0 ? "+" : ""
                let s = l.lat >= 0 ? "+" : ""
                landingNote = " · \(lSign)\(Int(l.long)), \(s)\(Int(l.lat))"
            } else {
                landingNote = ""
            }
            logFlash = "\(club.name) · \(label)\(landingNote)"
            Haptics.success()
            Task {
                try? await Task.sleep(for: .seconds(2.2))
                logFlash = nil
            }
        } catch {
            logOpen = false
            logFlash = "Error · \(error.localizedDescription)"
            Haptics.error()
            Task {
                try? await Task.sleep(for: .seconds(6))
                logFlash = nil
            }
        }
    }

    // MARK: dial actions

    private func registerDialActions() {
        let canLog = recommended != nil
        dial.setActions([
            DialAction(id: "zone", label: "Zone", systemImage: "slider.horizontal.3") {
                zoneOpen = true
            },
            DialAction(id: "log", label: "Log shot", systemImage: "plus", tone: .primary, isDisabled: !canLog) {
                logOpen = true
            },
            DialAction(id: "compare", label: "Compare", systemImage: "arrow.left.arrow.right", isDisabled: !canLog) {
                compareOpen = true
            },
            DialAction(id: "reset", label: "Reset", systemImage: "arrow.counterclockwise") {
                scenario.update(.init(
                    windMph: 0,
                    elevationFt: 0,
                    lie: .fairway,
                    minProbability: 0
                ))
            },
        ])
    }

    // MARK: zone sheet

    @ViewBuilder
    private func ZoneSheet() -> some View {
        let unit = settings.unit
        DSheetHeader(eyebrow: "Adjust", title: "Target & zone")

        UnitNumberField(
            label: "Distance to target (\(unit.label))",
            valueYards: scenario.distance,
            unit: unit
        ) { yd in scenario.update(.init(distance: yd)) }

        VStack(alignment: .leading, spacing: 8) {
            Text("Preset").eyebrow()
            DToggleGroup(
                options: Presets.all.map { DToggleOption(value: $0.id, label: $0.label) },
                selection: Binding(
                    get: { scenario.presetId },
                    set: { if let id = $0 { scenario.applyPreset(id) } }
                )
            )
        }

        HStack(spacing: 10) {
            UnitNumberField(label: "Width (\(unit.label))", valueYards: scenario.width, unit: unit) { yd in
                scenario.update(.init(width: yd, preset: .some(nil)))
            }
            UnitNumberField(label: "Depth (\(unit.label))", valueYards: scenario.depth, unit: unit) { yd in
                scenario.update(.init(depth: yd, preset: .some(nil)))
            }
        }

        VStack(alignment: .leading, spacing: 8) {
            Text("Lie").eyebrow()
            DToggleGroup(
                options: LieType.allCases.map { lie in
                    let mul = LieMultiplierStore.shared.multiplier(for: lie)
                    return DToggleOption(
                        value: lie,
                        label: lie.label,
                        trailing: mul == 1
                            ? nil
                            : "×\(String(format: "%.2f", mul))"
                    )
                },
                selection: Binding(
                    get: { scenario.lie },
                    set: { if let v = $0 { scenario.update(.init(lie: v)) } }
                )
            )
        }

        VStack(alignment: .leading, spacing: 12) {
            Text("Conditions").eyebrow()
            SliderRow(
                label: "Wind",
                value: scenario.windMph,
                range: -25...25,
                step: 1,
                describe: describeWind
            ) { v in scenario.update(.init(windMph: v)) }
            SliderRow(
                label: "Elevation",
                value: scenario.elevationFt,
                range: -50...50,
                step: 1,
                describe: describeElevation
            ) { v in scenario.update(.init(elevationFt: v)) }
        }

        VStack(alignment: .leading, spacing: 8) {
            Text("Confidence threshold").eyebrow()
            SliderRow(
                label: "Min P(in zone)",
                value: scenario.minProbability * 100,
                range: 0...95,
                step: 5,
                describe: { v in
                    Int(v) == 0 ? "Show all clubs" : "Only ≥\(Int(v))% in zone"
                }
            ) { v in scenario.update(.init(minProbability: v / 100)) }
        }

        HStack {
            Spacer()
            Button("Done") { zoneOpen = false }.buttonStyle(.dispersion(.solid))
        }
    }

    private func describeWind(_ v: Double) -> String {
        if v == 0 { return "Calm" }
        if v > 0 { return "Tailwind \(Int(v))mph (+\(Int(v))y)" }
        return "Headwind \(Int(abs(v)))mph (−\(Int(abs(v)))y)"
    }
    private func describeElevation(_ v: Double) -> String {
        if v == 0 { return "Level" }
        if v > 0 { return "Uphill \(Int(v))ft (+\(Int(v))y)" }
        return "Downhill \(Int(abs(v)))ft (−\(Int(abs(v)))y)"
    }
}

// MARK: helpers

private struct ProgressBar: View {
    var value: Double
    var color: Color
    var body: some View {
        GeometryReader { g in
            Capsule().fill(DesignTokens.muted.opacity(0.6))
                .overlay(alignment: .leading) {
                    Capsule().fill(color).frame(width: max(0, g.size.width * value))
                }
        }
    }
}

private struct UnitNumberField: View {
    var label: String
    var valueYards: Double
    var unit: DistanceUnit
    var onCommit: (Double) -> Void

    @State private var text: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).eyebrow()
            TextField("", text: $text)
                .keyboardType(.decimalPad)
                .font(DispersionType.display(18))
                .monospacedDigit()
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
                .onAppear {
                    let display = Units.roundForUnit(Units.from(yards: valueYards, in: unit), unit: unit)
                    text = formatNumber(display, unit: unit)
                }
                .onSubmit { commit() }
                .onChange(of: text) { _, _ in commit() }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func commit() {
        let parsed = Double(text) ?? 0
        onCommit(Units.toYards(parsed, from: unit))
    }

    private func formatNumber(_ v: Double, unit: DistanceUnit) -> String {
        switch unit {
        case .yards: return "\(Int(v))"
        case .meters:
            let r = (v * 2).rounded() / 2
            return r.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(r))"
                : String(format: "%.1f", r)
        }
    }
}

private struct SliderRow: View {
    var label: String
    var value: Double
    var range: ClosedRange<Double>
    var step: Double
    var describe: (Double) -> String
    var onChange: (Double) -> Void

    @State private var local: Double

    init(
        label: String,
        value: Double,
        range: ClosedRange<Double>,
        step: Double,
        describe: @escaping (Double) -> String,
        onChange: @escaping (Double) -> Void
    ) {
        self.label = label
        self.value = value
        self.range = range
        self.step = step
        self.describe = describe
        self.onChange = onChange
        self._local = State(initialValue: value)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).eyebrow()
                Spacer()
                Text(describe(local))
                    .font(DispersionType.mono(11))
                    .foregroundStyle(DesignTokens.foreground.opacity(0.8))
            }
            DSlider(value: $local, in: range, step: step)
                .onChange(of: local) { _, new in onChange(new) }
        }
    }
}
