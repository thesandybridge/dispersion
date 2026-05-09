// App-wide haptic feedback helpers, scaled by the user's preference in
// `SettingsStore.hapticsIntensity` and gated by `soundsEnabled` for the
// notification-style cues. Centralizes UIKit-bridge code in one place.

import Foundation
#if canImport(UIKit)
import UIKit
#endif

@MainActor
public enum Haptics {

    /// Light tap — small UI events, selection changes, drag-snap crossings.
    public static func light() {
        impact(.light)
    }

    /// Medium tap — a confirmed action (delete, switch tab, finish hole).
    public static func medium() {
        impact(.medium)
    }

    /// Heavy tap — strong confirmation (round complete, calibration save).
    public static func heavy() {
        impact(.heavy)
    }

    /// Notification "success" cue. Suppressed when haptics are off.
    public static func success() {
        notify(.success)
    }

    /// Notification "error" cue. Suppressed when haptics are off.
    public static func error() {
        notify(.error)
    }

    // MARK: - Internals

    #if canImport(UIKit)
    private static func impact(_ requested: UIImpactFeedbackGenerator.FeedbackStyle) {
        let intensity = SettingsStore.shared.hapticsIntensity
        guard let style = mappedStyle(requested: requested, intensity: intensity) else { return }
        let g = UIImpactFeedbackGenerator(style: style)
        g.impactOccurred()
    }

    private static func notify(_ kind: UINotificationFeedbackGenerator.FeedbackType) {
        guard SettingsStore.shared.hapticsIntensity != .off else { return }
        let g = UINotificationFeedbackGenerator()
        g.notificationOccurred(kind)
    }

    /// Map the call site's intent + the user's intensity preference into a
    /// concrete style. Returns `nil` to suppress the haptic entirely.
    private static func mappedStyle(
        requested: UIImpactFeedbackGenerator.FeedbackStyle,
        intensity: HapticsIntensity
    ) -> UIImpactFeedbackGenerator.FeedbackStyle? {
        switch intensity {
        case .off:
            return nil
        case .light:
            // Always tap softly, regardless of what the call site asked for.
            return .light
        case .medium:
            // Cap heavy at medium; pass through light/medium.
            return requested == .heavy ? .medium : requested
        case .full:
            return requested
        }
    }
    #else
    private static func impact(_ requested: Int) {}
    private static func notify(_ kind: Int) {}
    #endif
}
