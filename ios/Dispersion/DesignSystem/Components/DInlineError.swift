// Inline error pill — used near save/delete buttons to surface failures
// that previously got swallowed by silent catch blocks.

import SwiftUI

public struct DInlineError: View {
    public var message: String

    public init(_ message: String) {
        self.message = message
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundStyle(DesignTokens.destructive)
            Text(message)
                .font(DispersionType.ui(12))
                .foregroundStyle(DesignTokens.foreground)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(DesignTokens.destructive.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(DesignTokens.destructive.opacity(0.4), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(message)")
    }
}
