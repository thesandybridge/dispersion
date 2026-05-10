// Club create/edit sheet. Matches the app-wide .dispersionSheet design.

import SwiftData
import SwiftUI

public struct ClubEditSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeAccent) private var accent
    @State private var settings = SettingsStore.shared

    let initial: Club?
    let onClose: () -> Void

    @State private var name: String = ""
    @State private var carry: Double = 165
    @State private var carrySd: Double = 6
    @State private var lateralSd: Double = 8
    @State private var deleteConfirm: Bool = false
    @State private var saveError: String?

    public init(initial: Club?, onClose: @escaping () -> Void) {
        self.initial = initial
        self.onClose = onClose
    }

    private var unit: DistanceUnit { settings.unit }
    private var isEditing: Bool { initial != nil }
    private var isPutter: Bool {
        let n = name.lowercased()
        return n.contains("putter") || n.contains("ptr")
    }
    private var canSave: Bool {
        let nameOk = !name.trimmingCharacters(in: .whitespaces).isEmpty
        if isPutter { return nameOk }
        return nameOk && carry > 0 && carrySd > 0 && lateralSd > 0
    }

    public var body: some View {
        DSheetContainer {
            // Header
            DSheetHeader(
                eyebrow: isEditing ? "Editing" : "New club",
                title: isEditing ? (initial?.name ?? "Club") : "Add a club"
            )

            // Fields
            sheetField(isPutter ? "Putter name" : "Club name") {
                BufferedTextField(
                    isPutter ? "e.g. Scotty Cameron, Odyssey" : "e.g. 7 Iron, Driver, Putter",
                    value: $name,
                    capitalization: .words
                )
            }

            if !isPutter {
                // Preview
                preview

                sheetField("Carry distance (\(unit.label))", hint: "Average full-swing carry") {
                    NumericField("165", value: $carry, precision: 1)
                }

                HStack(spacing: 12) {
                    sheetField("σ long (\(unit.label))", hint: "Carry spread") {
                        NumericField("6", value: $carrySd, precision: 1)
                    }
                    sheetField("σ lateral (\(unit.label))", hint: "Left/right") {
                        NumericField("8", value: $lateralSd, precision: 1)
                    }
                }

                Text("Not sure about σ? Start with 4–8 for carry and 5–10 for lateral. Measure real values in Range mode.")
                    .font(DispersionType.ui(12))
                    .foregroundStyle(DesignTokens.mutedForeground)
            }

            // Actions
            VStack(spacing: 10) {
                if let saveError {
                    DInlineError(saveError)
                }

                Button { save() } label: {
                    Text(isEditing ? "Save changes" : "Add club")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.dispersion(.primary, size: .lg))
                .disabled(!canSave)

                if isEditing {
                    Button { deleteConfirm = true } label: {
                        Text("Delete club")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.dispersion(.destructive, size: .default))
                }
            }
        }
        .onAppear {
            if let c = initial {
                name = c.name
                carry = Units.from(yards: c.carryYards, in: unit)
                carrySd = Units.from(yards: c.carrySd, in: unit)
                lateralSd = Units.from(yards: c.lateralSd, in: unit)
            }
        }
        .confirmAction("Delete \(initial?.name ?? "club")?", isPresented: $deleteConfirm,
                       message: "This removes the club and cannot be undone.",
                       confirmLabel: "Delete", danger: true) {
            delete()
        }
    }

    // MARK: - Preview card

    private var preview: some View {
        let yardsCarry = Units.toYards(carry, from: unit)
        let yardsCarrySd = Units.toYards(carrySd, from: unit)
        let yardsLateral = Units.toYards(lateralSd, from: unit)
        return HStack(alignment: .center, spacing: 12) {
            DispersionViz(
                carry: yardsCarry,
                carrySd: yardsCarrySd,
                lateralSd: yardsLateral,
                distanceToTarget: yardsCarry,
                background: DesignTokens.backgroundDeep
            )
            .frame(width: 90, height: 110)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(name.isEmpty ? "Club name" : name)
                    .font(DispersionType.display(20, weight: .regular))
                    .foregroundStyle(DesignTokens.cream)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text("\(Int(carry))\(unit.label)")
                        .font(DispersionType.mono(12, weight: .medium))
                    Text("σ↕\(String(format: "%.1f", carrySd))")
                        .font(DispersionType.mono(10))
                    Text("σ↔\(String(format: "%.1f", lateralSd))")
                        .font(DispersionType.mono(10))
                }
                .foregroundStyle(DesignTokens.cream.opacity(0.55))
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DesignTokens.backgroundDeep)
        )
    }

    // MARK: - Reusable field

    private func sheetField<Content: View>(_ label: String, hint: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).eyebrow()
            content()
                .font(DispersionType.ui(16))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(DesignTokens.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(DesignTokens.border, lineWidth: 1)
                        )
                )
            if let hint {
                Text(hint)
                    .font(DispersionType.ui(11))
                    .foregroundStyle(DesignTokens.mutedForeground)
                    .padding(.leading, 2)
            }
        }
    }

    // MARK: - Actions

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard canSave else { return }
        let repo = ClubsRepo(context: modelContext)
        let yC = isPutter ? 0 : Units.toYards(carry, from: unit)
        let yCS = isPutter ? 0.5 : Units.toYards(carrySd, from: unit)
        let yLS = isPutter ? 0.5 : Units.toYards(lateralSd, from: unit)
        do {
            if let id = initial?.id {
                try repo.update(id: id, patch: .init(
                    name: trimmed, carryYards: yC, carrySd: yCS, lateralSd: yLS
                ))
            } else {
                try repo.create(Club(
                    id: UUID().uuidString.lowercased(),
                    name: trimmed, carryYards: yC, carrySd: yCS, lateralSd: yLS
                ))
            }
            saveError = nil
            Haptics.success()
            onClose()
        } catch {
            saveError = "Couldn't save: \(error.localizedDescription)"
            Haptics.error()
        }
    }

    private func delete() {
        guard let id = initial?.id else { return }
        do {
            try ClubsRepo(context: modelContext).delete(id: id)
            Haptics.medium()
            onClose()
        } catch {
            saveError = "Couldn't delete: \(error.localizedDescription)"
            Haptics.error()
        }
    }

}
