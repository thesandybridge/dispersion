// Premium bag tag — designed as a physical product (acrylic/metal).
// Portrait, near full-screen, shareable as image.

import SwiftData
import SwiftUI

struct BagTagView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClubModel.carryYards, order: .reverse) private var clubModels: [ClubModel]

    @State private var profile = ProfileStore.shared
    @State private var editing = false

    private var accent: Color { profile.accent.color }

    private var clubs: [Club] { clubModels.map { $0.toValue() } }
    private var totalShots: Int { (try? ShotsRepo(context: modelContext).countAll()) ?? 0 }
    private var avgCarrySd: Double {
        let vals = clubs.filter { $0.carryYards > 0 }.map(\.carrySd)
        return vals.isEmpty ? 5 : vals.reduce(0, +) / Double(vals.count)
    }
    private var avgLateralSd: Double {
        let vals = clubs.filter { $0.carryYards > 0 }.map(\.lateralSd)
        return vals.isEmpty ? 7 : vals.reduce(0, +) / Double(vals.count)
    }

    var body: some View {
        VStack(spacing: 0) {
            tagCard
                .padding(.horizontal, 16)
                .padding(.top, 4)

            HStack(spacing: 12) {
                Button { shareTag() } label: {
                    Image(systemName: "square.and.arrow.up").font(.system(size: 13))
                }
                .buttonStyle(.dispersion(.outline, size: .icon))

                Button { editing = true } label: {
                    Image(systemName: "pencil").font(.system(size: 13))
                }
                .buttonStyle(.dispersion(.primary, size: .icon))
            }
            .padding(.top, 12)
        }
        .padding(.bottom, 80)
        .dispersionSheet(isPresented: $editing, detents: [.large]) {
            tagEditContent
        }
    }

    // MARK: - The tag

    @MainActor
    private var tagCard: some View {
        let initials = computeInitials(profile.name)

        return VStack(spacing: 0) {
            // Grommet
            ZStack {
                Capsule()
                    .fill(LinearGradient(
                        colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .frame(width: 36, height: 14)
                Circle()
                    .fill(DesignTokens.background)
                    .frame(width: 8, height: 8)
                    .overlay(Circle().strokeBorder(accent.opacity(0.4), lineWidth: 1))
            }
            .offset(y: 4)
            .zIndex(1)

            // Main card body
            ZStack {
                // Base material — dark with subtle noise texture feel
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient(
                        colors: [hex("#1a1f1c"), hex("#141814"), hex("#0f1210")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))

                // Accent edge — thin line along the left (like metal inlay)
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [accent, accent.opacity(0.3)],
                            startPoint: .top, endPoint: .bottom
                        ))
                        .frame(width: 3)
                    Spacer()
                }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                // Inner border — metallic feel
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.12), Color.white.opacity(0.03), Color.white.opacity(0.08)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )

                // Content
                VStack(alignment: .leading, spacing: 0) {
                    // Top: brand mark
                    HStack(spacing: 6) {
                        Text("DISPERSION")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .tracking(4)
                            .foregroundStyle(accent.opacity(0.5))
                        Spacer()
                        // Monogram
                        Text(initials)
                            .font(profile.font.font(size: 14, weight: .semibold))
                            .foregroundStyle(accent)
                            .frame(width: 32, height: 32)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .strokeBorder(accent.opacity(0.3), lineWidth: 0.5)
                            )
                    }
                    .padding(.bottom, 20)

                    // Name — etched style (thin, wide tracking)
                    Text(profile.name.isEmpty ? "YOUR NAME" : profile.name.uppercased())
                        .font(.system(size: 22, weight: .light, design: .default))
                        .tracking(3)
                        .foregroundStyle(DesignTokens.cream)
                        .lineLimit(2)

                    // Home course
                    if !profile.homeCourse.isEmpty {
                        Text(profile.homeCourse.uppercased())
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .tracking(2)
                            .foregroundStyle(Color.white.opacity(0.35))
                            .padding(.top, 6)
                    }

                    // Motto
                    if !profile.motto.isEmpty {
                        Text(profile.motto)
                            .font(profile.font.font(size: 13))
                            .italic()
                            .foregroundStyle(accent.opacity(0.6))
                            .padding(.top, 12)
                    }

                    Spacer().frame(minHeight: 20)

                    // Divider line — metal accent
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [accent.opacity(0.6), accent.opacity(0.1)],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(height: 0.5)
                        .padding(.vertical, 12)

                    // Stats row — etched numbers
                    HStack(spacing: 0) {
                        tagStat("HCP", value: profile.handicap.isEmpty ? "—" : profile.handicap)
                        Spacer()
                        tagStat("CLUBS", value: "\(clubs.filter { $0.carryYards > 0 }.count)")
                        Spacer()
                        tagStat("SHOTS", value: "\(totalShots)")
                        Spacer()
                        tagStat("σ", value: String(format: "%.1f", avgCarrySd))
                    }

                    // Divider
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 0.5)
                        .padding(.vertical, 12)

                    // Footer
                    HStack {
                        // Dispersion glyph
                        DispersionGlyph(
                            carrySd: avgCarrySd,
                            lateralSd: avgLateralSd,
                            fill: accent.opacity(0.3),
                            stroke: accent.opacity(0.5)
                        )
                        .frame(width: 28, height: 18)

                        Text("σ \(String(format: "%.1f", avgCarrySd)) × \(String(format: "%.1f", avgLateralSd))")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .tracking(1)
                            .foregroundStyle(Color.white.opacity(0.3))

                        Spacer()

                        if !profile.contact.isEmpty {
                            Text(profile.contact)
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.3))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)
            }
            .frame(maxHeight: .infinity)
        }
    }

    private func tagStat(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 7, weight: .medium, design: .monospaced))
                .tracking(2)
                .foregroundStyle(accent.opacity(0.5))
            Text(value)
                .font(profile.font.font(size: 18, weight: .light))
                .foregroundStyle(DesignTokens.cream.opacity(0.85))
                .monospacedDigit()
        }
    }

    private func computeInitials(_ name: String) -> String {
        (name.isEmpty ? "—" : name)
            .split(separator: " ").prefix(2)
            .compactMap { $0.first.map { String($0).uppercased() } }
            .joined()
    }

    // MARK: - Share

    @MainActor
    private func shareTag() {
        let renderer = ImageRenderer(content:
            tagCard
                .padding(32)
                .background(DesignTokens.background)
                .frame(width: 420)
                .environment(\.colorScheme, .dark)
        )
        renderer.scale = 3
        guard let image = renderer.uiImage else { return }
        let av = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
    }

    // MARK: - Edit sheet

    @ViewBuilder
    private var tagEditContent: some View {
        DSheetHeader(eyebrow: "Bag tag", title: "Customize")

        editField("Name", placeholder: "Player name", text: Binding(
            get: { profile.name }, set: { profile.setProfile(name: $0) }
        ))
        HStack(spacing: 12) {
            editField("Handicap", placeholder: "e.g. 12", text: Binding(
                get: { profile.handicap }, set: { profile.setProfile(handicap: $0) }
            ))
            editField("Home course", placeholder: "e.g. Augusta", text: Binding(
                get: { profile.homeCourse }, set: { profile.setProfile(homeCourse: $0) }
            ))
        }
        editField("Motto", placeholder: "Keep it in the short grass", text: Binding(
            get: { profile.motto }, set: { profile.setProfile(motto: $0) }
        ))
        editField("Contact", placeholder: "Phone or email", text: Binding(
            get: { profile.contact }, set: { profile.setProfile(contact: $0) }
        ))

        // Accent
        VStack(alignment: .leading, spacing: 8) {
            Text("Accent").eyebrow()
            HStack(spacing: 10) {
                ForEach(ProfileAccent.allCases, id: \.self) { a in
                    Button { profile.setProfile(accent: a) } label: {
                        Circle().fill(a.color).frame(width: 28, height: 28)
                            .overlay {
                                if profile.accent == a {
                                    Circle().strokeBorder(.white, lineWidth: 2).frame(width: 24, height: 24)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }

        // Font
        VStack(alignment: .leading, spacing: 8) {
            Text("Font").eyebrow()
            HStack(spacing: 8) {
                ForEach(ProfileFont.allCases, id: \.self) { f in
                    Button { profile.setProfile(font: f) } label: {
                        VStack(spacing: 3) {
                            Text("Aa").font(f.font(size: 16, weight: .medium))
                                .frame(width: 48, height: 36)
                                .background(RoundedRectangle(cornerRadius: 8)
                                    .fill(profile.font == f ? DesignTokens.foreground : DesignTokens.surface))
                                .foregroundStyle(profile.font == f ? DesignTokens.background : DesignTokens.foreground)
                            Text(f.label).font(DispersionType.mono(9)).foregroundStyle(DesignTokens.mutedForeground)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }

        Button { editing = false } label: { Text("Done") }
            .buttonStyle(.dispersion(.solid))
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func editField(_ label: String, placeholder: String = "", text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).eyebrow()
            TextField(placeholder, text: text)
                .font(DispersionType.ui(15))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(DesignTokens.surface)
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(DesignTokens.border, lineWidth: 1))
                )
        }
    }
}
