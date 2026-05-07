// Port of app/src/components/range/SessionDetail.tsx. Shows all shots in a
// session, with delete actions for individual shots and the session itself.

import SwiftData
import SwiftUI

struct SessionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClubModel.carryYards, order: .reverse) private var clubModels: [ClubModel]

    var sessionId: String
    var onBack: () -> Void

    @State private var deleteSessionConfirm = false
    @State private var pendingShotDelete: String?

    private var session: Session? {
        try? SessionsRepo(context: modelContext).get(id: sessionId)
    }

    private var shots: [Shot] {
        ((try? ShotsRepo(context: modelContext).listBySession(sessionId)) ?? []).reversed()
    }

    private var clubMap: [String: Club] {
        Dictionary(uniqueKeysWithValues: clubModels.map { ($0.id, $0.toValue()) })
    }

    var body: some View {
        List {
            Section { header }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))

            if shots.isEmpty {
                Section { emptyState }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                Section {
                    ForEach(shots, id: \.id) { shot in
                        shotRow(shot)
                    }
                    .onDelete { indexSet in
                        for i in indexSet {
                            try? ShotsRepo(context: modelContext).delete(id: shots[i].id)
                        }
                        Haptics.medium()
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 16))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .alert("Delete \(session?.label ?? "this session")?", isPresented: $deleteSessionConfirm) {
            Button("Delete session", role: .destructive) { deleteSession() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Removes the session and all \(shots.count) of its shots.")
        }
        .alert("Delete this shot?", isPresented: Binding(
            get: { pendingShotDelete != nil },
            set: { if !$0 { pendingShotDelete = nil } }
        )) {
            Button("Delete", role: .destructive) { confirmDeleteShot() }
            Button("Cancel", role: .cancel) { pendingShotDelete = nil }
        } message: {
            Text("The σ values for this club will recalculate without it.")
        }
    }

    // MARK: subviews

    private var header: some View {
        let accent = session?.kind == .range ? DesignTokens.primary : DesignTokens.pMarginal
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button { onBack() } label: {
                    Text("← Back to log")
                        .font(DispersionType.mono(12))
                        .tracking(1.6)
                        .textCase(.uppercase)
                        .foregroundStyle(DesignTokens.mutedForeground)
                }
                .buttonStyle(.plain)
                Spacer()
                Button { deleteSessionConfirm = true } label: {
                    Text("Delete session")
                        .font(DispersionType.mono(11))
                        .tracking(1.6)
                        .textCase(.uppercase)
                        .foregroundStyle(DesignTokens.destructive)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(accent)
                    .frame(width: 4, height: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(session?.kind.rawValue ?? "session")
                        .eyebrow()
                    Text(session?.label ?? "Session")
                        .font(DispersionType.display(26, weight: .regular))
                        .tracking(-0.52)
                }
            }
            Text("\(formatStarted(session?.createdAt ?? .now)) · \(shots.count) shot\(shots.count == 1 ? "" : "s")")
                .font(DispersionType.mono(11))
                .foregroundStyle(DesignTokens.mutedForeground)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) { DSeparator() }
    }

    private var emptyState: some View {
        Text("No shots in this session.")
            .font(DispersionType.ui(13))
            .foregroundStyle(DesignTokens.mutedForeground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 48)
    }

    private func shotRow(_ shot: Shot) -> some View {
        let club = clubMap[shot.clubId]
        let hasLanding = !(shot.longDelta == 0 && shot.latDelta == 0)
        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(club?.name ?? "(deleted)")
                        .font(DispersionType.ui(13, weight: .medium))
                    Text("\(Int(shot.targetDistanceYards))y")
                        .font(DispersionType.mono(10))
                        .foregroundStyle(DesignTokens.mutedForeground)
                }

                HStack(spacing: 4) {
                    Text(formatTime(shot.timestamp))
                        .font(DispersionType.mono(11))
                        .foregroundStyle(DesignTokens.mutedForeground)
                    if hasLanding {
                        let longSign = shot.longDelta >= 0 ? "+" : ""
                        let side = shot.latDelta >= 0 ? "R" : "L"
                        Text("· \(longSign)\(Int(shot.longDelta)) long · \(side)\(Int(abs(shot.latDelta)))")
                            .font(DispersionType.mono(11))
                            .foregroundStyle(DesignTokens.mutedForeground)
                    }
                }

                if !shot.outcomes.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(shot.outcomes.map(\.rawValue).sorted(), id: \.self) { tag in
                            Text(tag.uppercased())
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .tracking(1)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule().fill(tagColor(tag).opacity(0.18))
                                )
                                .foregroundStyle(tagColor(tag))
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(ThemedCardFill(cornerRadius: 12))
    }

    // MARK: actions

    private func deleteSession() {
        try? ShotsRepo(context: modelContext).deleteBySession(sessionId)
        try? SessionsRepo(context: modelContext).delete(id: sessionId)
        onBack()
    }

    private func confirmDeleteShot() {
        guard let id = pendingShotDelete else { return }
        try? ShotsRepo(context: modelContext).delete(id: id)
        pendingShotDelete = nil
    }

    // MARK: formatting

    private func formatStarted(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }

    private func formatTime(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
    }

    private func tagColor(_ tag: String) -> Color {
        switch tag {
        case "in":      return DesignTokens.primary
        case "penalty": return DesignTokens.destructive
        case "left", "right": return DesignTokens.destructive
        default:        return DesignTokens.pMarginal
        }
    }
}
