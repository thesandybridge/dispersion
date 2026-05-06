// Port of app/src/routes/settings.tsx.

import SwiftData
import SwiftUI

public struct SettingsScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var clubModels: [ClubModel]

    @State private var settings = SettingsStore.shared
    @State private var dial     = DialStore.shared

    @State private var seedConfirm: Bool = false
    @State private var clearConfirm: Bool = false
    @State private var status: (kind: StatusKind, text: String)?

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
                        dataGroup
                        developerGroup
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
                        Text("Dispersion v0.1.0 · iOS native build")
                            .font(DispersionType.mono(11))
                            .foregroundStyle(DesignTokens.mutedForeground)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 24)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }
            }
        }
        .preferredColorScheme(.dark)
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
                Text("Local-only · v0.1 · \(clubModels.count) clubs")
                    .font(DispersionType.mono(11))
                    .foregroundStyle(DesignTokens.mutedForeground)
            }
            .padding(20)
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 0))
    }

    private var unitsGroup: some View {
        SettingsGroup(label: "Units", systemImage: "ruler", accent: DesignTokens.primary) {
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
        }
    }

    private var dataGroup: some View {
        SettingsGroup(label: "Data", systemImage: "externaldrive", accent: hex("#7aa3cc")) {
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
        let repo = ClubsRepo(context: modelContext)
        do {
            try repo.deleteAll()
            try ShotsRepo(context: modelContext).deleteAll()
            status = (.ok, "All data cleared.")
        } catch {
            status = (.err, String(describing: error))
        }
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
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(DesignTokens.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(DesignTokens.border, lineWidth: 1)
                    )
            )
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
