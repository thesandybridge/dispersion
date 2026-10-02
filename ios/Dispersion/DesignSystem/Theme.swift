// Design tokens with automatic dark/light mode resolution.
// Uses UIColor trait collection so DesignTokens.background resolves
// correctly without any call-site changes.

import SwiftUI
import UIKit

// MARK: - Adaptive color helper

private func adaptive(dark: String, light: String) -> Color {
    Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? uiHex(dark) : uiHex(light)
    })
}

private func adaptive(dark: UIColor, light: UIColor) -> Color {
    Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? dark : light
    })
}

private func uiHex(_ s: String) -> UIColor {
    var h = s
    if h.hasPrefix("#") { h.removeFirst() }
    var rgb: UInt64 = 0
    Scanner(string: h).scanHexInt64(&rgb)
    return UIColor(
        red: CGFloat((rgb >> 16) & 0xFF) / 255,
        green: CGFloat((rgb >> 8) & 0xFF) / 255,
        blue: CGFloat(rgb & 0xFF) / 255, alpha: 1
    )
}

// MARK: - Design tokens

public enum DesignTokens {
    // Brand palette (fixed — same in both modes)
    public static let fairway50      = hex("#f4efe3")
    public static let bentgrass      = hex("#62b375")
    public static let fairwayShadow  = hex("#2c8a5e")
    public static let rough          = hex("#16624a")
    public static let pine           = hex("#0b3d2e")
    public static let soil900        = hex("#1a2419")
    public static let sand           = hex("#f0e7b8")
    public static let flag           = hex("#e85d4d")
    public static let water          = hex("#1f3a5f")
    public static let ink            = hex("#0e1a13")
    public static let cream          = hex("#f6f1e1")

    // Probability heatmap (fixed)
    public static let heat0 = hex("#0b3d2e")
    public static let heat1 = hex("#16624a")
    public static let heat2 = hex("#2c8a5e")
    public static let heat3 = hex("#62b375")
    public static let heat4 = hex("#a9d18e")
    public static let heat5 = hex("#f0e7b8")

    // Probability label palette (fixed)
    public static let pStrong   = hex("#62b375")
    public static let pFavored  = hex("#a9d18e")
    public static let pMarginal = hex("#e6c068")
    public static let pPoor     = hex("#c87060")
    public static let danger    = hex("#a23939")

    // Semantic — adaptive dark/light
    public static let background          = adaptive(dark: "#101a17", light: "#f8f6f0")
    public static let backgroundDeep      = adaptive(dark: "#070d0a", light: "#f0ece4")
    public static let foreground          = adaptive(dark: "#f6f1e1", light: "#1a2419")
    public static let card                = adaptive(dark: "#1b2621", light: "#ffffff")
    public static let cardForeground      = adaptive(dark: "#f6f1e1", light: "#1a2419")
    public static let popover             = adaptive(dark: "#1a2419", light: "#f4f2ec")
    public static let primary             = adaptive(dark: "#a9d18e", light: "#4a8a3c")
    public static let primaryForeground   = adaptive(dark: "#0a1410", light: "#ffffff")
    public static let secondary           = adaptive(dark: "#1f2a23", light: "#e8e4dc")
    public static let secondaryForeground = adaptive(dark: "#f6f1e1", light: "#1a2419")
    public static let muted               = adaptive(dark: "#1a2419", light: "#e8e4dc")
    public static let accent              = adaptive(dark: "#62b375", light: "#3a7a4c")
    public static let accentForeground    = adaptive(dark: "#0a1410", light: "#ffffff")
    public static let destructive         = adaptive(dark: "#e85d4d", light: "#d44030")

    // Translucent — flip white/black based on mode
    public static let border = adaptive(
        dark: UIColor.white.withAlphaComponent(0.10),
        light: UIColor.black.withAlphaComponent(0.10)
    )
    public static let borderStrong = adaptive(
        dark: UIColor.white.withAlphaComponent(0.18),
        light: UIColor.black.withAlphaComponent(0.18)
    )
    public static let surface = adaptive(
        dark: UIColor.white.withAlphaComponent(0.04),
        light: UIColor.black.withAlphaComponent(0.03)
    )
    public static let surfaceStrong = adaptive(
        dark: UIColor.white.withAlphaComponent(0.07),
        light: UIColor.black.withAlphaComponent(0.06)
    )
    public static let mutedForeground = adaptive(
        dark: UIColor.white.withAlphaComponent(0.70),
        light: UIColor.black.withAlphaComponent(0.70)
    )
    public static let subtleForeground = adaptive(
        dark: UIColor.white.withAlphaComponent(0.56),
        light: UIColor.black.withAlphaComponent(0.56)
    )

    public enum Radius {
        public static let sm: CGFloat = 6
        public static let md: CGFloat = 10
        public static let lg: CGFloat = 14
        public static let xl: CGFloat = 20
        public static let xxl: CGFloat = 28
    }
}

// MARK: Theme accent environment

private struct ThemeAccentKey: EnvironmentKey {
    static let defaultValue: Color = DesignTokens.primary
}

public extension EnvironmentValues {
    var themeAccent: Color {
        get { self[ThemeAccentKey.self] }
        set { self[ThemeAccentKey.self] = newValue }
    }
}

public extension View {
    func themeAccent(_ color: Color) -> some View {
        environment(\.themeAccent, color)
            .tint(color)
    }
}

// MARK: Themed card background

public struct ThemedCardFill: View {
    var cornerRadius: CGFloat
    var opacity: Double

    public init(cornerRadius: CGFloat = 16, opacity: Double = 1) {
        self.cornerRadius = cornerRadius
        self.opacity = opacity
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        DesignTokens.card.opacity(opacity),
                        DesignTokens.card.opacity(opacity * 0.96)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(DesignTokens.border, lineWidth: 1)
            )
    }
}

// MARK: Interactive pop gesture fix

public struct InteractivePopGesture: UIViewControllerRepresentable {
    public func makeUIViewController(context: Context) -> UIViewController {
        InteractivePopController()
    }
    public func updateUIViewController(_ vc: UIViewController, context: Context) {}
}

private class InteractivePopController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = nil
    }
}

public extension View {
    func enableInteractivePop() -> some View {
        self.background(InteractivePopGesture())
    }
}

// MARK: Edge-swipe-to-dismiss for fullScreenCovers (no NavigationController)

private struct EdgeSwipeDismiss: ViewModifier {
    var onDismiss: () -> Void
    @State private var dragOffset: CGFloat = 0
    @State private var canDrag = false

    func body(content: Content) -> some View {
        content
            .offset(x: dragOffset)
            .simultaneousGesture(
                DragGesture(minimumDistance: 8, coordinateSpace: .global)
                    .onChanged { value in
                        // Only honor drags that start at the very left edge.
                        if !canDrag {
                            canDrag = value.startLocation.x < 24
                        }
                        guard canDrag else { return }
                        dragOffset = max(0, value.translation.width)
                    }
                    .onEnded { value in
                        guard canDrag else { return }
                        canDrag = false
                        let shouldDismiss = value.translation.width > 80
                            || value.predictedEndTranslation.width > 200
                        if shouldDismiss {
                            withAnimation(.easeOut(duration: 0.22)) {
                                dragOffset = UIScreen.main.bounds.width
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                                onDismiss()
                                dragOffset = 0
                            }
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
    }
}

public extension View {
    /// Edge-pan-to-dismiss for screens not in a NavigationStack (e.g. fullScreenCover).
    /// Mirrors the standard iOS swipe-from-left-edge gesture.
    func swipeToDismiss(_ onDismiss: @escaping () -> Void) -> some View {
        modifier(EdgeSwipeDismiss(onDismiss: onDismiss))
    }
}

// MARK: Hex helper

func hex(_ s: String) -> Color {
    var trimmed = s
    if trimmed.hasPrefix("#") { trimmed.removeFirst() }
    let scanner = Scanner(string: trimmed)
    var rgb: UInt64 = 0
    scanner.scanHexInt64(&rgb)
    let r = Double((rgb & 0xFF0000) >> 16) / 255.0
    let g = Double((rgb & 0x00FF00) >> 8) / 255.0
    let b = Double(rgb & 0x0000FF) / 255.0
    return Color(red: r, green: g, blue: b)
}
