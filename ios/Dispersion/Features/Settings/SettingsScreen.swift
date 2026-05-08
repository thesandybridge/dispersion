// Port of app/src/routes/settings.tsx.

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

    private enum StatusKind { case ok, err }

    public init() {}

    public var body: some View {
        ZStack {
            DesignTokens.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    hero
                    VStack(alignment: .leading, spacing: 16) {
                        unitsGroup
                        themeGroup
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
        .alert("Delete all clubs?", isPresented: $clearConfirm) {
            Button("Delete all", role: .destructive) { clearAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes every club. Cannot be undone.")
        }
        .onAppear { dial.setActions([]) }
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
                        Button { settings.setThemeAccent(a) } label: {
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
                    }
                }
            }
        }
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

    private func clearAll() {
        do {
            try ClubsRepo(context: modelContext).deleteAll()
            try ShotsRepo(context: modelContext).deleteAll()
            try SessionsRepo(context: modelContext).deleteAll()
            try FaceStrikesRepo(context: modelContext).deleteAll()
            status = (.ok, "All data cleared.")
        } catch {
            status = (.err, String(describing: error))
        }
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
