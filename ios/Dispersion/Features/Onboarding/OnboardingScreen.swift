// 4-step onboarding wizard: Hello, MathPrimer, FirstClub, Ready.

import SwiftData
import SwiftUI

public struct OnboardingScreen: View {
    @Environment(\.modelContext) private var modelContext
    @State private var settings = SettingsStore.shared
    @State private var step: Int = 1
    @State private var carryValue: Double = 150

    public var onComplete: () -> Void
    public init(onComplete: @escaping () -> Void) { self.onComplete = onComplete }

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [DesignTokens.ink, DesignTokens.pine, DesignTokens.backgroundDeep],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress bar
                progressBar
                    .padding(.horizontal, 22)
                    .padding(.top, 12)

                // Content
                ScrollView(showsIndicators: false) {
                    Group {
                        switch step {
                        case 1: stepHello
                        case 2: stepMathPrimer
                        case 3: stepFirstClub
                        case 4: stepReady
                        default: stepHello
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 32)
                    .padding(.bottom, 120)
                }

                // Footer buttons
                footer
                    .padding(.horizontal, 22)
                    .padding(.bottom, 20)
            }
        }
            }

    // MARK: - Progress

    private var progressBar: some View {
        HStack(spacing: 4) {
            ForEach(1...4, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? DesignTokens.primary : DesignTokens.muted)
                    .frame(height: 3)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: step)
            }
        }
    }

    // MARK: - Step 1: Hello

    private var stepHello: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer().frame(height: 40)
            Text("Dispersion")
                .eyebrow(color: DesignTokens.primary)
            Text("Hit the club ")
                .font(DispersionType.display(40, weight: .regular))
                .tracking(-1)
                .foregroundStyle(DesignTokens.foreground) +
            Text("most likely")
                .font(DispersionType.display(40, weight: .regular))
                .tracking(-1)
                .italic()
                .foregroundStyle(DesignTokens.primary) +
            Text(" to land where you want it.")
                .font(DispersionType.display(40, weight: .regular))
                .tracking(-1)
                .foregroundStyle(DesignTokens.foreground)

            Text("A probability-first club selector for serious amateurs. You teach it your dispersion. It does the math.")
                .font(DispersionType.ui(15))
                .foregroundStyle(DesignTokens.foreground.opacity(0.6))
                .lineSpacing(3)
                .padding(.top, 8)
        }
    }

    // MARK: - Step 2: Math Primer

    private var stepMathPrimer: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How it thinks")
                .eyebrow(color: DesignTokens.primary)
            Text("Every shot is a distribution. Not a number.")
                .font(DispersionType.display(32, weight: .regular))
                .tracking(-0.8)
                .foregroundStyle(DesignTokens.foreground)

            DispersionViz(
                carry: 150,
                carrySd: 6,
                lateralSd: 8,
                distanceToTarget: 150,
                zoneWidth: 25,
                zoneDepth: 25,
                contours: 5,
                facets: 28,
                background: DesignTokens.ink
            )
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Text("We model carry and lateral as independent normals, then compute the probability your shot lands in your safe zone.")
                .font(DispersionType.ui(14))
                .foregroundStyle(DesignTokens.foreground.opacity(0.6))
                .lineSpacing(3)

            Text("Bigger zone, more clubs qualify. Tighter zone, fewer.")
                .font(DispersionType.ui(14))
                .foregroundStyle(DesignTokens.primary.opacity(0.8))
                .lineSpacing(3)

            HStack(spacing: 20) {
                primerStat(label: "σ↕", desc: "Carry spread", example: "4–8y typical")
                primerStat(label: "σ↔", desc: "Lateral spread", example: "5–10y typical")
            }
            .padding(.top, 8)
        }
    }

    private func primerStat(label: String, desc: String, example: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(DispersionType.display(24, weight: .regular))
                .foregroundStyle(DesignTokens.primary)
            Text(desc)
                .font(DispersionType.ui(12, weight: .medium))
                .foregroundStyle(DesignTokens.foreground)
            Text(example)
                .font(DispersionType.mono(10))
                .foregroundStyle(DesignTokens.mutedForeground)
        }
    }

    // MARK: - Step 3: First Club

    private var stepFirstClub: some View {
        let unit = settings.unit
        let display = Units.roundForUnit(Units.from(yards: carryValue, in: unit), unit: unit)
        let minV: Double = unit == .yards ? 80 : 70
        let maxV: Double = unit == .yards ? 280 : 260

        return VStack(alignment: .leading, spacing: 16) {
            Text("Add your first club")
                .eyebrow(color: DesignTokens.primary)
            Text("Start with your 7 iron.")
                .font(DispersionType.display(32, weight: .regular))
                .tracking(-0.8)
                .foregroundStyle(DesignTokens.foreground)

            VStack(spacing: 8) {
                Text("Average carry")
                    .eyebrow()
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(display))")
                        .font(DispersionType.display(64, weight: .regular))
                        .tracking(-2)
                        .foregroundStyle(DesignTokens.foreground)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: display))
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: display)
                    Text(unit.label)
                        .font(DispersionType.display(20, weight: .regular))
                        .foregroundStyle(DesignTokens.mutedForeground)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 20)

            DSlider(
                value: Binding(
                    get: { Units.from(yards: carryValue, in: unit) },
                    set: { carryValue = Units.toYards($0, from: unit) }
                ),
                in: minV...maxV,
                step: 1
            )

            HStack {
                Text("\(Int(minV))\(unit.label)")
                Spacer()
                Text("\(Int(maxV))\(unit.label)")
            }
            .font(DispersionType.mono(10))
            .foregroundStyle(DesignTokens.mutedForeground)

            Text("Don't overthink it. We'll dial in your dispersion using Range mode, or you can edit by feel later.")
                .font(DispersionType.ui(13))
                .foregroundStyle(DesignTokens.foreground.opacity(0.5))
                .padding(.top, 8)
        }
    }

    // MARK: - Step 4: Ready

    private var stepReady: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer().frame(height: 20)
            Text("Ready")
                .eyebrow(color: DesignTokens.primary)
            Text("Your bag is local. Your data is yours.")
                .font(DispersionType.display(32, weight: .regular))
                .tracking(-0.8)
                .foregroundStyle(DesignTokens.foreground)

            Text("Everything stays on this device. Export to JSON anytime. No accounts, no cloud, no telemetry.")
                .font(DispersionType.ui(14))
                .foregroundStyle(DesignTokens.foreground.opacity(0.6))
                .lineSpacing(3)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 12) {
                featureRow("Local-first storage")
                featureRow("Export / import as JSON")
                featureRow("Build course maps from satellite imagery")
                featureRow("Calibrate your clubs at the range")
                featureRow("Track rounds with GPS shot logging")
            }
            .padding(.top, 12)

            HStack(spacing: 14) {
                Button {
                    seedSampleBag()
                    finish()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Recommended").eyebrow(color: DesignTokens.background.opacity(0.55))
                        Text("Use a sample bag")
                            .font(DispersionType.ui(14, weight: .medium))
                            .foregroundStyle(DesignTokens.background)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(DesignTokens.foreground)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    finish()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("From scratch").eyebrow()
                        Text("Add myself")
                            .font(DispersionType.ui(14, weight: .medium))
                            .foregroundStyle(DesignTokens.foreground)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(ThemedCardFill(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 12)
        }
    }

    private func featureRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            Circle().fill(DesignTokens.primary).frame(width: 6, height: 6)
            Text(text)
                .font(DispersionType.ui(14))
                .foregroundStyle(DesignTokens.foreground.opacity(0.75))
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if step > 1 {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        step -= 1
                    }
                    Haptics.light()
                } label: {
                    Text("Back")
                }
                .buttonStyle(.dispersion(.ghost))
            }
            Spacer()

            if step < 4 {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        step += 1
                    }
                    Haptics.light()
                } label: {
                    Text("Continue")
                }
                .buttonStyle(.dispersion(.primary))
            }
        }
    }

    // MARK: - Actions

    private func finish() {
        // Create the 7 iron from step 3
        let repo = ClubsRepo(context: modelContext)
        let existing = (try? repo.list()) ?? []
        if existing.isEmpty {
            _ = try? repo.create(Club(
                id: UUID().uuidString.lowercased(),
                name: "7 Iron",
                carryYards: carryValue,
                carrySd: 6,
                lateralSd: 8
            ))
        }
        settings.setOnboardingComplete(true)
        Haptics.success()
    }

    private func seedSampleBag() {
        let repo = ClubsRepo(context: modelContext)
        _ = try? repo.deleteAll()
        for c in SampleBag.clubs() { _ = try? repo.create(c) }
    }
}
