// Port of the QuickLogSheet from app/src/routes/calculator.tsx.
// Outcome tags + optional exact landing entry for logging shots from the
// calculator screen.

import SwiftUI
import SwiftData

struct QuickLogSheet: View {
    var club: Club
    var distance: Double
    var onLog: (Set<ShotOutcomeTag>, LandingDelta?) -> Void

    @State private var tags: Set<ShotOutcomeTag> = []
    @State private var landing: LandingDelta?
    @State private var showLanding: Bool = false

    struct LandingDelta: Equatable {
        var lat: Double
        var long: Double
    }

    var body: some View {
        DSheetHeader(eyebrow: "Log shot", title: "\(club.name) · \(Int(distance))y target")

        VStack(spacing: 12) {
            // In-zone quick log
            Button {
                onLog([.in], landing)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                    Text("Landed in zone")
                }
            }
            .buttonStyle(.dispersion(
                tags == [.in] ? .primary : .outline,
                size: .lg
            ))
            .frame(maxWidth: .infinity)

            // Distance outcomes
            OutcomeRow(label: "Distance", items: [
                .init(tag: .short, label: "Short", systemImage: "arrow.down"),
                .init(tag: .long, label: "Long", systemImage: "arrow.up"),
            ], active: tags, onPick: toggle)

            // Lateral outcomes
            OutcomeRow(label: "Lateral", items: [
                .init(tag: .left, label: "Left", systemImage: "arrow.left"),
                .init(tag: .right, label: "Right", systemImage: "arrow.right"),
            ], active: tags, onPick: toggle)

            // Penalty toggle
            penaltyRow

            // Exact landing
            landingSection

            // Save button
            Button {
                onLog(tags, landing)
            } label: {
                if tags.isEmpty {
                    Text("Pick an outcome")
                } else {
                    let desc = tags.map(\.rawValue).sorted().joined(separator: " · ")
                    let suffix = landing != nil ? " · with landing" : ""
                    Text("Save · \(desc)\(suffix)")
                }
            }
            .buttonStyle(.dispersion(.outline, size: .lg))
            .disabled(tags.isEmpty)
            .frame(maxWidth: .infinity)

            Text("Combine tags. Penalty stacks with any miss.")
                .font(DispersionType.ui(11))
                .foregroundStyle(DesignTokens.mutedForeground)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    // MARK: subviews

    private var penaltyRow: some View {
        let isOn = tags.contains(.penalty)
        return Button { toggle(.penalty) } label: {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "xmark").font(.system(size: 13))
                    Text("Penalty").font(DispersionType.ui(13))
                }
                Spacer()
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isOn ? DesignTokens.destructive : DesignTokens.muted)
                    .frame(width: 28, height: 16)
                    .overlay(alignment: isOn ? .trailing : .leading) {
                        Circle()
                            .fill(DesignTokens.background)
                            .frame(width: 12, height: 12)
                            .padding(2)
                    }
                    .animation(.spring(response: 0.22, dampingFraction: 0.8), value: isOn)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isOn ? DesignTokens.destructive.opacity(0.15) : DesignTokens.card.opacity(0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                isOn ? DesignTokens.destructive.opacity(0.55) : DesignTokens.border,
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(isOn ? DesignTokens.destructive : DesignTokens.foreground)
    }

    @ViewBuilder
    private var landingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { showLanding.toggle() } label: {
                HStack {
                    HStack(spacing: 4) {
                        Text("Exact landing").eyebrow()
                        if let l = landing {
                            Text(landingDescription(l))
                                .font(DispersionType.mono(10))
                                .foregroundStyle(DesignTokens.primary)
                        }
                    }
                    Spacer()
                    Text(showLanding ? "hide" : (landing != nil ? "edit" : "add"))
                        .font(DispersionType.mono(10))
                        .foregroundStyle(DesignTokens.mutedForeground)
                }
            }
            .buttonStyle(.plain)

            if showLanding {
                LandingEntryFields(
                    targetYards: distance,
                    landing: $landing
                )
            }

            if landing != nil {
                Button {
                    landing = nil
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise").font(.system(size: 10))
                        Text("Clear landing")
                    }
                    .eyebrow()
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: logic

    private func toggle(_ tag: ShotOutcomeTag) {
        tags = Outcomes.toggle(in: tags, tag: tag)
    }

    private func landingDescription(_ l: LandingDelta) -> String {
        let longSign = l.long >= 0 ? "+" : ""
        let side = l.lat >= 0 ? "R" : "L"
        return "\(longSign)\(Int(l.long))y long · \(side)\(Int(abs(l.lat)))y"
    }
}

// MARK: - Outcome Row

private struct OutcomeRow: View {
    struct Item {
        var tag: ShotOutcomeTag
        var label: String
        var systemImage: String
    }

    var label: String
    var items: [Item]
    var active: Set<ShotOutcomeTag>
    var onPick: (ShotOutcomeTag) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).eyebrow()
            HStack(spacing: 8) {
                ForEach(items, id: \.tag) { item in
                    let isOn = active.contains(item.tag)
                    Button { onPick(item.tag) } label: {
                        HStack(spacing: 6) {
                            Image(systemName: item.systemImage).font(.system(size: 13))
                            Text(item.label).font(DispersionType.ui(13))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(isOn ? DesignTokens.destructive.opacity(0.15) : DesignTokens.card.opacity(0.4))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(
                                            isOn ? DesignTokens.destructive.opacity(0.55) : DesignTokens.border,
                                            lineWidth: 1
                                        )
                                )
                        )
                        .foregroundStyle(isOn ? DesignTokens.destructive : DesignTokens.foreground)
                        .fontWeight(isOn ? .semibold : .regular)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Landing Entry Fields

private struct LandingEntryFields: View {
    var targetYards: Double
    @Binding var landing: QuickLogSheet.LandingDelta?

    @State private var carryStr: String = ""
    @State private var lateralStr: String = "0"
    @State private var side: Side = .right

    enum Side { case left, right }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Carry (yd)").eyebrow()
                TextField("", text: $carryStr)
                    .keyboardType(.decimalPad)
                    .font(DispersionType.display(16))
                    .monospacedDigit()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(DesignTokens.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(DesignTokens.border, lineWidth: 1)
                            )
                    )
                    .onSubmit { commit() }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Lateral (yd)").eyebrow()
                HStack(spacing: 6) {
                    TextField("", text: $lateralStr)
                        .keyboardType(.decimalPad)
                        .font(DispersionType.display(16))
                        .monospacedDigit()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(DesignTokens.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(DesignTokens.border, lineWidth: 1)
                                )
                        )
                        .onSubmit { commit() }

                    HStack(spacing: 0) {
                        sideButton("L", selected: side == .left) { side = .left; commit() }
                        sideButton("R", selected: side == .right) { side = .right; commit() }
                    }
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(DesignTokens.border, lineWidth: 1))
                }
            }
        }
        .onAppear {
            carryStr = "\(Int(targetYards))"
        }
    }

    private func sideButton(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(DispersionType.ui(12, weight: .medium))
                .foregroundStyle(selected ? DesignTokens.background : DesignTokens.mutedForeground)
                .frame(width: 28, height: 32)
                .background(selected ? DesignTokens.foreground : Color.clear)
        }
        .buttonStyle(.plain)
    }

    private func commit() {
        guard let carry = Double(carryStr), let lat = Double(lateralStr) else { return }
        let longDelta = carry - targetYards
        let latYards = side == .left ? -lat : lat
        landing = .init(lat: latYards, long: longDelta)
    }
}
