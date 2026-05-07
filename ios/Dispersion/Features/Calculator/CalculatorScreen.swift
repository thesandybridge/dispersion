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
    @Environment(\.themeAccent) private var accent

    @State private var zoneOpen: Bool = false
    @State private var logOpen: Bool = false
    @State private var logFlash: String?
    @State private var viewClubId: String?

    public init() {}

    private var clubs: [Club] { clubModels.map { $0.toValue() } }

    private var playingDistance: Double {
        Conditions.effectiveDistance(
            target: scenario.distance,
            windMph: scenario.windMph,
            elevationFt: scenario.elevationFt
        )
    }

    private var lieMul: Double { scenario.lie.sigmaMultiplier }

    private var adjustedClubs: [Club] {
        guard lieMul != 1 else { return clubs }
        return clubs.map {
            var c = $0
            c.carrySd *= lieMul
            c.lateralSd *= lieMul
            return c
        }
    }

    private var rankings: [ClubResult] {
        let s = ShotScenario(
            distanceToTargetYards: playingDistance,
            safeZoneWidthYards: scenario.width,
            safeZoneDepthYards: scenario.depth
        )
        return Probability.rankClubs(adjustedClubs, scenario: s)
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

            // Full-bleed dispersion — drag to change target distance
            if let club = viewedClub, let vr = viewedResult {
                DispersionViz(
                    carry: vr.expectedCarry,
                    carrySd: club.carrySd * vr.swingType.sigmaMultiplier,
                    lateralSd: club.lateralSd * vr.swingType.sigmaMultiplier,
                    distanceToTarget: scenario.distance,
                    zoneWidth: scenario.width,
                    zoneDepth: scenario.depth,
                    contours: 7,
                    facets: 28,
                    background: .clear
                )
                .ignoresSafeArea()
                .overlay {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(targetDragGesture)
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
                    if !isViewingRecommended, let club = viewedClub, let result = viewedResult {
                        viewingBanner(club: club, prob: result.probabilityInZone)
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
        .preferredColorScheme(.dark)
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

            HStack(spacing: 10) {
                Text("Distance to target").eyebrow()
                Spacer()
                Button { zoneOpen = true } label: {
                    let presetName = Presets.all.first(where: { $0.id == scenario.presetId })?.label ?? "Custom"
                    let w = Int(Units.from(yards: scenario.width, in: settings.unit))
                    let d = Int(Units.from(yards: scenario.depth, in: settings.unit))
                    HStack(spacing: 4) {
                        Text(presetName)
                            .font(DispersionType.ui(11, weight: .medium))
                        Text("\(w)w x \(d)d")
                            .font(DispersionType.mono(9))
                            .foregroundStyle(DesignTokens.mutedForeground)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.06))
                            .overlay(Capsule().strokeBorder(DesignTokens.border, lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
    }

    @State private var dragStartYards: Double = 0

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

    private var targetDragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                if dragStartYards == 0 { dragStartYards = scenario.distance }
                let ptsPerYard: CGFloat = 5
                let deltaYards = Double(-value.translation.height / ptsPerYard)
                let newYards = (dragStartYards + deltaYards).rounded()
                let clamped = max(20, min(400, newYards))
                if clamped != scenario.distance {
                    Haptics.light()
                    scenario.update(.init(distance: clamped))
                }
            }
            .onEnded { _ in
                dragStartYards = 0
            }
    }

    private var conditionsRow: some View {
        var items: [(key: String, label: String, icon: String, tone: DBadgeVariant)] = []
        if scenario.windMph != 0 {
            items.append((
                "wind",
                scenario.windMph > 0
                    ? "+\(Int(scenario.windMph)) tail"
                    : "\(Int(abs(scenario.windMph))) head",
                "wind",
                .outline
            ))
        }
        if scenario.elevationFt != 0 {
            items.append((
                "elev",
                scenario.elevationFt > 0
                    ? "+\(Int(scenario.elevationFt))ft"
                    : "\(Int(abs(scenario.elevationFt)))ft↓",
                "mountain.2",
                .outline
            ))
        }
        if scenario.lie != .fairway && scenario.lie != .tee {
            items.append(("lie", scenario.lie.label, "leaf", .outline))
        }
        if scenario.minProbability > 0 {
            let pct = Int((scenario.minProbability * 100).rounded())
            items.append((
                "thresh",
                noneQualify ? "≥\(pct)% · none qualify" : "≥\(pct)%",
                "percent",
                noneQualify ? .destructive : .outline
            ))
        }

        return Group {
            if items.isEmpty {
                EmptyView()
            } else {
                Button { zoneOpen = true } label: {
                    FlowLayout(spacing: 6, runSpacing: 6) {
                        ForEach(items, id: \.key) { item in
                            DBadge(variant: item.tone) {
                                if !item.icon.isEmpty {
                                    Image(systemName: item.icon).font(.system(size: 9))
                                }
                                Text(item.label)
                            }
                        }
                    }
                    .padding(10)
                    .background(
                        ThemedCardFill(cornerRadius: 16, opacity: 0.8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(DesignTokens.border, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func viewingBanner(club: Club, prob: Double) -> some View {
        HStack {
            HStack(spacing: 6) {
                Text("Viewing").eyebrow(color: DesignTokens.destructive)
                Text(club.name)
                    .font(DispersionType.ui(13, weight: .medium))
                Text("\(Int(prob * 100))%")
                    .font(DispersionType.mono(11))
                    .foregroundStyle(DesignTokens.mutedForeground)
            }
            Spacer()
            Button("Show recommended") { viewClubId = nil }
                .font(DispersionType.mono(10, weight: .medium))
                .tracking(1.6)
                .textCase(.uppercase)
                .foregroundStyle(accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DesignTokens.destructive.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(DesignTokens.destructive.opacity(0.4), lineWidth: 1)
                )
        )
    }

    private func recommendedCard(club: Club, result: ClubResult) -> some View {
        let lbl = ProbLabelRegistry.of(result.probabilityInZone)
        let isActive = isViewingRecommended
        return Button { viewClubId = nil } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Circle().fill(lbl.color).frame(width: 5, height: 5)
                        Text("Recommended · \(lbl.label.lowercased())")
                            .eyebrow(color: lbl.color)
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
        let lbl = ProbLabelRegistry.of(result.probabilityInZone)
        let active = viewClubId == result.id
        return Button { viewClubId = active ? nil : result.id; Haptics.light() } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(club.name)
                        .font(DispersionType.ui(13, weight: .medium))
                        .lineLimit(1)
                    if result.swingType != .full {
                        Text(result.swingType.label)
                            .font(DispersionType.mono(9, weight: .medium))
                            .foregroundStyle(lbl.color)
                    }
                }
                HStack(spacing: 6) {
                    Text("\(Int(result.expectedCarry))y")
                        .font(DispersionType.mono(10))
                        .foregroundStyle(DesignTokens.mutedForeground)
                    Text("\(Int(result.probabilityInZone * 100))%")
                        .font(DispersionType.mono(11, weight: .medium))
                        .foregroundStyle(lbl.color)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(active ? accent.opacity(0.15) : Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(active ? accent.opacity(0.4) : DesignTokens.border, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
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
                options: LieType.allCases.map {
                    DToggleOption(
                        value: $0,
                        label: $0.label,
                        trailing: $0.sigmaMultiplier == 1
                            ? nil
                            : "×\(String(format: "%.2f", $0.sigmaMultiplier))"
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
