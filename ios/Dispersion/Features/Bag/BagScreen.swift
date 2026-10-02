// Bag screen — dark theme, matching the rest of the app.
// Clubs list with hero stats, putter section, gapping, insights.

import SwiftData
import SwiftUI

public struct BagScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.themeAccent) private var accent
    @Query(sort: \ClubModel.carryYards, order: .reverse) private var clubModels: [ClubModel]
    @Query(sort: \PutterModel.createdAt, order: .forward) private var putterModels: [PutterModel]

    @State private var settings = SettingsStore.shared
    @State private var dial = DialStore.shared

    @State private var editingClub: Club?
    @State private var editingPutter: Putter?
    @State private var creatingNewClub: Bool = false
    @State private var creatingNewPutter: Bool = false
    @State private var showingTag: Bool = false
    @State private var gappingExpanded = false
    @State private var navPath = NavigationPath()
    @State private var stats: BagStats = .empty

    public init() {}

    private var clubs: [Club] { clubModels.map { $0.toValue() } }
    /// All ClubModels are now non-putter (the one-time wipe in DispersionApp
    /// removes any legacy putter Club). Filter is kept as belt-and-braces in
    /// case a user inadvertently names a club "Putter".
    private var regularClubs: [Club] {
        clubs.filter {
            ClubCategoryRegistry.categorize(name: $0.name, carryYards: $0.carryYards) != .putter
        }
    }
    private var putter: Putter? { putterModels.first?.toValue() }
    private var unit: DistanceUnit { settings.unit }

    private var isWide: Bool { sizeClass == .regular }

    public var body: some View {
        NavigationStack(path: $navPath) {
            bagListColumn
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: Club.self) { club in
                    ClubDetailView(
                        club: club,
                        onBack: { navPath.removeLast() },
                        onEdit: { editingClub = club }
                    )
                    .toolbar(.hidden, for: .navigationBar)
                }
                .navigationDestination(for: Putter.self) { p in
                    PutterDetailView(
                        putter: p,
                        onBack: { navPath.removeLast() },
                        onEdit: { editingPutter = p }
                    )
                    .toolbar(.hidden, for: .navigationBar)
                }
        }
                .sheet(item: $editingClub) { c in
            ClubEditSheet(initial: c, onClose: { editingClub = nil })
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(DesignTokens.popover)
        }
        .sheet(item: $editingPutter) { p in
            PutterEditSheet(initial: p, onClose: { editingPutter = nil })
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(DesignTokens.popover)
        }
        .sheet(isPresented: $creatingNewClub) {
            ClubEditSheet(initial: nil, onClose: { creatingNewClub = false })
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(DesignTokens.popover)
        }
        .sheet(isPresented: $creatingNewPutter) {
            PutterEditSheet(initial: nil, onClose: { creatingNewPutter = false })
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(DesignTokens.popover)
        }
        .fullScreenCover(isPresented: $showingTag) {
            BagTagView(onClose: { showingTag = false })
        }
        .onAppear {
            registerDialActions()
            navPath = NavigationPath()
            refreshStats()
        }
        .onChange(of: clubModels.count) { _, _ in refreshStats() }
        .onChange(of: editingClub) { _, new in
            // Refresh after the edit sheet closes
            if new == nil { refreshStats() }
        }
        .onChange(of: creatingNewClub) { _, new in
            if !new { refreshStats() }
        }
    }

    private func refreshStats() {
        stats = BagStats.load(context: modelContext, clubs: clubs)
    }

    // MARK: - List column

    private var bagListColumn: some View {
        List {
            Section {
                headerBar
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            .listRowSeparator(.hidden)

            if regularClubs.isEmpty && putter == nil {
                Section {
                    emptyState
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                Section {
                    heroCard
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowSeparator(.hidden)

                Section {
                    ForEach(regularClubs, id: \.id) { club in
                        clubRow(club)
                            .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 16))
                    }
                    .onDelete { indexSet in
                        do {
                            for i in indexSet {
                                let club = regularClubs[i]
                                try ClubsRepo(context: modelContext).delete(id: club.id)
                            }
                            Haptics.medium()
                        } catch {
                            Haptics.error()
                        }
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                Section {
                    putterSection
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowSeparator(.hidden)

                if regularClubs.count >= 2 {
                    Section {
                        gappingSection
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowSeparator(.hidden)
                }

                Section {
                    bagStatsSection
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(DesignTokens.background)
    }

    // MARK: - Header

    /// Single-row header — same shape as the Course tab. Title on the left,
    /// circular action icons on the right (open bag tag, add club).
    private var headerBar: some View {
        HStack(alignment: .center) {
            Text("Your bag")
                .font(DispersionType.display(32, weight: .regular))
                .tracking(-0.7)
                .foregroundStyle(DesignTokens.foreground)
            Spacer()
            HStack(spacing: 8) {
                Button { showingTag = true; Haptics.light() } label: {
                    Image(systemName: "tag")
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(DesignTokens.surface))
                        .foregroundStyle(DesignTokens.foreground)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open bag tag")

                Button { creatingNewClub = true; Haptics.light() } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(accent))
                        .foregroundStyle(DesignTokens.primaryForeground)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add club")
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    // MARK: - Hero card

    private var heroCard: some View {
        let carries = regularClubs.map { Units.from(yards: $0.carryYards, in: unit) }
        let minC = carries.min() ?? 0
        let maxC = carries.max() ?? 0

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("KNOW YOUR DISTANCES").eyebrow(color: accent)
                Spacer()
                Text("\(regularClubs.count) clubs")
                    .font(DispersionType.ui(12, weight: .medium))
                    .foregroundStyle(DesignTokens.mutedForeground)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int(minC))–\(Int(maxC))")
                    .font(DispersionType.display(36))
                    .monospacedDigit()
                Text(unit.label + " carry range")
                    .font(DispersionType.ui(13))
                    .foregroundStyle(DesignTokens.mutedForeground)
            }
            Text("Tap a club to explore its distances and miss pattern.")
                .font(DispersionType.ui(13))
                .foregroundStyle(DesignTokens.mutedForeground)
        }
        .foregroundStyle(DesignTokens.foreground)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ThemedCardFill(cornerRadius: 20))
    }

    // MARK: - Club list

    private var clubList: some View {
        VStack(spacing: 6) {
            ForEach(regularClubs, id: \.id) { club in
                clubRow(club)
            }
        }
    }

    private func clubRow(_ club: Club) -> some View {
        let cat = ClubCategoryRegistry.categorize(name: club.name, carryYards: club.carryYards)
        let style = ClubCategoryRegistry.style(for: cat)
        let carry = Int(Units.from(yards: club.carryYards, in: unit))

        return Button {
            navPath.append(club)
            Haptics.light()
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearGradient(gradient: style.gradient, startPoint: .top, endPoint: .bottom))
                    .frame(width: 3, height: 36)
                VStack(alignment: .leading, spacing: 3) {
                    Text(club.name)
                        .font(DispersionType.ui(16, weight: .medium))
                        .foregroundStyle(DesignTokens.foreground)
                    Text("Spread \(Int(Units.from(yards: club.carrySd, in: unit).rounded())) × \(Int(Units.from(yards: club.lateralSd, in: unit).rounded())) \(unit.label)")
                        .font(DispersionType.ui(12))
                        .foregroundStyle(DesignTokens.mutedForeground)
                }
                Spacer()
                DispersionGlyph(
                    carrySd: club.carrySd,
                    lateralSd: club.lateralSd,
                    fill: style.accent.opacity(0.3),
                    stroke: accent.opacity(0.7)
                )
                .frame(width: 32, height: 24)
                Text("\(carry)")
                    .font(DispersionType.display(24, weight: .regular))
                    .foregroundStyle(DesignTokens.foreground)
                    .monospacedDigit()
                Text(unit.label)
                    .font(DispersionType.ui(12))
                    .foregroundStyle(DesignTokens.mutedForeground)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(ThemedCardFill(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Putter section

    @ViewBuilder
    private var putterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Putter").eyebrow()
            if let p = putter {
                Button {
                    navPath.append(p)
                    Haptics.light()
                } label: {
                    HStack(spacing: 12) {
                        // Same accent strip idiom as the regular club rows.
                        RoundedRectangle(cornerRadius: 2)
                            .fill(LinearGradient(
                                colors: [accent, accent.opacity(0.55)],
                                startPoint: .top, endPoint: .bottom
                            ))
                            .frame(width: 3, height: 36)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(p.name)
                                .font(DispersionType.ui(16, weight: .medium))
                                .foregroundStyle(DesignTokens.foreground)
                            HStack(spacing: 6) {
                                Text("\(Int(p.lengthInches))″ · \(p.headType.label)")
                                    .font(DispersionType.ui(12))
                                    .foregroundStyle(DesignTokens.mutedForeground)
                                let count = (try? PuttsRepo(context: modelContext).count(putterId: p.id)) ?? 0
                                if count > 0 {
                                    Text("· \(count) putts")
                                        .font(DispersionType.ui(12))
                                        .foregroundStyle(DesignTokens.mutedForeground)
                                }
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11))
                            .foregroundStyle(DesignTokens.mutedForeground.opacity(0.5))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(ThemedCardFill(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            } else {
                Button { creatingNewPutter = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 14))
                        Text("Add putter")
                            .font(DispersionType.ui(13, weight: .medium))
                    }
                    .foregroundStyle(accent)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(accent.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Gapping

    private var gappingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Carry gapping").eyebrow()
            BagGappingChart(clubs: regularClubs, unit: unit)
                .background(ThemedCardFill(cornerRadius: 14))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    // MARK: - Bag stats

    @ViewBuilder
    private var bagStatsSection: some View {
        if stats.totalShots >= 5 || stats.recentShotCount > 0 {
            VStack(alignment: .leading, spacing: 10) {
                Text("Performance").eyebrow()

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    if stats.totalShots >= AppConfig.minShotsForSGAggregate {
                        bagStatCard("Strokes gained",
                                    value: String(format: "%+.2f", stats.avgSG),
                                    sub: "per shot · \(stats.totalShots) total",
                                    color: stats.avgSG >= 0 ? DesignTokens.primary : DesignTokens.pPoor)
                    }

                    bagStatCard("Total shots",
                                value: "\(stats.totalShots)",
                                sub: "\(stats.recentShotCount) last \(AppConfig.recentActivityDays) days",
                                color: DesignTokens.foreground)

                    if let best = stats.bestClubName, let bestSG = stats.bestClubSG {
                        bagStatCard("Best club",
                                    value: best,
                                    sub: String(format: "%+.2f SG/shot", bestSG),
                                    color: DesignTokens.primary)
                    }
                    if let worst = stats.worstClubName, let worstSG = stats.worstClubSG {
                        bagStatCard("Needs work",
                                    value: worst,
                                    sub: String(format: "%+.2f SG/shot", worstSG),
                                    color: DesignTokens.pPoor)
                    }
                }
            }
        }
    }

    private func bagStatCard(_ label: String, value: String, sub: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).eyebrow()
            Text(value)
                .font(DispersionType.display(20, weight: .regular))
                .foregroundStyle(color)
                .monospacedDigit()
            Text(sub)
                .font(DispersionType.mono(9))
                .foregroundStyle(DesignTokens.mutedForeground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(ThemedCardFill(cornerRadius: 12))
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(alignment: .center, spacing: 12) {
            Spacer().frame(height: 40)
            Text("Empty bag")
                .font(DispersionType.display(28, weight: .regular))
                .foregroundStyle(DesignTokens.foreground)
            Text("Add your clubs to get started. The math needs at least one club.")
                .font(DispersionType.ui(14))
                .foregroundStyle(DesignTokens.mutedForeground)
                .multilineTextAlignment(.center)
            Button { creatingNewClub = true } label: {
                Text("Add a club")
            }
            .buttonStyle(.dispersion(.primary))
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Dial

    private func registerDialActions() {
        dial.setActions([
            DialAction(id: "add-club", label: "Add club", systemImage: "plus", tone: .primary) {
                creatingNewClub = true
            },
        ])
    }
}
