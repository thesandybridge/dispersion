// Live debug stats overlay — toggled from Settings > Developer > Debug overlay.

import SwiftData
import SwiftUI

struct DebugOverlay: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var clubModels: [ClubModel]
    @Query private var shotModels: [ShotModel]
    @Query private var sessionModels: [SessionModel]

    @State private var settings = SettingsStore.shared
    @State private var session = SessionStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            row("Clubs", "\(clubModels.count)")
            row("Shots", "\(shotModels.count)")
            row("Sessions", "\(sessionModels.count)")
            row("Unit", settings.unit.label)
            row("Active", session.active?.kind.rawValue ?? "none")
            row("Theme", settings.themeAccent.rawValue)
        }
        .font(.system(size: 9, design: .monospaced))
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(DesignTokens.popover)
                        )
        .padding(.leading, 8)
        .padding(.top, 52)
        .allowsHitTesting(false)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .foregroundStyle(.white.opacity(0.45))
                .frame(width: 52, alignment: .trailing)
            Text(value)
                .foregroundStyle(.white.opacity(0.8))
        }
    }
}
