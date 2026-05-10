// Animated splash screen — shows on cold launch with logo, tagline, version.

import SwiftUI

struct SplashScreen: View {
    @State private var logoOpacity: Double = 0
    @State private var taglineOpacity: Double = 0
    @State private var detailsOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.6
    @State private var finished = false

    var onFinished: () -> Void

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [DesignTokens.ink, DesignTokens.pine, DesignTokens.backgroundDeep],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo mark — dispersion rings + reticle
                ZStack {
                    // Outer rings
                    ForEach(0..<5) { i in
                        Circle()
                            .strokeBorder(
                                DesignTokens.primary.opacity(0.08 + Double(i) * 0.06),
                                lineWidth: 1
                            )
                            .frame(width: CGFloat(180 - i * 28), height: CGFloat(180 - i * 28))
                    }
                    .scaleEffect(ringScale)

                    // Reticle
                    VStack(spacing: 0) {
                        Rectangle().fill(Color.white.opacity(0.5)).frame(width: 1, height: 16)
                        Spacer().frame(height: 6)
                        Rectangle().fill(Color.white.opacity(0.5)).frame(width: 1, height: 16)
                    }
                    .frame(height: 38)
                    .opacity(logoOpacity)

                    HStack(spacing: 0) {
                        Rectangle().fill(Color.white.opacity(0.5)).frame(width: 16, height: 1)
                        Spacer().frame(width: 6)
                        Rectangle().fill(Color.white.opacity(0.5)).frame(width: 16, height: 1)
                    }
                    .frame(width: 38)
                    .opacity(logoOpacity)

                    Circle()
                        .fill(DesignTokens.primary)
                        .frame(width: 6, height: 6)
                        .opacity(logoOpacity)
                }
                .frame(width: 180, height: 180)

                // App name
                Text("DISPERSION")
                    .font(.system(size: 24, weight: .light, design: .default))
                    .tracking(8)
                    .foregroundStyle(DesignTokens.cream)
                    .opacity(logoOpacity)
                    .padding(.top, 28)

                // Tagline
                Text("Know your miss. Pick the right club.")
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(DesignTokens.primary)
                    .opacity(taglineOpacity)
                    .padding(.top, 10)

                Spacer()

                // Bottom details
                VStack(spacing: 8) {
                    HStack(spacing: 16) {
                        detailPill("Strokes-Gained")
                        detailPill("Local-First")
                        detailPill("No Ads")
                    }

                    Text("v0.1.0")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(DesignTokens.mutedForeground.opacity(0.5))
                        .padding(.top, 4)
                }
                .opacity(detailsOpacity)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                logoOpacity = 1
                ringScale = 1
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.4)) {
                taglineOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.7)) {
                detailsOpacity = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    finished = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onFinished()
                }
            }
        }
        .opacity(finished ? 0 : 1)
    }

    private func detailPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .medium, design: .monospaced))
            .tracking(1.5)
            .foregroundStyle(DesignTokens.cream.opacity(0.4))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .overlay(
                Capsule().strokeBorder(DesignTokens.cream.opacity(0.1), lineWidth: 0.5)
            )
    }
}
