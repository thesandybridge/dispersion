// Manual scorecard entry — par, yardage per tee, handicap per hole.

import SwiftData
import SwiftUI

struct ScorecardEditorSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeAccent) private var accent

    var courseId: String
    var holeCount: Int
    var onSave: () -> Void

    @State private var holes: [HoleInfo] = []
    @State private var teeNames: [String] = []
    @State private var saveError: String?

    // Which tee's yardage column is shown (compact for phone)
    @State private var selectedTee: String = "White"

    var body: some View {
        DSheetHeader(eyebrow: "Scorecard", title: "Edit pars & yardage")

        // Tee selector for yardage column
        if teeNames.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(teeNames, id: \.self) { name in
                        Button {
                            selectedTee = name
                            Haptics.light()
                        } label: {
                            Text(name)
                                .font(DispersionType.mono(10, weight: .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule().fill(selectedTee == name ? accent : DesignTokens.surface)
                                )
                                .foregroundStyle(selectedTee == name ? DesignTokens.primaryForeground : DesignTokens.foreground)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }

        ScrollView {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Text("Hole").frame(width: 36, alignment: .leading)
                    Text("Par").frame(width: 60)
                    Text("Yards" + (teeNames.count > 1 ? " (\(selectedTee))" : ""))
                        .frame(maxWidth: .infinity)
                    Text("HCP").frame(width: 50)
                }
                .font(DispersionType.mono(9, weight: .medium))
                .foregroundStyle(DesignTokens.mutedForeground)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

                ForEach(holes.indices, id: \.self) { i in
                    holeRow(index: i)
                }
            }
        }

        if let saveError {
            DInlineError(saveError)
        }

        Button { save() } label: {
            Text("Save").frame(maxWidth: .infinity)
        }
        .buttonStyle(.dispersion(.primary))
        .onAppear { loadHoles() }
    }

    private func holeRow(index i: Int) -> some View {
        HStack(spacing: 0) {
            Text("\(holes[i].holeNumber)")
                .font(DispersionType.mono(12, weight: .medium))
                .frame(width: 36, alignment: .leading)

            HStack(spacing: 4) {
                ForEach([3, 4, 5], id: \.self) { p in
                    Button {
                        holes[i].par = p
                        Haptics.light()
                    } label: {
                        Text("\(p)")
                            .font(DispersionType.mono(11, weight: .medium))
                            .frame(width: 24, height: 24)
                            .background(
                                Circle().fill(holes[i].par == p ? DesignTokens.primary : DesignTokens.surface)
                            )
                            .foregroundStyle(holes[i].par == p ? DesignTokens.primaryForeground : DesignTokens.foreground)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: 60)

            // Yardage for selected tee
            let yardageBinding = Binding<Int>(
                get: { holes[i].teeBox(named: selectedTee)?.yardage ?? 0 },
                set: { newVal in
                    if let idx = holes[i].teeBoxes.firstIndex(where: { $0.name.caseInsensitiveCompare(selectedTee) == .orderedSame }) {
                        holes[i].teeBoxes[idx].yardage = newVal
                    } else {
                        let color = TeeBox.defaultColors.first { $0.name == selectedTee }?.color ?? selectedTee.lowercased()
                        holes[i].teeBoxes.append(TeeBox(name: selectedTee, color: color, yardage: newVal))
                    }
                }
            )
            TextField("0", value: yardageBinding, format: .number)
                .keyboardType(.numberPad)
                .font(DispersionType.mono(12))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 6).fill(DesignTokens.surface))
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)

            TextField("0", value: Binding(
                get: { holes[i].handicap },
                set: { holes[i].handicap = $0 }
            ), format: .number)
            .keyboardType(.numberPad)
            .font(DispersionType.mono(12))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 6).fill(DesignTokens.surface))
            .frame(width: 50)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(i % 2 == 0 ? Color.clear : DesignTokens.surface.opacity(0.3))
    }

    private func loadHoles() {
        let infos = (try? CoursesRepo(context: modelContext).holeInfos(courseId: courseId)) ?? []
        if infos.isEmpty {
            holes = (1...holeCount).map { HoleInfo(courseId: courseId, holeNumber: $0) }
        } else {
            holes = infos
        }
        // Collect all tee names across all holes
        let names = Set(holes.flatMap { $0.teeBoxes.map(\.name) })
        teeNames = TeeBox.defaultColors.map(\.name).filter { names.contains($0) }
            + names.filter { n in !TeeBox.defaultColors.contains { $0.name == n } }.sorted()
        if teeNames.isEmpty { teeNames = ["White"] }
        if !teeNames.contains(selectedTee) { selectedTee = teeNames.first ?? "White" }
    }

    private func save() {
        let repo = CoursesRepo(context: modelContext)
        var failures = 0
        for hole in holes {
            do { try repo.upsertHoleInfo(hole) } catch { failures += 1 }
        }
        if failures > 0 {
            saveError = "Couldn't save \(failures) hole\(failures == 1 ? "" : "s"). Try again."
            Haptics.error()
            return
        }
        saveError = nil
        Haptics.success()
        onSave()
    }
}
