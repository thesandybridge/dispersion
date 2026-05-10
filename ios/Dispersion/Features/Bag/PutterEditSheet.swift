// Putter create / edit sheet. Putters are not part of the Club domain so
// they get their own sheet with putter-relevant fields only — no carry, no
// σ↕/σ↔. Uses the same .dispersionSheet chrome as ClubEditSheet so the two
// sheets feel like siblings.

import SwiftData
import SwiftUI

public struct PutterEditSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeAccent) private var accent

    let initial: Putter?
    let onClose: () -> Void

    @State private var name: String = ""
    @State private var lengthInches: Double = PutterDefaults.lengthInches
    @State private var headType: PutterHeadType = PutterDefaults.headType
    @State private var loftDegrees: Double = PutterDefaults.loftDegrees
    @State private var deleteConfirm: Bool = false
    @State private var saveError: String?

    public init(initial: Putter?, onClose: @escaping () -> Void) {
        self.initial = initial
        self.onClose = onClose
    }

    private var isEditing: Bool { initial != nil }
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    public var body: some View {
        DSheetContainer {
            DSheetHeader(
                eyebrow: isEditing ? "Editing" : "New putter",
                title: isEditing ? (initial?.name ?? "Putter") : "Add a putter"
            )

            sheetField("Putter name") {
                BufferedTextField(
                    "e.g. Scotty Cameron, Odyssey",
                    value: $name,
                    capitalization: .words
                )
            }

            sheetField("Head type") {
                DToggleGroup(
                    options: PutterHeadType.allCases.map {
                        DToggleOption(value: $0, label: $0.label)
                    },
                    selection: Binding(
                        get: { headType },
                        set: { if let v = $0 { headType = v } }
                    )
                )
            }

            HStack(spacing: 12) {
                sheetField("Length", hint: "Inches") {
                    NumericField("34", value: $lengthInches, precision: 1)
                }
                sheetField("Loft", hint: "Degrees") {
                    NumericField("3", value: $loftDegrees, precision: 1)
                }
            }

            Text("Putters track make rate by distance and lag-putt proximity. They live separately from the rest of your bag — no carry or σ here.")
                .font(DispersionType.ui(12))
                .foregroundStyle(DesignTokens.mutedForeground)

            VStack(spacing: 10) {
                if let saveError {
                    DInlineError(saveError)
                }

                Button { save() } label: {
                    Text(isEditing ? "Save changes" : "Add putter")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.dispersion(.primary, size: .lg))
                .disabled(!canSave)

                if isEditing {
                    Button { deleteConfirm = true } label: {
                        Text("Delete putter")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.dispersion(.destructive, size: .default))
                }
            }
        }
        .onAppear {
            if let p = initial {
                name = p.name
                lengthInches = p.lengthInches
                headType = p.headType
                loftDegrees = p.loftDegrees
            }
        }
        .confirmAction(
            "Delete \(initial?.name ?? "putter")?",
            isPresented: $deleteConfirm,
            message: "Removes the putter and every putt logged with it. Cannot be undone.",
            confirmLabel: "Delete",
            danger: true
        ) {
            delete()
        }
    }

    private func sheetField<Content: View>(
        _ label: String,
        hint: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
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

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard canSave else { return }
        let repo = PuttersRepo(context: modelContext)
        do {
            if let id = initial?.id {
                try repo.update(id: id, patch: .init(
                    name: trimmed,
                    lengthInches: lengthInches,
                    headType: headType,
                    loftDegrees: loftDegrees
                ))
            } else {
                try repo.create(Putter(
                    id: UUID().uuidString.lowercased(),
                    name: trimmed,
                    lengthInches: lengthInches,
                    headType: headType,
                    loftDegrees: loftDegrees,
                    createdAt: .now,
                    updatedAt: .now
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
            try PuttersRepo(context: modelContext).delete(id: id)
            Haptics.medium()
            onClose()
        } catch {
            saveError = "Couldn't delete: \(error.localizedDescription)"
            Haptics.error()
        }
    }
}
