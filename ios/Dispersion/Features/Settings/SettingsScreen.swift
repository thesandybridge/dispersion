// Port of app/src/routes/settings.tsx.

import SQLite3
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

public struct SettingsScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var clubModels: [ClubModel]

    @State private var settings = SettingsStore.shared
    @State private var dial     = DialStore.shared

    @State private var seedConfirm: Bool = false
    @State private var clearConfirm: Bool = false
    @State private var importerOpen: Bool = false
    @State private var exportData: ExportFile?
    @State private var status: (kind: StatusKind, text: String)?
    @State private var devTapCount: Int = 0
    @State private var showDev: Bool = false
    @State private var showHelp: Bool = false

    private enum StatusKind { case ok, err }

    public init() {}

    public var body: some View {
        ZStack {
            DesignTokens.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    hero
                    VStack(alignment: .leading, spacing: 16) {
                        helpGroup
                        unitsGroup
                        themeGroup
                        iconGroup
                        paletteGroup
                        if settings.paletteMode == .custom {
                            customPaletteGroup
                        }
                        feedbackGroup
                        conditionsTuningGroup
                        recommendationTuningGroup
                        lieMultipliersGroup
                        outlierGroup
                        storageGroup
                        dataGroup
                        if showDev { developerGroup }
                        if let status {
                            Text(status.text)
                                .font(DispersionType.ui(12))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(status.kind == .ok
                                              ? DesignTokens.primary.opacity(0.10)
                                              : DesignTokens.destructive.opacity(0.10))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .strokeBorder(
                                                    status.kind == .ok
                                                        ? DesignTokens.primary.opacity(0.30)
                                                        : DesignTokens.destructive.opacity(0.40),
                                                    lineWidth: 1
                                                )
                                        )
                                )
                                .foregroundStyle(status.kind == .ok ? DesignTokens.primary : DesignTokens.destructive)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Button {
                            devTapCount += 1
                            if devTapCount >= 7 && !showDev {
                                showDev = true
                                Haptics.success()
                                status = (.ok, "Developer mode enabled.")
                            }
                        } label: {
                            Text("Dispersion v0.1.0 · iOS native build")
                                .font(DispersionType.mono(11))
                                .foregroundStyle(DesignTokens.mutedForeground)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 24)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }
            }
        }
                .alert("Replace bag with sample?", isPresented: $seedConfirm) {
            Button("Replace") { seedSampleBag() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Wipes your bag and inserts \(SampleBag.entries.count) sample clubs.")
        }
        .alert("Delete all data?", isPresented: $clearConfirm) {
            Button("Delete all", role: .destructive) { clearAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Wipes clubs, putters, every shot, putt, session, and round. Your saved courses stay — re-add their play history yourself if you want it back. Cannot be undone.")
        }
        .onAppear { dial.setActions([]) }
        .fullScreenCover(isPresented: $showHelp) {
            HelpScreen(onClose: { showHelp = false })
        }
        .fileImporter(isPresented: $importerOpen, allowedContentTypes: [.json]) { result in
            importBackup(result)
        }
        .fileExporter(isPresented: Binding(
            get: { exportData != nil },
            set: { if !$0 { exportData = nil } }
        ), document: exportData, contentType: .json, defaultFilename: "dispersion-backup.json") { result in
            switch result {
            case .success: status = (.ok, "Backup exported.")
            case .failure(let e): status = (.err, e.localizedDescription)
            }
        }
    }

    // MARK: sections

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                gradient: Gradient(colors: [DesignTokens.ink, DesignTokens.backgroundDeep]),
                startPoint: .top, endPoint: .bottom
            )
            RadialGradient(
                gradient: Gradient(colors: [DesignTokens.bentgrass.opacity(0.32), .clear]),
                center: .topTrailing, startRadius: 0, endRadius: 220
            )
            VStack(alignment: .leading, spacing: 4) {
                Text("Settings").eyebrow(color: DesignTokens.primary)
                Text("Preferences")
                    .font(DispersionType.display(40, weight: .regular))
                    .tracking(-1)
                    .foregroundStyle(DesignTokens.foreground)
                let shotCount = (try? ShotsRepo(context: modelContext).countAll()) ?? 0
                Text("Local-only · \(clubModels.count) clubs · \(shotCount) shots")
                    .font(DispersionType.mono(11))
                    .foregroundStyle(DesignTokens.mutedForeground)
            }
            .padding(20)
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 0))
    }

    private var unitsGroup: some View {
        SettingsGroup(label: "Preferences", systemImage: "ruler", accent: DesignTokens.primary) {
            SettingsRow(label: "Appearance", helper: "Follow system or force dark/light") {
                DToggleGroup(
                    options: AppAppearance.allCases.map { DToggleOption(value: $0, label: $0.label) },
                    selection: Binding(
                        get: { settings.appearance },
                        set: { if let v = $0 { settings.setAppearance(v) } }
                    )
                )
            }
            SettingsRow(label: "Distance", helper: "Used everywhere yardage is shown") {
                DToggleGroup(
                    options: [
                        DToggleOption(value: DistanceUnit.yards, label: "Yards"),
                        DToggleOption(value: DistanceUnit.meters, label: "Meters"),
                    ],
                    selection: Binding(
                        get: { settings.unit },
                        set: { if let v = $0 { settings.setUnit(v) } }
                    )
                )
            }
            SettingsRow(label: "Handedness", helper: "Flips face strike heel/toe labels") {
                DToggleGroup(
                    options: [
                        DToggleOption(value: false, label: "Right"),
                        DToggleOption(value: true, label: "Left"),
                    ],
                    selection: Binding(
                        get: { settings.leftHanded },
                        set: { if let v = $0 { settings.setLeftHanded(v) } }
                    )
                )
            }
        }
    }

    private var themeGroup: some View {
        SettingsGroup(label: "Theme", systemImage: "paintpalette", accent: settings.themeAccent.color) {
            SettingsRow(label: "Accent color", helper: "Applied across the app") {
                HStack(spacing: 8) {
                    ForEach(ProfileAccent.allCases, id: \.self) { a in
                        Button { settings.setThemeAccent(a); Haptics.light() } label: {
                            Circle()
                                .fill(a.color)
                                .frame(width: 26, height: 26)
                                .overlay {
                                    if settings.themeAccent == a {
                                        Circle().strokeBorder(.white, lineWidth: 2)
                                            .frame(width: 22, height: 22)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(a.rawValue) accent")
                    }
                }
            }
        }
    }

    // MARK: App icon

    @State private var iconStore = AppIconStore.shared

    private var iconGroup: some View {
        SettingsGroup(label: "App icon", systemImage: "app.gift", accent: DesignTokens.bentgrass) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Pick the look on your home screen. iOS 18 dark and tint modes adapt automatically.")
                    .font(DispersionType.ui(12))
                    .foregroundStyle(DesignTokens.mutedForeground)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(AppIcon.all) { icon in
                            iconTile(icon)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func iconTile(_ icon: AppIcon) -> some View {
        let selected = iconStore.current.id == icon.id
        Button {
            Haptics.light()
            Task { await iconStore.setIcon(icon) }
        } label: {
            VStack(spacing: 6) {
                Image(icon.previewAsset)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(1, contentMode: .fit)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                selected ? DesignTokens.primary : Color.white.opacity(0.10),
                                lineWidth: selected ? 2 : 1
                            )
                    )
                Text(icon.displayName)
                    .font(DispersionType.mono(10, weight: .medium))
                    .foregroundStyle(selected ? DesignTokens.primary : DesignTokens.mutedForeground)
            }
            .frame(width: 76)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(icon.displayName) app icon\(selected ? ", selected" : "")")
    }

    // MARK: Lie multipliers

    @State private var lieStore = LieMultiplierStore.shared

    private var lieMultipliersGroup: some View {
        SettingsGroup(label: "Lie σ multipliers", systemImage: "leaf", accent: DesignTokens.bentgrass) {
            ForEach(LieType.allCases, id: \.self) { lie in
                lieMultiplierRow(lie)
            }
            // Footer: explanation + reset.
            HStack(alignment: .center, spacing: 8) {
                Text("Defaults are estimates — adjust to your game.")
                    .font(DispersionType.ui(11))
                    .foregroundStyle(DesignTokens.mutedForeground)
                Spacer()
                Button {
                    lieStore.resetAll()
                    Haptics.medium()
                } label: {
                    Text("Reset all")
                        .font(DispersionType.mono(10, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(DesignTokens.surface))
                        .foregroundStyle(DesignTokens.foreground)
                }
                .buttonStyle(.plain)
                .opacity(lieStore.overrides.isEmpty ? 0.4 : 1)
                .disabled(lieStore.overrides.isEmpty)
                .accessibilityLabel("Reset all lie multipliers to defaults")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    @ViewBuilder
    private func lieMultiplierRow(_ lie: LieType) -> some View {
        let current = lieStore.multiplier(for: lie)
        let isOverridden = lieStore.isOverridden(lie)
        let binding = Binding<Double>(
            get: { current },
            set: { lieStore.setOverride($0, for: lie) }
        )

        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                Text(lie.label)
                    .font(DispersionType.ui(13, weight: .medium))
                    .foregroundStyle(DesignTokens.foreground)
                Spacer()
                Text("×\(String(format: "%.2f", current))")
                    .font(DispersionType.mono(12, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(isOverridden ? DesignTokens.primary : DesignTokens.foreground)
                if isOverridden {
                    Button {
                        lieStore.setOverride(nil, for: lie)
                        Haptics.light()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 10, weight: .medium))
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(DesignTokens.surface))
                            .foregroundStyle(DesignTokens.mutedForeground)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Reset \(lie.label) to default")
                }
            }
            Slider(
                value: binding,
                in: LieType.multiplierRange,
                step: 0.05,
                onEditingChanged: { editing in
                    if !editing { Haptics.light() }
                }
            )
            .tint(isOverridden ? DesignTokens.primary : DesignTokens.foreground.opacity(0.6))
            .accessibilityLabel("\(lie.label) sigma multiplier")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(divider, alignment: .bottom)
    }

    private var divider: some View {
        DSeparator()
            .padding(.horizontal, 16)
            .opacity(0.4)
    }

    // MARK: Help & tutorials

    private var helpGroup: some View {
        SettingsGroup(label: "Help", systemImage: "questionmark.circle", accent: DesignTokens.primary) {
            Button { showHelp = true; Haptics.light() } label: {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Help & tutorials")
                            .font(DispersionType.ui(14, weight: .medium))
                            .foregroundStyle(DesignTokens.foreground)
                        Text("How to read the calculator, log range shots, build a course, and more.")
                            .font(DispersionType.ui(12))
                            .foregroundStyle(DesignTokens.mutedForeground)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DesignTokens.mutedForeground.opacity(0.5))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open help and tutorials")
        }
    }

    // MARK: Palette mode + custom palette

    @State private var customPalette = CustomPaletteStore.shared

    private var paletteGroup: some View {
        SettingsGroup(label: "Color theme", systemImage: "paintbrush", accent: DesignTokens.primary) {
            ForEach(PaletteMode.allCases, id: \.self) { mode in
                paletteModeRow(mode)
            }
        }
    }

    private func paletteModeRow(_ mode: PaletteMode) -> some View {
        let isActive = settings.paletteMode == mode
        let preview = (mode == .custom)
            ? customPalette.resolved()
            : Palettes.resolve(mode)

        return Button {
            // Switching INTO custom seeds it from whatever's currently active
            // so the user has a non-blank starting point.
            if mode == .custom && settings.paletteMode != .custom {
                customPalette.seed(from: settings.paletteMode)
            }
            settings.setPaletteMode(mode)
            Haptics.light()
        } label: {
            HStack(alignment: .center, spacing: 12) {
                paletteSwatch(preview)
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.label)
                        .font(DispersionType.ui(13, weight: .medium))
                        .foregroundStyle(DesignTokens.foreground)
                    Text(mode.helper)
                        .font(DispersionType.ui(11))
                        .foregroundStyle(DesignTokens.mutedForeground)
                }
                Spacer()
                if isActive {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DesignTokens.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(divider, alignment: .bottom)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(mode.label). \(mode.helper)")
        .accessibilityAddTraits(isActive ? [.isSelected, .isButton] : .isButton)
    }

    /// 5-stop horizontal swatch showing how the probability gradient reads
    /// in the given palette. Lets the user preview before switching.
    private func paletteSwatch(_ palette: Palette) -> some View {
        HStack(spacing: 2) {
            ForEach(Array([
                palette.pStrong, palette.pFavored, palette.pMarginal,
                palette.pPoor, palette.danger
            ].enumerated()), id: \.offset) { _, c in
                Rectangle().fill(c).frame(width: 8, height: 24)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
        )
    }

    // MARK: Custom palette pickers

    private var customPaletteGroup: some View {
        SettingsGroup(label: "Custom colors", systemImage: "paintpalette", accent: DesignTokens.primary) {
            ForEach(CustomPaletteStore.Section.allCases, id: \.self) { section in
                customSectionHeader(section.label)
                ForEach(CustomPaletteStore.Slot.allCases.filter { $0.section == section }, id: \.self) { slot in
                    customSlotRow(slot)
                }
            }
            HStack(spacing: 8) {
                Spacer()
                ForEach([PaletteMode.standard, .redGreenSafe, .blueYellowSafe], id: \.self) { mode in
                    Button {
                        customPalette.seed(from: mode)
                        Haptics.medium()
                    } label: {
                        Text("From \(mode.label)")
                            .font(DispersionType.mono(10, weight: .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(DesignTokens.surface))
                            .foregroundStyle(DesignTokens.foreground)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Seed custom palette from \(mode.label)")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private func customSectionHeader(_ label: String) -> some View {
        HStack {
            Text(label.uppercased())
                .font(DispersionType.mono(9, weight: .medium))
                .tracking(1.6)
                .foregroundStyle(DesignTokens.mutedForeground)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 4)
    }

    private func customSlotRow(_ slot: CustomPaletteStore.Slot) -> some View {
        let binding = Binding<Color>(
            get: { customPalette.color(for: slot) },
            set: { customPalette.setColor($0, for: slot) }
        )

        return HStack(alignment: .center, spacing: 12) {
            ColorPicker("", selection: binding, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 32, height: 32)
            Text(slot.label)
                .font(DispersionType.ui(13, weight: .medium))
                .foregroundStyle(DesignTokens.foreground)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(divider, alignment: .bottom)
    }

    // MARK: Feedback (haptics + sounds)

    private var feedbackGroup: some View {
        SettingsGroup(label: "Feedback", systemImage: "hand.tap", accent: DesignTokens.primary) {
            SettingsRow(label: "Haptics", helper: "Tactile feedback on taps and confirmations") {
                DToggleGroup(
                    options: HapticsIntensity.allCases.map {
                        DToggleOption(value: $0, label: $0.label)
                    },
                    selection: Binding(
                        get: { settings.hapticsIntensity },
                        set: { if let v = $0 { settings.setHapticsIntensity(v); Haptics.light() } }
                    )
                )
            }
            SettingsRow(label: "System sounds", helper: "Toggle off to silence success / error cues") {
                DSwitch(Binding(
                    get: { settings.soundsEnabled },
                    set: { settings.setSoundsEnabled($0) }
                ))
            }
        }
    }

    // MARK: Conditions tuning

    @State private var tuning = CalculatorTuningStore.shared

    private var conditionsTuningGroup: some View {
        SettingsGroup(label: "Conditions tuning", systemImage: "wind", accent: DesignTokens.primary) {
            tuningSliderRow(
                label: "Wind",
                helper: "Yards of distance per mph of wind",
                value: tuning.windYardsPerMph,
                range: CalculatorTuningStore.windRange,
                step: 0.05,
                defaultValue: 1.0,
                format: { "×\(String(format: "%.2f", $0))" },
                onChange: { tuning.setWindYardsPerMph($0) }
            )
            tuningSliderRow(
                label: "Elevation",
                helper: "Yards of distance per foot of elevation",
                value: tuning.elevYardsPerFoot,
                range: CalculatorTuningStore.elevRange,
                step: 0.05,
                defaultValue: 1.0,
                format: { "×\(String(format: "%.2f", $0))" },
                onChange: { tuning.setElevYardsPerFoot($0) }
            )
        }
    }

    // MARK: Recommendation tuning

    private var recommendationTuningGroup: some View {
        SettingsGroup(label: "Recommendation", systemImage: "scope", accent: DesignTokens.primary) {
            tuningSliderRow(
                label: "Short-side bias",
                helper: "Penalty on clubs that fall short of the target. Higher = aggressively prefer 'take more club'",
                value: tuning.shortSideBias,
                range: CalculatorTuningStore.biasRange,
                step: 0.01,
                defaultValue: 0.08,
                format: { String(format: "%.2f", $0) },
                onChange: { tuning.setShortSideBias($0) }
            )
        }
    }

    // MARK: Outlier threshold

    private var outlierGroup: some View {
        SettingsGroup(label: "Shot filtering", systemImage: "line.3.horizontal.decrease.circle", accent: DesignTokens.primary) {
            tuningSliderRow(
                label: "Outlier threshold",
                helper: "Shots with deltas beyond this are treated as bad data and excluded from σ math",
                value: tuning.shotOutlierYards,
                range: CalculatorTuningStore.outlierRange,
                step: 5,
                defaultValue: 100,
                format: { "\(Int($0))y" },
                onChange: { tuning.setShotOutlierYards($0) }
            )
            SettingsRow(label: "Replay tutorial", helper: "Re-show the onboarding wizard") {
                Button {
                    settings.resetOnboarding()
                    Haptics.success()
                    status = (.ok, "Tutorial will appear next launch.")
                } label: {
                    Text("Replay")
                        .font(DispersionType.mono(11, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(DesignTokens.surface))
                        .foregroundStyle(DesignTokens.foreground)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Reusable slider row used by the calculator-tuning groups. Shows the
    /// label, helper, current value pill (accent-tinted when overridden), an
    /// undo button when the value differs from the default, and a slider.
    @ViewBuilder
    private func tuningSliderRow(
        label: String,
        helper: String?,
        value: Double,
        range: ClosedRange<Double>,
        step: Double,
        defaultValue: Double,
        format: @escaping (Double) -> String,
        onChange: @escaping (Double) -> Void
    ) -> some View {
        let isOverridden = abs(value - defaultValue) > step / 2
        let binding = Binding<Double>(
            get: { value },
            set: { onChange($0) }
        )

        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(DispersionType.ui(13, weight: .medium))
                        .foregroundStyle(DesignTokens.foreground)
                    if let helper {
                        Text(helper)
                            .font(DispersionType.ui(11))
                            .foregroundStyle(DesignTokens.mutedForeground)
                    }
                }
                Spacer()
                Text(format(value))
                    .font(DispersionType.mono(12, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(isOverridden ? DesignTokens.primary : DesignTokens.foreground)
                if isOverridden {
                    Button {
                        onChange(defaultValue)
                        Haptics.light()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 10, weight: .medium))
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(DesignTokens.surface))
                            .foregroundStyle(DesignTokens.mutedForeground)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Reset \(label) to default")
                }
            }
            Slider(
                value: binding,
                in: range,
                step: step,
                onEditingChanged: { editing in
                    if !editing { Haptics.light() }
                }
            )
            .tint(isOverridden ? DesignTokens.primary : DesignTokens.foreground.opacity(0.6))
            .accessibilityLabel(label)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(divider, alignment: .bottom)
    }

    private var storageGroup: some View {
        let shotCount = (try? ShotsRepo(context: modelContext).countAll()) ?? 0
        let sessionCount = ((try? SessionsRepo(context: modelContext).list()) ?? []).count
        let courseCount = ((try? CoursesRepo(context: modelContext).list()) ?? []).count
        let roundCount = ((try? CoursesRepo(context: modelContext).rounds()) ?? []).count
        let dbSize = databaseSize()

        return SettingsGroup(label: "Storage", systemImage: "internaldrive", accent: DesignTokens.primary) {
            SettingsRow(label: "Database size", helper: nil) {
                Text(dbSize).font(DispersionType.mono(12)).foregroundStyle(DesignTokens.foreground)
            }
            SettingsRow(label: "Clubs", helper: nil) {
                Text("\(clubModels.count)").font(DispersionType.mono(12)).foregroundStyle(DesignTokens.foreground)
            }
            SettingsRow(label: "Shots logged", helper: nil) {
                Text("\(shotCount)").font(DispersionType.mono(12)).foregroundStyle(DesignTokens.foreground)
            }
            SettingsRow(label: "Sessions", helper: nil) {
                Text("\(sessionCount)").font(DispersionType.mono(12)).foregroundStyle(DesignTokens.foreground)
            }
            SettingsRow(label: "Courses", helper: nil) {
                Text("\(courseCount)").font(DispersionType.mono(12)).foregroundStyle(DesignTokens.foreground)
            }
            SettingsRow(label: "Rounds played", helper: nil) {
                Text("\(roundCount)").font(DispersionType.mono(12)).foregroundStyle(DesignTokens.foreground)
            }
        }
    }

    private func databaseSize() -> String {
        guard let url = modelContext.container.configurations.first?.url else { return "—" }
        let fm = FileManager.default
        var total: Int64 = 0
        // SwiftData uses SQLite with WAL — check main + WAL + SHM files
        for suffix in ["", "-wal", "-shm"] {
            let path = url.path + suffix
            if let attrs = try? fm.attributesOfItem(atPath: path),
               let size = attrs[.size] as? Int64 {
                total += size
            }
        }
        if total == 0 { return "—" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: total)
    }

    private var dataGroup: some View {
        SettingsGroup(label: "Data", systemImage: "externaldrive", accent: hex("#7aa3cc")) {
            SettingsActionRow(
                icon: "square.and.arrow.up",
                label: "Export backup",
                value: "Full",
                helper: "Clubs, shots, courses, rounds — everything as JSON"
            ) {
                exportBackup()
            }
            SettingsActionRow(
                icon: "square.and.arrow.down",
                label: "Import backup",
                value: "JSON",
                helper: "Replaces all data with a backup file"
            ) {
                importerOpen = true
            }
            SettingsActionRow(
                icon: "trash",
                label: "Clear all data",
                value: "\(clubModels.count) club\(clubModels.count == 1 ? "" : "s")",
                helper: "Removes every club. Cannot be undone.",
                danger: true
            ) {
                clearConfirm = true
            }
        }
    }

    private var developerGroup: some View {
        SettingsGroup(label: "Developer", systemImage: "wrench.and.screwdriver", accent: DesignTokens.pMarginal) {
            SettingsRow(label: "Debug overlay", helper: "Shows live state in the corner") {
                DSwitch(Binding(
                    get: { settings.debugOverlay },
                    set: { settings.setDebugOverlay($0) }
                ))
            }
            SettingsActionRow(
                icon: "testtube.2",
                label: "Seed sample bag",
                value: "\(SampleBag.entries.count) clubs",
                helper: "Replace your bag with a realistic starter set"
            ) {
                seedConfirm = true
            }
            SettingsActionRow(
                icon: "arrow.counterclockwise",
                label: "Replay onboarding",
                value: "↗",
                helper: "Show the first-run flow next launch"
            ) {
                settings.resetOnboarding()
                status = (.ok, "Onboarding will show next time.")
            }
        }
    }

    // MARK: actions

    private func seedSampleBag() {
        let repo = ClubsRepo(context: modelContext)
        do {
            try repo.deleteAll()
            for c in SampleBag.clubs() { try repo.create(c) }
            status = (.ok, "Seeded sample bag.")
        } catch {
            status = (.err, String(describing: error))
        }
    }

    /// Wipe every piece of personal play data — clubs, putters, every shot,
    /// putt, session, face strike, and recorded round. Course definitions
    /// (CourseModel + holes + polygons) are preserved deliberately because
    /// they're hand-built and tedious to recreate; the user can clear those
    /// individually from the Course tab.
    private func clearAll() {
        do {
            try ClubsRepo(context: modelContext).deleteAll()
            try ShotsRepo(context: modelContext).deleteAll()
            try SessionsRepo(context: modelContext).deleteAll()
            try FaceStrikesRepo(context: modelContext).deleteAll()
            try PuttersRepo(context: modelContext).deleteAll()
            try PuttsRepo(context: modelContext).deleteAll()

            // Round play history — RoundModel rows are play data, not part
            // of the course definition. Clear them; the Course / Polygon /
            // HoleInfo records that define the course stay.
            let coursesRepo = CoursesRepo(context: modelContext)
            for r in (try? coursesRepo.rounds()) ?? [] {
                try? coursesRepo.deleteRound(id: r.id)
            }

            // Active session pointer (if any) is now stale — clear it.
            SessionStore.shared.clear()

            // Reclaim disk space — SQLite holds onto freed pages until
            // VACUUM is run, so deletes alone don't shrink the file on
            // disk. Best-effort: if SwiftData has a lock we can't get,
            // we at least truncate the WAL.
            vacuumPersistentStore()

            status = (.ok, "All data cleared. Courses preserved.")
        } catch {
            status = (.err, String(describing: error))
        }
    }

    /// Run VACUUM + WAL checkpoint on the SwiftData SQLite store to
    /// actually reclaim disk space after large deletes. Opens a parallel
    /// sqlite3 connection because SwiftData doesn't expose the underlying
    /// DB. Both operations are best-effort — failures (e.g., a busy lock)
    /// leave the store intact, just not vacuumed.
    private func vacuumPersistentStore() {
        guard let url = modelContext.container.configurations.first?.url else { return }
        // Force any pending SwiftData writes through before we open a
        // second connection to the same file.
        try? modelContext.save()

        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else { return }
        defer { sqlite3_close(db) }
        sqlite3_exec(db, "PRAGMA wal_checkpoint(TRUNCATE);", nil, nil, nil)
        sqlite3_exec(db, "VACUUM;", nil, nil, nil)
    }

    private func exportBackup() {
        let clubs = (try? ClubsRepo(context: modelContext).list()) ?? []
        let sessions = (try? SessionsRepo(context: modelContext).list()) ?? []
        let shots = (try? ShotsRepo(context: modelContext).listAll()) ?? []
        var allStrikes: [FaceStrike] = []
        for c in clubs { allStrikes += (try? FaceStrikesRepo(context: modelContext).listByClub(c.id)) ?? [] }
        let coursesRepo = CoursesRepo(context: modelContext)
        let courses = (try? coursesRepo.list()) ?? []
        var allHoleInfos: [HoleInfo] = []
        var allPolygons: [CoursePolygon] = []
        for c in courses {
            allHoleInfos += (try? coursesRepo.holeInfos(courseId: c.id)) ?? []
            allPolygons += (try? coursesRepo.polygons(courseId: c.id)) ?? []
        }
        let data = Backup.build(
            clubs: clubs, sessions: sessions, shots: shots,
            faceStrikes: allStrikes,
            courses: courses, holeInfos: allHoleInfos, polygons: allPolygons
        )
        exportData = ExportFile(data: data)
    }

    private func importBackup(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let e):
            status = (.err, e.localizedDescription)
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else {
                status = (.err, "Cannot access file.")
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                let data = try Data(contentsOf: url)
                let parsed = try Backup.parse(data)
                // Replace all data
                try ClubsRepo(context: modelContext).deleteAll()
                try SessionsRepo(context: modelContext).deleteAll()
                try ShotsRepo(context: modelContext).deleteAll()
                try FaceStrikesRepo(context: modelContext).deleteAll()
                let coursesRepo = CoursesRepo(context: modelContext)
                for c in (try? coursesRepo.list()) ?? [] {
                    try? coursesRepo.deleteCourse(id: c.id)
                }
                let clubsRepo = ClubsRepo(context: modelContext)
                for c in parsed.clubs { try clubsRepo.create(c) }
                let sessionsRepo = SessionsRepo(context: modelContext)
                for s in parsed.sessions { try sessionsRepo.create(s) }
                let shotsRepo = ShotsRepo(context: modelContext)
                for s in parsed.shots { try shotsRepo.create(s) }
                let strikesRepo = FaceStrikesRepo(context: modelContext)
                for f in parsed.faceStrikes { try strikesRepo.create(f) }
                for c in parsed.courses { try coursesRepo.createCourse(c) }
                for h in parsed.holeInfos { try coursesRepo.upsertHoleInfo(h) }
                if !parsed.polygons.isEmpty { try coursesRepo.insertPolygons(parsed.polygons) }
                var msg = "Imported \(parsed.clubs.count) clubs, \(parsed.courses.count) courses, \(parsed.shots.count) shots."
                if !parsed.warnings.isEmpty {
                    msg += " (\(parsed.warnings.count) items skipped)"
                }
                status = (.ok, msg)
            } catch {
                status = (.err, error.localizedDescription)
            }
        }
    }
}

// MARK: - File document for export

struct ExportFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// MARK: settings primitives

private struct SettingsGroup<Content: View>: View {
    var label: String
    var systemImage: String
    var accent: Color
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(accent)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(DesignTokens.muted.opacity(0.6)))
                Text(label.uppercased())
                    .font(DispersionType.mono(11, weight: .medium))
                    .tracking(2.0)
                    .foregroundStyle(DesignTokens.mutedForeground)
            }
            .padding(.bottom, 6)
            VStack(spacing: 0) {
                content()
            }
            .background(ThemedCardFill(cornerRadius: 16))
        }
        .padding(.top, 8)
    }
}

private struct SettingsRow<Trailing: View>: View {
    var label: String
    var helper: String?
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(DispersionType.ui(14, weight: .medium))
                    .foregroundStyle(DesignTokens.foreground)
                if let helper {
                    Text(helper)
                        .font(DispersionType.ui(12))
                        .foregroundStyle(DesignTokens.mutedForeground)
                }
            }
            Spacer()
            trailing()
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(divider, alignment: .bottom)
    }

    private var divider: some View {
        DSeparator()
            .padding(.horizontal, 16)
            .opacity(0.4)
    }
}

private struct SettingsActionRow: View {
    var icon: String
    var label: String
    var value: String
    var helper: String?
    var danger: Bool = false
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(danger ? DesignTokens.destructive : DesignTokens.foreground.opacity(0.8))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(DesignTokens.muted.opacity(0.5)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(DispersionType.ui(14, weight: .medium))
                        .foregroundStyle(danger ? DesignTokens.destructive : DesignTokens.foreground)
                    if let helper {
                        Text(helper)
                            .font(DispersionType.ui(12))
                            .foregroundStyle(DesignTokens.mutedForeground)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer()
                HStack(spacing: 4) {
                    Text(value)
                        .font(DispersionType.mono(11))
                        .foregroundStyle(DesignTokens.mutedForeground)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(DesignTokens.mutedForeground.opacity(0.6))
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}
