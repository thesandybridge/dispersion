// Port of app/src/routes/clubs.tsx (the "Bag" sub-tab).
// Shows the editorial bag hero + sorted club rows + insights.

import SwiftData
import SwiftUI

public struct BagScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query(sort: \ClubModel.carryYards, order: .reverse) private var clubModels: [ClubModel]
    @Query private var allShotModels: [ShotModel]

    @State private var settings = SettingsStore.shared
    @State private var dial     = DialStore.shared

    @State private var editingClub: Club?
    @State private var detailClub: Club?
    @State private var creatingNewClub: Bool = false
    @State private var subTab: BagSubTab = .bag

    enum BagSubTab { case bag, tag }

    public init() {}

    private var clubs: [Club] { clubModels.map { $0.toValue() } }
    private var shots: [Shot] { allShotModels.map { $0.toValue() } }
    private var unit: DistanceUnit { settings.unit }

    private var isWide: Bool { sizeClass == .regular }

    public var body: some View {
        ZStack {
            DesignTokens.fairway50.ignoresSafeArea()

            if isWide {
                // iPad: side-by-side
                HStack(spacing: 0) {
                    bagListColumn
                        .frame(maxWidth: 420)
                    if let detail = detailClub {
                        ClubDetailView(
                            club: detail,
                            onBack: { withAnimation { detailClub = nil } },
                            onEdit: { editingClub = detail }
                        )
                        .frame(maxWidth: .infinity)
                        .transition(.opacity)
                    } else {
                        VStack {
                            Spacer()
                            Text("Select a club")
                                .font(DispersionType.ui(15))
                                .foregroundStyle(DesignTokens.soil900.opacity(0.4))
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            } else if let detail = detailClub {
                // iPhone: full-screen detail
                ClubDetailView(
                    club: detail,
                    onBack: { withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { detailClub = nil } },
                    onEdit: { editingClub = detail }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                bagListColumn
            }
        }
        .preferredColorScheme(.light)
        .sheet(item: $editingClub) { c in
            ClubEditSheet(initial: c, onClose: {
                editingClub = nil
                if let d = detailClub, d.id == c.id {
                    detailClub = clubs.first(where: { $0.id == d.id })
                }
            })
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
        .onAppear { registerDialActions() }
    }

    @ViewBuilder
    private var bagListColumn: some View {
        switch subTab {
        case .bag:
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerBar
                    if clubs.isEmpty {
                        emptyState
                    } else {
                        BagHero(clubs: clubs, unit: unit)
                        BagInsightStack(clubs: clubs, shots: shots, onOpen: { c in withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { detailClub = c } })
                        if clubs.count >= 2 { gappingSection }
                        clubList
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 100)
            }
        case .tag:
            VStack(spacing: 0) {
                headerBar
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                BagTagView()
            }
        }
    }

    private var headerBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your clubs")
                        .font(DispersionType.mono(10, weight: .medium))
                        .tracking(2.0)
                        .textCase(.uppercase)
                        .foregroundStyle(DesignTokens.soil900.opacity(0.55))
                    Text("My Bag")
                        .font(DispersionType.display(36, weight: .regular))
                        .tracking(-0.7)
                        .foregroundStyle(DesignTokens.soil900)
                }
                Spacer()
                Button {
                    creatingNewClub = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus").font(.system(size: 12, weight: .semibold))
                        Text("Add club").font(DispersionType.ui(13, weight: .medium))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(DesignTokens.soil900))
                    .foregroundStyle(DesignTokens.fairway50)
                }
                .buttonStyle(.plain)
                .opacity(subTab == .bag ? 1 : 0)
                .allowsHitTesting(subTab == .bag)
            }

            // Sub-tab switcher
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
                .foregroundStyle(subTab == tab ? DesignTokens.fairway50 : DesignTokens.soil900.opacity(0.6))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(subTab == tab ? DesignTokens.soil900 : DesignTokens.soil900.opacity(0.06))
                )
        }
        .buttonStyle(.plain)
    }

    @State private var gappingExpanded = false

    private var gappingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { withAnimation { gappingExpanded.toggle() } } label: {
                HStack {
                    Text("Carry gapping").eyebrow(color: DesignTokens.soil900.opacity(0.55))
                    Spacer()
                    Image(systemName: gappingExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(DesignTokens.soil900.opacity(0.4))
                }
            }
            .buttonStyle(.plain)

            if gappingExpanded {
                BagGappingChart(clubs: clubs, unit: unit)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(DesignTokens.soil900.opacity(0.07), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }
        }
    }

    private var clubList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(clubs.count) club\(clubs.count == 1 ? "" : "s")")
                Spacer()
                Text("Sorted by carry")
            }
            .font(DispersionType.mono(11))
            .foregroundStyle(DesignTokens.soil900.opacity(0.5))
            .padding(.horizontal, 4)
            .padding(.top, 8)

            VStack(spacing: 8) {
                ForEach(clubs, id: \.id) { c in
                    ClubCardRow(
                        club: c,
                        unit: unit,
                        onOpen: { withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { detailClub = c } },
                        onEdit: { editingClub = c }
                    )
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .center, spacing: 12) {
            Spacer().frame(height: 40)
            Text("◆ Empty bag")
                .font(DispersionType.mono(10, weight: .medium))
                .tracking(2.4)
                .textCase(.uppercase)
                .foregroundStyle(DesignTokens.fairwayShadow)
            Text("Tell us what's in your bag.")
                .font(DispersionType.display(36, weight: .regular))
                .tracking(-0.7)
                .multilineTextAlignment(.center)
                .foregroundStyle(DesignTokens.soil900)
            Text("The math needs at least one club. Add one yourself or seed a sample bag from Settings.")
                .font(DispersionType.ui(14))
                .foregroundStyle(DesignTokens.soil900.opacity(0.65))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            Button {
                creatingNewClub = true
            } label: {
                Text("Add a club")
                    .font(DispersionType.ui(14, weight: .medium))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(DesignTokens.soil900))
                    .foregroundStyle(DesignTokens.fairway50)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: dial actions

    private func registerDialActions() {
        dial.setActions([
            DialAction(id: "add-club", label: "Add club", systemImage: "plus", tone: .primary) {
                creatingNewClub = true
            },
        ])
    }
}

// MARK: club card row

private struct ClubCardRow: View {
    var club: Club
    var unit: DistanceUnit
    var onOpen: () -> Void
    var onEdit: () -> Void

    var body: some View {
        let cat = ClubCategoryRegistry.categorize(name: club.name, carryYards: club.carryYards)
        let style = ClubCategoryRegistry.style(for: cat)
        let carry = Int(Units.from(yards: club.carryYards, in: unit).rounded())

        HStack(spacing: 12) {
            // Brand stripe
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(LinearGradient(gradient: style.gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 4)
                .frame(maxHeight: .infinity)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(club.name)
                        .font(DispersionType.ui(16, weight: .medium))
                        .foregroundStyle(DesignTokens.soil900)
                    Text(style.label)
                        .font(DispersionType.mono(9, weight: .medium))
                        .tracking(1.5)
                        .textCase(.uppercase)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(style.accent.opacity(0.18)))
                        .foregroundStyle(style.accentDeep)
                }
                Text("σ↕ \(format(club.carrySd)) · σ↔ \(format(club.lateralSd)) \(unit.label)")
                    .font(DispersionType.mono(11))
                    .foregroundStyle(DesignTokens.soil900.opacity(0.55))
            }

            Spacer()

            DispersionGlyph(
                carrySd: club.carrySd,
                lateralSd: club.lateralSd,
                fill: style.accent,
                stroke: style.accentDeep
            )

            Text("\(carry)")
                .font(DispersionType.display(30, weight: .regular))
                .tracking(-0.75)
                .foregroundStyle(DesignTokens.soil900)
                .monospacedDigit()
                .frame(minWidth: 60, alignment: .trailing)

            Button {
                onEdit()
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .regular))
                    .padding(8)
                    .foregroundStyle(DesignTokens.soil900.opacity(0.55))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(minHeight: 64)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(DesignTokens.soil900.opacity(0.07), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { onOpen() }
    }

    private func format(_ v: Double) -> String {
        let n = Units.from(yards: v, in: unit)
        return String(format: "%.1f", n)
    }
}

// MARK: bag hero

private struct BagHero: View {
    var clubs: [Club]
    var unit: DistanceUnit

    var body: some View {
        let carries = clubs.map { Units.from(yards: $0.carryYards, in: unit) }
        let sds     = clubs.map { Units.from(yards: $0.carrySd, in: unit) }
        let avgSd   = sds.isEmpty ? 0 : sds.reduce(0, +) / Double(sds.count)
        let tightest = sds.min() ?? 0
        let minC = carries.min() ?? 0
        let maxC = carries.max() ?? 0

        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Bag overview")
                        .font(DispersionType.mono(10, weight: .medium))
                        .tracking(2.4)
                        .textCase(.uppercase)
                        .foregroundStyle(DesignTokens.heat4)
                    Text("\(clubs.count)")
                        .font(DispersionType.display(80, weight: .regular))
                        .tracking(-2.8)
                        .foregroundStyle(DesignTokens.cream)
                        .monospacedDigit() +
                    Text("  clubs")
                        .font(DispersionType.ui(20))
                        .foregroundStyle(DesignTokens.cream.opacity(0.55))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Carry range")
                        .font(DispersionType.mono(9, weight: .medium))
                        .tracking(2.2)
                        .textCase(.uppercase)
                        .foregroundStyle(DesignTokens.cream.opacity(0.5))
                    Text("\(Int(minC))–\(Int(maxC))")
                        .font(DispersionType.mono(13, weight: .medium))
                        .foregroundStyle(DesignTokens.cream)
                        .monospacedDigit() +
                    Text(" \(unit.label)")
                        .font(DispersionType.mono(10))
                        .foregroundStyle(DesignTokens.cream.opacity(0.5))
                }
            }
            .padding(.top, 4)

            CarryTickRule(carriesYards: clubs.map(\.carryYards), unit: unit)
                .padding(.top, 16)

            DSeparator()
                .padding(.vertical, 14)

            HStack(spacing: 24) {
                BagHeroStat(label: "Avg σ↕", value: String(format: "%.1f", avgSd), suffix: unit.label)
                Spacer().frame(width: 1).frame(maxHeight: .infinity).overlay(DSeparator(.vertical))
                BagHeroStat(label: "Tightest", value: String(format: "%.1f", tightest), suffix: unit.label)
            }
        }
        .padding(20)
        .background(
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [DesignTokens.pine, DesignTokens.backgroundDeep]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    gradient: Gradient(colors: [DesignTokens.bentgrass.opacity(0.32), .clear]),
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: 220
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
    }
}

private struct BagHeroStat: View {
    var label: String
    var value: String
    var suffix: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(DispersionType.mono(9, weight: .medium))
                .tracking(2.2)
                .textCase(.uppercase)
                .foregroundStyle(DesignTokens.cream.opacity(0.55))
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(DispersionType.display(24, weight: .regular))
                    .tracking(-0.36)
                    .foregroundStyle(DesignTokens.cream)
                    .monospacedDigit()
                if let suffix {
                    Text(suffix)
                        .font(DispersionType.mono(10))
                        .foregroundStyle(DesignTokens.cream.opacity(0.55))
                }
            }
        }
    }
}

// MARK: insights

private struct BagInsightStack: View {
    var clubs: [Club]
    var shots: [Shot]
    var onOpen: (Club) -> Void

    var body: some View {
        let insights = Insights.compute(clubs: clubs, shots: shots)
        if insights.isEmpty {
            EmptyView()
        } else {
            VStack(spacing: 8) {
                ForEach(insights) { ins in
                    InsightCardView(insight: ins) {
                        if let id = ins.action?.clubId, let c = clubs.first(where: { $0.id == id }) {
                            onOpen(c)
                        }
                    }
                }
            }
        }
    }
}

private struct InsightCardView: View {
    var insight: Insight
    var onTap: () -> Void

    var body: some View {
        let tone = colors(for: insight.severity)
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 10) {
                Circle().fill(tone.pin).frame(width: 8, height: 8).padding(.top, 4)
                VStack(alignment: .leading, spacing: 2) {
                    Text(insight.title)
                        .font(DispersionType.ui(13, weight: .medium))
                        .foregroundStyle(DesignTokens.soil900)
                        .multilineTextAlignment(.leading)
                    Text(insight.body)
                        .font(DispersionType.ui(12))
                        .foregroundStyle(DesignTokens.soil900.opacity(0.65))
                        .multilineTextAlignment(.leading)
                }
                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tone.bg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(tone.border, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func colors(for severity: InsightSeverity) -> (bg: Color, border: Color, pin: Color) {
        switch severity {
        case .good:
            return (
                DesignTokens.bentgrass.opacity(0.12),
                DesignTokens.bentgrass.opacity(0.45),
                DesignTokens.fairwayShadow
            )
        case .warn:
            return (
                DesignTokens.flag.opacity(0.10),
                DesignTokens.flag.opacity(0.45),
                DesignTokens.flag
            )
        case .info:
            return (
                DesignTokens.soil900.opacity(0.04),
                DesignTokens.soil900.opacity(0.12),
                DesignTokens.soil900.opacity(0.6)
            )
        }
    }
}
