// Visual treatment for floating capsule controls overlaid on a map.
// Used by CoursePlayView and MapBuilderView header overlays so both
// screens share one look.
//
// The dark colorScheme override is intentional — these chips sit on
// satellite imagery, where light text on a dark popover capsule reads
// regardless of the user's system appearance.

import SwiftUI

private struct FloatingPillStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(.white)
            .background(
                Capsule()
                    .fill(DesignTokens.popover.opacity(0.92))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.08), lineWidth: 1))
            )
            .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
    }
}

public extension View {
    /// Renders a control as a dark-tinted floating capsule with a subtle
    /// border and drop shadow. Designed to overlay map content.
    func floatingPillStyle() -> some View {
        modifier(FloatingPillStyle())
    }
}
