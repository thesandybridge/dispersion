// Port of the ClubEditForm in app/src/routes/clubs.tsx — shown as a sheet.

import SwiftData
import SwiftUI

public struct ClubEditSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var settings = SettingsStore.shared

    let initial: Club?
    let onClose: () -> Void

    @State private var name: String = ""
    @State private var carry: Double = 165
    @State private var carrySd: Double = 6
    @State private var lateralSd: Double = 8
    @State private var deleteConfirm: Bool = false

    public init(initial: Club?, onClose: @escaping () -> Void) {
        self.initial = initial
        self.onClose = onClose
    }

    private var unit: DistanceUnit { settings.unit }
    private var isEditing: Bool { initial != nil }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                preview
                fields
                actions
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .scrollIndicators(.hidden)
        .onAppear {
            if let c = initial {
                name = c.name
                carry = Units.from(yards: c.carryYards, in: unit)
                carrySd = Units.from(yards: c.carrySd, in: unit)
                lateralSd = Units.from(yards: c.lateralSd, in: unit)
            }
        }
        .alert("Delete \(initial?.name ?? "club")?", isPresented: $deleteConfirm) {
            Button("Delete", role: .destructive) { delete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the club. Cannot be undone.")
        }
    }

    // MARK: sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(isEditing ? "Editing" : "Adding").eyebrow(color: DesignTokens.soil900.opacity(0.55))
            Text(isEditing ? (initial?.name ?? "Club") : "New club")
                .font(DispersionType.display(28, weight: .regular))
                .tracking(-0.6)
                .foregroundStyle(DesignTokens.soil900)
        }
    }

    private var preview: some View {
        let yardsCarry = Units.toYards(carry, from: unit)
        let yardsCarrySd = Units.toYards(carrySd, from: unit)
        let yardsLateral = Units.toYards(lateralSd, from: unit)
        return HStack(alignment: .top, spacing: 16) {
            DispersionViz(
                carry: yardsCarry,
                carrySd: yardsCarrySd,
                lateralSd: yardsLateral,
                distanceToTarget: yardsCarry,
                background: DesignTokens.ink
            )
            .frame(width: 140, height: 170)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 6) {
                Text("Live preview").eyebrow(color: DesignTokens.cream.opacity(0.5))
                Text("\(Int(carry))")
                    .font(DispersionType.display(36, weight: .regular))
                    .foregroundStyle(DesignTokens.cream)
                    .monospacedDigit() +
                Text(unit.label)
                    .font(DispersionType.ui(14))
                    .foregroundStyle(DesignTokens.cream.opacity(0.55))
                Text("σ↕ \(String(format: "%.1f", carrySd))  σ↔ \(String(format: "%.1f", lateralSd))")
                    .font(DispersionType.mono(11))
                    .foregroundStyle(DesignTokens.cream.opacity(0.55))
            }
            .padding(.top, 4)
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.ink)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditField(label: "Name") {
                TextField("e.g. 7 Iron", text: $name)
                    .textInputAutocapitalization(.words)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10).fill(.white)
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(DesignTokens.soil900.opacity(0.15), lineWidth: 1))
                    )
                    .foregroundStyle(DesignTokens.soil900)
            }
            EditField(label: "Carry (\(unit.label))") {
                NumberStepperField(value: $carry, range: 1...400, step: unit == .yards ? 1 : 0.5)
            }
            EditField(label: "σ↕ (\(unit.label))") {
                NumberStepperField(value: $carrySd, range: 0.1...50, step: unit == .yards ? 0.5 : 0.5)
            }
            EditField(label: "σ↔ (\(unit.label))") {
                NumberStepperField(value: $lateralSd, range: 0.1...50, step: unit == .yards ? 0.5 : 0.5)
            }
        }
    }

    private var actions: some View {
        HStack {
            if isEditing {
                Button("Delete", role: .destructive) { deleteConfirm = true }
                    .buttonStyle(.dispersion(.destructive, size: .default))
            }
            Spacer()
            Button("Cancel") { onClose() }
                .buttonStyle(.dispersion(.ghost, size: .default))
            Button(isEditing ? "Save" : "Add") { save() }
                .buttonStyle(.dispersion(.primary, size: .default))
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || carry <= 0 || carrySd <= 0 || lateralSd <= 0)
        }
        .padding(.top, 8)
    }

    // MARK: actions

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, carry > 0, carrySd > 0, lateralSd > 0 else { return }
        let repo = ClubsRepo(context: modelContext)
        let yardsCarry = Units.toYards(carry, from: unit)
        let yardsCarrySd = Units.toYards(carrySd, from: unit)
        let yardsLat = Units.toYards(lateralSd, from: unit)
        do {
            if let id = initial?.id {
                try repo.update(id: id, patch: .init(
                    name: trimmed,
                    carryYards: yardsCarry,
                    carrySd: yardsCarrySd,
                    lateralSd: yardsLat
                ))
            } else {
                try repo.create(Club(
                    id: UUID().uuidString.lowercased(),
                    name: trimmed,
                    carryYards: yardsCarry,
                    carrySd: yardsCarrySd,
                    lateralSd: yardsLat
                ))
            }
            onClose()
        } catch {
            // TODO: surface error
        }
    }

    private func delete() {
        guard let id = initial?.id else { return }
        let repo = ClubsRepo(context: modelContext)
        try? repo.delete(id: id)
        onClose()
    }
}

private struct EditField<Content: View>: View {
    var label: String
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).eyebrow(color: DesignTokens.soil900.opacity(0.55))
            content()
        }
    }
}

private struct NumberStepperField: View {
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double
    @State private var text: String = ""

    var body: some View {
        HStack(spacing: 8) {
            TextField("", text: $text)
                .keyboardType(.decimalPad)
                .font(DispersionType.display(20))
                .monospacedDigit()
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10).fill(.white)
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(DesignTokens.soil900.opacity(0.15), lineWidth: 1))
                )
                .foregroundStyle(DesignTokens.soil900)
                .onChange(of: text) { _, new in
                    if let v = Double(new) {
                        value = min(max(v, range.lowerBound), range.upperBound)
                    }
                }
            Stepper("", value: $value, in: range, step: step)
                .labelsHidden()
                .onChange(of: value) { _, new in
                    text = format(new)
                }
        }
        .onAppear { text = format(value) }
    }

    private func format(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : String(format: "%.1f", v)
    }
}
