// Lightweight onboarding. The Tauri version has a 4-step walkthrough; this
// is a single screen that lets the user either seed the sample bag or start
// adding clubs manually. Both paths complete onboarding.

import SwiftData
import SwiftUI

public struct OnboardingScreen: View {
    @Environment(\.modelContext) private var modelContext
    @State private var settings = SettingsStore.shared
    @State private var presentEditSheet: Bool = false

    public var onComplete: () -> Void
    public init(onComplete: @escaping () -> Void) { self.onComplete = onComplete }

    public var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [DesignTokens.pine, DesignTokens.backgroundDeep]),
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                Spacer()
                Text("First time").eyebrow(color: DesignTokens.primary)
                Text("Tell us\nwhat's in\nyour bag.")
                    .font(DispersionType.display(56, weight: .regular))
                    .tracking(-1.4)
                    .foregroundStyle(DesignTokens.foreground)
                    .lineSpacing(-2)
                Text("Dispersion turns your shot data into a probability of landing in any zone you set. We need at least one club to do the math.")
                    .font(DispersionType.ui(14))
                    .foregroundStyle(DesignTokens.foreground.opacity(0.65))
                    .padding(.top, 4)
                Spacer()

                Button {
                    seedSampleBag()
                    settings.setOnboardingComplete(true)
                    onComplete()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Recommended").eyebrow(color: DesignTokens.background.opacity(0.55))
                            Text("Use a sample bag")
                                .font(DispersionType.ui(15, weight: .medium))
                                .foregroundStyle(DesignTokens.background)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundStyle(DesignTokens.background.opacity(0.55))
                    }
                    .padding(.horizontal, 18).padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(DesignTokens.foreground)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    settings.setOnboardingComplete(true)
                    onComplete()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("From scratch").eyebrow()
                            Text("Add clubs myself")
                                .font(DispersionType.ui(15, weight: .medium))
                                .foregroundStyle(DesignTokens.foreground)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundStyle(DesignTokens.mutedForeground)
                    }
                    .padding(.horizontal, 18).padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(DesignTokens.card)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(DesignTokens.border, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)

                Spacer().frame(height: 12)
            }
            .padding(.horizontal, 22)
        }
        .preferredColorScheme(.dark)
    }

    private func seedSampleBag() {
        let repo = ClubsRepo(context: modelContext)
        try? repo.deleteAll()
        for c in SampleBag.clubs() { try? repo.create(c) }
    }
}
