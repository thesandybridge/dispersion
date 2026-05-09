// Help & tutorials root. Presented as a fullScreenCover from Settings; the
// internal NavigationStack lets users drill into individual topics and back out.

import SwiftUI

struct HelpScreen: View {
    var onClose: () -> Void

    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header

                    VStack(spacing: 8) {
                        ForEach(HelpContent.topics) { topic in
                            NavigationLink(value: topic) {
                                HelpTopicCard(topic: topic)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 4)

                    Spacer().frame(height: 60)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(DesignTokens.background.ignoresSafeArea())
            .navigationDestination(for: HelpTopic.self) { topic in
                HelpTopicView(topic: topic)
                    .toolbar(.hidden, for: .navigationBar)
                    .enableInteractivePop()
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Help").eyebrow()
                Text("Tutorials")
                    .font(DispersionType.display(28, weight: .regular))
                    .tracking(-0.56)
                    .foregroundStyle(DesignTokens.foreground)
            }
            Spacer()
            Button { onClose(); Haptics.light() } label: {
                Text("Done")
                    .font(DispersionType.mono(11, weight: .medium))
                    .foregroundStyle(DesignTokens.foreground)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(DesignTokens.surface))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close help")
        }
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}

private struct HelpTopicCard: View {
    let topic: HelpTopic

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: topic.icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(DesignTokens.primary)
                .frame(width: 40, height: 40)
                .background(Circle().fill(DesignTokens.primary.opacity(0.12)))

            VStack(alignment: .leading, spacing: 2) {
                Text(topic.title)
                    .font(DispersionType.ui(15, weight: .medium))
                    .foregroundStyle(DesignTokens.foreground)
                    .lineLimit(1)
                Text(topic.summary)
                    .font(DispersionType.ui(12))
                    .foregroundStyle(DesignTokens.mutedForeground)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DesignTokens.mutedForeground.opacity(0.5))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(ThemedCardFill(cornerRadius: 14))
    }
}
