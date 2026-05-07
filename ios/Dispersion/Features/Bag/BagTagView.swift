// Port of the "Tag" sub-tab from app/src/routes/clubs.tsx (BagTagPanel +
// BagTag). Full-height dark card with strap, monogram, stats, and share.

import SwiftData
import SwiftUI

struct BagTagView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClubModel.carryYards, order: .reverse) private var clubModels: [ClubModel]

    @State private var profile = ProfileStore.shared
    @State private var editing = false

    private var clubs: [Club] { clubModels.map { $0.toValue() } }

    private var totalShots: Int {
        (try? ShotsRepo(context: modelContext).countAll()) ?? 0
    }

    private var avgCarrySd: Double {
        let vals = clubs.map(\.carrySd)
        return vals.isEmpty ? 5 : vals.reduce(0, +) / Double(vals.count)
    }

    private var avgLateralSd: Double {
        let vals = clubs.map(\.lateralSd)
        return vals.isEmpty ? 7 : vals.reduce(0, +) / Double(vals.count)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    tagCard
                        .padding(.horizontal, 24)
                        .padding(.top, 16)

                    HStack(spacing: 12) {
                        Button { shareTag() } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 13, weight: .medium))
                                Text("Share")
                                    .font(DispersionType.ui(13, weight: .medium))
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(DesignTokens.soil900.opacity(0.08)))
                            .foregroundStyle(DesignTokens.soil900)
                        }
                        .buttonStyle(.plain)

                        Button { editing = true } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 13, weight: .medium))
                                Text("Customize")
                                    .font(DispersionType.ui(13, weight: .medium))
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(DesignTokens.soil900))
                            .foregroundStyle(DesignTokens.fairway50)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 100)
            }
        }
        .dispersionSheet(isPresented: $editing, detents: [.large]) {
            tagEditContent
        }
    }

    // MARK: - Tag Card (dark, full-width)

    @MainActor
    private var tagCard: some View {
        let accent = profile.accent.color
        let mat = profile.material
        let initials = computeInitials(profile.name)

        return VStack(spacing: 0) {
            // Strap
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient(
                        colors: [mat.strapTop, mat.strapBottom],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .frame(width: 44, height: 28)
                    .overlay {
                        Circle()
                            .fill(mat.grommet)
                            .frame(width: 10, height: 10)
                            .shadow(color: .black.opacity(0.5), radius: 1, y: 1)
                    }
                    .shadow(color: .black.opacity(0.25), radius: 2, y: 2)
            }
            .offset(y: 6)
            .zIndex(1)

            // Card body
            ZStack(alignment: .leading) {
                // Card background
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(
                        colors: [hex("#1f2a23"), hex("#131c16"), hex("#0d1410")],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .shadow(color: .black.opacity(0.32), radius: 24, y: 12)
                    .shadow(color: .black.opacity(0.18), radius: 8, y: 4)

                // Left accent bar
                HStack(spacing: 0) {
                    LinearGradient(colors: [accent, accent.opacity(0.5)], startPoint: .top, endPoint: .bottom)
                        .frame(width: 5)
                    Spacer()
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                // Dispersion watermark
                DispersionGlyph(
                    carrySd: avgCarrySd,
                    lateralSd: avgLateralSd,
                    fill: accent.opacity(0.08),
                    stroke: accent.opacity(0.12)
                )
                .frame(width: 160, height: 160)
                .rotationEffect(.degrees(-12))
                .offset(x: 180, y: 80)
                .clipped()

                // Content
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Dispersion · Bag tag")
                                .font(DispersionType.mono(10, weight: .medium))
                                .tracking(2.4)
                                .textCase(.uppercase)
                                .foregroundStyle(accent)

                            Text(profile.name.isEmpty ? "Set your name" : profile.name)
                                .font(profile.font.font(size: 36, weight: profile.font == .mono ? .medium : .regular))
                                .tracking(-0.72)
                                .foregroundStyle(DesignTokens.cream)
                                .lineLimit(2)

                            if !profile.homeCourse.isEmpty {
                                Text(profile.homeCourse)
                                    .font(DispersionType.mono(11))
                                    .tracking(0.4)
                                    .foregroundStyle(DesignTokens.cream.opacity(0.55))
                            }
                        }
                        Spacer()
                        // Monogram
                        ZStack {
                            Circle()
                                .strokeBorder(accent.opacity(0.4), lineWidth: 1.5)
                            Text(initials)
                                .font(profile.font.font(size: 18, weight: .semibold))
                                .foregroundStyle(accent)
                        }
                        .frame(width: 48, height: 48)
                    }

                    // Motto
                    if !profile.motto.isEmpty {
                        Text("\"\(profile.motto)\"")
                            .font(profile.font.font(size: 15))
                            .italic()
                            .foregroundStyle(accent)
                            .padding(.top, 16)
                    }

                    // Stats row
                    HStack(spacing: 0) {
                        statCell(label: "Hcp", value: profile.handicap.isEmpty ? "—" : profile.handicap, accent: accent)
                        Spacer()
                        statCell(label: "Clubs", value: "\(clubs.count)", accent: accent)
                        Spacer()
                        statCell(label: "Shots", value: "\(totalShots)", accent: accent)
                    }
                    .padding(.top, 20)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(DesignTokens.cream.opacity(0.14))
                            .frame(height: 0.5)
                            .padding(.top, 0)
                    }

                    // Footer
                    HStack {
                        HStack(spacing: 6) {
                            DispersionGlyph(
                                carrySd: avgCarrySd,
                                lateralSd: avgLateralSd,
                                fill: accent,
                                stroke: accent
                            )
                            .frame(width: 24, height: 16)
                            Text("σ \(String(format: "%.1f", avgCarrySd)) × \(String(format: "%.1f", avgLateralSd))")
                                .font(DispersionType.mono(10))
                                .tracking(1.6)
                                .textCase(.uppercase)
                                .foregroundStyle(DesignTokens.cream.opacity(0.45))
                        }
                        Spacer()
                        if !profile.contact.isEmpty {
                            Text(profile.contact)
                                .font(DispersionType.mono(10))
                                .foregroundStyle(DesignTokens.cream.opacity(0.55))
                        }
                    }
                    .padding(.top, 14)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(DesignTokens.cream.opacity(0.08))
                            .frame(height: 0.5)
                    }
                }
                .padding(.leading, 24)
                .padding(.trailing, 20)
                .padding(.top, 28)
                .padding(.bottom, 24)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            // Corner grommet
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(mat.grommet)
                    .frame(width: 14, height: 14)
                    .shadow(color: .black.opacity(0.5), radius: 1, y: 1)
                    .overlay {
                        Circle().strokeBorder(DesignTokens.cream.opacity(0.06), lineWidth: 2)
                    }
                    .padding(.top, 12)
                    .padding(.trailing, 12)
            }
        }
    }

    private func statCell(label: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(DispersionType.mono(9, weight: .medium))
                .tracking(1.6)
                .textCase(.uppercase)
                .foregroundStyle(accent.opacity(0.7))
            Text(value)
                .font(profile.font.font(size: 22, weight: .regular))
                .foregroundStyle(DesignTokens.cream)
                .monospacedDigit()
        }
    }

    private func computeInitials(_ name: String) -> String {
        let parts = (name.isEmpty ? "—" : name)
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map { String($0).uppercased() } }
        return parts.joined()
    }

    // MARK: - Share

    @MainActor
    private func shareTag() {
        let renderer = ImageRenderer(content:
            tagCard
                .padding(24)
                .background(DesignTokens.fairway50)
                .frame(width: 400)
                .environment(\.colorScheme, .light)
        )
        renderer.scale = 3
        guard let image = renderer.uiImage else { return }
        let av = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
    }

    // MARK: - Edit Sheet Content

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

        // Accent picker
        VStack(alignment: .leading, spacing: 8) {
            Text("Accent").eyebrow()
            HStack(spacing: 10) {
                ForEach(ProfileAccent.allCases, id: \.self) { a in
                    Button { profile.setProfile(accent: a) } label: {
                        Circle()
                            .fill(a.color)
                            .frame(width: 32, height: 32)
                            .overlay {
                                if profile.accent == a {
                                    Circle().strokeBorder(.white, lineWidth: 2.5)
                                        .frame(width: 28, height: 28)
                                }
                            }
                            .shadow(color: a.color.opacity(profile.accent == a ? 0.4 : 0), radius: 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }

        // Material picker
        VStack(alignment: .leading, spacing: 8) {
            Text("Material").eyebrow()
            HStack(spacing: 8) {
                ForEach(ProfileMaterial.allCases, id: \.self) { m in
                    Button { profile.setProfile(material: m) } label: {
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(LinearGradient(
                                    colors: [m.strapTop, m.strapBottom],
                                    startPoint: .top, endPoint: .bottom
                                ))
                                .frame(width: 40, height: 40)
                                .overlay {
                                    if profile.material == m {
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .strokeBorder(.white, lineWidth: 2)
                                    }
                                }
                            Text(m.label)
                                .font(DispersionType.mono(9))
                                .foregroundStyle(DesignTokens.mutedForeground)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }

        // Font picker
        VStack(alignment: .leading, spacing: 8) {
            Text("Font").eyebrow()
            HStack(spacing: 8) {
                ForEach(ProfileFont.allCases, id: \.self) { f in
                    Button { profile.setProfile(font: f) } label: {
                        VStack(spacing: 4) {
                            Text("Aa")
                                .font(f.font(size: 16, weight: .medium))
                                .frame(width: 52, height: 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(profile.font == f
                                              ? DesignTokens.foreground : DesignTokens.muted.opacity(0.4))
                                )
                                .foregroundStyle(profile.font == f
                                                 ? DesignTokens.background : DesignTokens.foreground)
                            Text(f.label)
                                .font(DispersionType.mono(9))
                                .foregroundStyle(DesignTokens.mutedForeground)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }

        Button { editing = false } label: {
            Text("Done")
        }
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
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(DesignTokens.border, lineWidth: 1)
                        )
                )
        }
    }
}
