// Help topic detail view. Renders the topic's sections in a scroll view,
// showing each section's optional heading + body + visual. Visuals are
// rendered inline so the page is self-illustrating.

import SwiftUI

struct HelpTopicView: View {
    let topic: HelpTopic

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                backRow
                titleBlock

                ForEach(Array(topic.sections.enumerated()), id: \.offset) { _, section in
                    sectionView(section)
                }

                Spacer().frame(height: 80)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
        }
        .background(DesignTokens.background.ignoresSafeArea())
    }

    // MARK: - Header

    private var backRow: some View {
        HStack(alignment: .center, spacing: 4) {
            Button { dismiss(); Haptics.light() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 12))
                    Text("Help")
                        .font(DispersionType.mono(12))
                }
                .foregroundStyle(DesignTokens.mutedForeground)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.bottom, 4)
        .overlay(alignment: .bottom) { DSeparator().opacity(0.4) }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Image(systemName: topic.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(DesignTokens.primary)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(DesignTokens.primary.opacity(0.12)))
                Text(topic.title)
                    .font(DispersionType.display(28, weight: .regular))
                    .tracking(-0.56)
                    .foregroundStyle(DesignTokens.foreground)
                Spacer()
            }
            Text(topic.summary)
                .font(DispersionType.ui(14))
                .foregroundStyle(DesignTokens.mutedForeground)
                .lineSpacing(2)
        }
        .padding(.top, 4)
    }

    // MARK: - Section rendering

    @ViewBuilder
    private func sectionView(_ section: HelpSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let heading = section.heading {
                Text(heading)
                    .font(DispersionType.ui(15, weight: .semibold))
                    .foregroundStyle(DesignTokens.foreground)
            }
            if !section.body.isEmpty {
                Text(section.body)
                    .font(DispersionType.ui(14))
                    .foregroundStyle(DesignTokens.foreground.opacity(0.78))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let visual = section.visual {
                visualView(visual)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func visualView(_ visual: HelpVisual) -> some View {
        switch visual {
        case let .dispersion(carry, sd, lat, target, width, depth):
            DispersionViz(
                carry: carry,
                carrySd: sd,
                lateralSd: lat,
                distanceToTarget: target,
                zoneWidth: width,
                zoneDepth: depth,
                contours: 5,
                facets: 28,
                background: DesignTokens.ink
            )
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

        case let .iconLegend(items):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: item.icon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(DesignTokens.primary)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(DesignTokens.primary.opacity(0.10)))
                        Text(item.caption)
                            .font(DispersionType.ui(13))
                            .foregroundStyle(DesignTokens.foreground.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(12)
            .background(ThemedCardFill(cornerRadius: 12))
        }
    }
}
