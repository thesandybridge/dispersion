// Bag screen — dark theme, matching the rest of the app.
// Clubs list with hero stats, putter section, gapping, insights.

import SwiftData
import SwiftUI

public struct BagScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.themeAccent) private var accent
    @Query(sort: \ClubModel.carryYards, order: .reverse) private var clubModels: [ClubModel]
    @Query private var allShotModels: [ShotModel]

    @State private var settings = SettingsStore.shared
    @State private var dial = DialStore.shared

    @State private var editingClub: Club?
    @State private var creatingNewClub: Bool = false
    @State private var subTab: BagSubTab = .bag
    @State private var gappingExpanded = false
    @State private var navPath = NavigationPath()

    enum BagSubTab { case bag, tag }

    public init() {}

    private var clubs: [Club] { clubModels.map { $0.toValue() } }
    private var regularClubs: [Club] { clubs.filter { ClubCategoryRegistry.categorize(name: $0.name, carryYards: $0.carryYards) != .putter } }
    private var putter: Club? { clubs.first { ClubCategoryRegistry.categorize(name: $0.name, carryYards: $0.carryYards) == .putter } }
    private var shots: [Shot] { allShotModels.map { $0.toValue() } }
    private var unit: DistanceUnit { settings.unit }

    private var isWide: Bool { sizeClass == .regular }

    public var body: some View {
        NavigationStack(path: $navPath) {
            bagListColumn
                .navigationBarHidden(true)
                .navigationDestination(for: Club.self) { club in
                    ClubDetailView(
                        club: club,
                        onBack: { navPath.removeLast() },
                        onEdit: { editingClub = club }
                    )
                    .navigationBarHidden(true)
                }
        }
        .preferredColorScheme(.dark)
        .sheet(item: $editingClub) { c in
            ClubEditSheet(initial: c, onClose: { editingClub = nil })
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $creatingNewClub) {
            ClubEditSheet(initial: nil, onClose: { creatingNewClub = false })
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
        .onAppear {
            registerDialActions()
            subTab = .bag
            navPath = NavigationPath()
        }
    }

    // MARK: - List column

    @ViewBuilder
    private var bagListColumn: some View {
        switch subTab {
        case .bag:
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerBar
                    if regularClubs.isEmpty && putter == nil {
                        emptyState
                    } else {
                        heroCard
                        clubList
                        putterSection
                        if regularClubs.count >= 2 { gappingSection }
                        bagStatsSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 100)
            }
        case .tag:
            VStack(spacing: 0) {
                headerBar.padding(.horizontal, 16).padding(.top, 12)
                BagTagView()
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Text("My Bag")
                    .font(DispersionType.display(32, weight: .regular))
                    .tracking(-0.7)
                    .foregroundStyle(DesignTokens.foreground)
                Spacer()
                Button { creatingNewClub = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(10)
                        .background(Circle().fill(accent))
                        .foregroundStyle(DesignTokens.primaryForeground)
                }
                .buttonStyle(.plain)
                .opacity(subTab == .bag ? 1 : 0)
                .allowsHitTesting(subTab == .bag)
            }
            HStack(spacing: 4) {
                subTabButton("Bag", tab: .bag)
                subTabButton("Tag", tab: .tag)
            }
        }
    }

    private func subTabButton(_ label: String, tab: BagSubTab) -> some View {
        Button { subTab = tab; Haptics.light() } label: {
            Text(label)
                .font(DispersionType.ui(13, weight: .medium))
                .foregroundStyle(subTab == tab ? DesignTokens.primaryForeground : DesignTokens.mutedForeground)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(subTab == tab ? accent : DesignTokens.surface))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Hero card

    private var heroCard: some View {
        let carries = regularClubs.map { Units.from(yards: $0.carryYards, in: unit) }
        let avgSd = regularClubs.isEmpty ? 0 : regularClubs.map { $0.carrySd }.reduce(0, +) / Double(regularClubs.count)
        let minC = carries.min() ?? 0
        let maxC = carries.max() ?? 0

        return HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(regularClubs.count)")
                    .font(DispersionType.display(40, weight: .regular))
                    .foregroundStyle(DesignTokens.foreground)
                    .monospacedDigit()
                Text("clubs")
                    .font(DispersionType.mono(10))
                    .foregroundStyle(DesignTokens.mutedForeground)
            }
            DSeparator(.vertical).frame(height: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(Int(minC))–\(Int(maxC))\(unit.label)")
                    .font(DispersionType.mono(13, weight: .medium))
                    .foregroundStyle(DesignTokens.foreground)
                Text("carry range")
                    .font(DispersionType.mono(10))
                    .foregroundStyle(DesignTokens.mutedForeground)
            }
            DSeparator(.vertical).frame(height: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: "%.1f", avgSd))
                    .font(DispersionType.mono(13, weight: .medium))
                    .foregroundStyle(DesignTokens.foreground)
                Text("avg σ↕")
                    .font(DispersionType.mono(10))
                    .foregroundStyle(DesignTokens.mutedForeground)
            }
            Spacer()
        }
        .padding(16)
        .background(ThemedCardFill(cornerRadius: 16))
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
                        .font(DispersionType.ui(15, weight: .medium))
                        .foregroundStyle(DesignTokens.foreground)
                    Text("σ↕\(String(format: "%.1f", club.carrySd)) · σ↔\(String(format: "%.1f", club.lateralSd))")
                        .font(DispersionType.mono(10))
                        .foregroundStyle(DesignTokens.mutedForeground)
                }
                Spacer()
                Text("\(carry)")
                    .font(DispersionType.display(24, weight: .regular))
                    .foregroundStyle(DesignTokens.foreground)
                    .monospacedDigit()
                Text(unit.label)
                    .font(DispersionType.mono(10))
                    .foregroundStyle(DesignTokens.mutedForeground)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(ThemedCardFill(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { editingClub = club } label: { Label("Edit", systemImage: "pencil") }
            Button(role: .destructive) {
                try? ClubsRepo(context: modelContext).delete(id: club.id)
                Haptics.medium()
            } label: { Label("Delete", systemImage: "trash") }
        }
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
                        Image(systemName: "circle.bottomhalf.filled")
                            .font(.system(size: 16))
                            .foregroundStyle(accent)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(p.name)
                                .font(DispersionType.ui(15, weight: .medium))
                                .foregroundStyle(DesignTokens.foreground)
                            let shotCount = shots.filter { $0.clubId == p.id }.count
                            Text("\(shotCount) shots logged")
                                .font(DispersionType.mono(10))
                                .foregroundStyle(DesignTokens.mutedForeground)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11))
                            .foregroundStyle(DesignTokens.mutedForeground.opacity(0.5))
                    }
                    .padding(14)
                    .background(ThemedCardFill(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            } else {
                Button { creatingNewClub = true } label: {
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
            Button { withAnimation { gappingExpanded.toggle() } } label: {
                HStack {
                    Text("Carry gapping").eyebrow()
                    Spacer()
                    Image(systemName: gappingExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(DesignTokens.mutedForeground.opacity(0.5))
                }
            }
            .buttonStyle(.plain)

            if gappingExpanded {
                BagGappingChart(clubs: regularClubs, unit: unit)
                    .background(ThemedCardFill(cornerRadius: 14))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }
        }
    }

    // MARK: - Bag stats

    @ViewBuilder
    private var bagStatsSection: some View {
        let allFilteredShots = shots.filter { abs($0.longDelta) < 100 && abs($0.latDelta) < 100 }
        let sg = StrokesGained.aggregate(allFilteredShots)
        let last30 = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
        let recent = allFilteredShots.filter { $0.timestamp >= last30 }

        if sg.shotCount >= 5 || !recent.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Performance").eyebrow()

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    if sg.shotCount >= 2 {
                        bagStatCard("Strokes gained",
                                    value: String(format: "%+.2f", sg.avgSG),
                                    sub: "per shot · \(sg.shotCount) total",
                                    color: sg.avgSG >= 0 ? DesignTokens.primary : DesignTokens.pPoor)
                    }

                    bagStatCard("Total shots",
                                value: "\(allFilteredShots.count)",
                                sub: "\(recent.count) last 30 days",
                                color: DesignTokens.foreground)

                    // Per-club breakdown: best SG club
                    let clubSGs = regularClubs.compactMap { club -> (Club, Double)? in
                        let clubShots = allFilteredShots.filter { $0.clubId == club.id }
                        let csg = StrokesGained.aggregate(clubShots)
                        guard csg.shotCount >= 3 else { return nil }
                        return (club, csg.avgSG)
                    }
                    if let best = clubSGs.max(by: { $0.1 < $1.1 }) {
                        bagStatCard("Best club",
                                    value: best.0.name,
                                    sub: String(format: "%+.2f SG/shot", best.1),
                                    color: DesignTokens.primary)
                    }
                    if let worst = clubSGs.min(by: { $0.1 < $1.1 }) {
                        bagStatCard("Needs work",
                                    value: worst.0.name,
                                    sub: String(format: "%+.2f SG/shot", worst.1),
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
