// Port of app/src/components/ui/button.tsx. Variants + sizes mirror shadcn's
// CVA spec, expressed as a SwiftUI ButtonStyle.

import SwiftUI

public enum DButtonVariant: Equatable {
    case primary       // bg-primary
    case solid         // bg-foreground (high contrast)
    case accent        // bg-accent
    case destructive
    case outline
    case secondary
    case ghost
}

public enum DButtonSize: Equatable {
    case `default`     // h-10
    case sm            // h-8
    case lg            // h-12
    case icon          // 40×40
    case iconSmall     // 32×32
}

public struct DButtonStyle: ButtonStyle {
    @Environment(\.themeAccent) private var accent
    public var variant: DButtonVariant = .primary
    public var size: DButtonSize = .default

    public init(variant: DButtonVariant = .primary, size: DButtonSize = .default) {
        self.variant = variant
        self.size = size
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .foregroundStyle(foreground)
            .padding(.horizontal, isIcon ? 0 : horizontalPadding)
            .frame(width: isIcon ? height : nil, height: height)
            .background(backgroundView(pressed: configuration.isPressed))
            .clipShape(Capsule())
            .overlay {
                if showsBorder {
                    Capsule().strokeBorder(borderColor, lineWidth: 1)
                }
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.85), value: configuration.isPressed)
            .opacity(0.999) // ensures animations register
            .contentShape(Capsule())
    }

    // MARK: derived properties

    private var height: CGFloat {
        switch size {
        case .default:    return 40
        case .sm:         return 32
        case .lg:         return 48
        case .icon:       return 40
        case .iconSmall:  return 32
        }
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .default:   return 16
        case .sm:        return 12
        case .lg:        return 24
        case .icon, .iconSmall: return 0
        }
    }

    private var fontSize: CGFloat {
        switch size {
        case .default:   return 13
        case .sm:        return 12
        case .lg:        return 14
        case .icon:      return 14
        case .iconSmall: return 12
        }
    }

    private var font: Font {
        DispersionType.ui(fontSize, weight: .medium)
    }

    private var isIcon: Bool { size == .icon || size == .iconSmall }

    private var foreground: Color {
        switch variant {
        case .primary:     return DesignTokens.primaryForeground  // dark on accent
        case .solid:       return DesignTokens.background
        case .accent:      return DesignTokens.accentForeground
        case .destructive: return DesignTokens.foreground
        case .outline:     return DesignTokens.foreground
        case .secondary:   return DesignTokens.secondaryForeground
        case .ghost:       return DesignTokens.foreground
        }
    }

    @ViewBuilder
    private func backgroundView(pressed: Bool) -> some View {
        switch variant {
        case .primary:
            accent
                .opacity(pressed ? 0.85 : 1)
        case .solid:
            DesignTokens.foreground
                .opacity(pressed ? 0.88 : 1)
        case .accent:
            DesignTokens.accent
                .opacity(pressed ? 0.88 : 1)
        case .destructive:
            DesignTokens.destructive
                .opacity(pressed ? 0.88 : 1)
        case .outline:
            Color.clear.background(pressed ? DesignTokens.muted.opacity(0.55) : .clear)
        case .secondary:
            DesignTokens.secondary
                .opacity(pressed ? 0.85 : 1)
        case .ghost:
            (pressed ? DesignTokens.muted.opacity(0.6) : Color.clear)
        }
    }

    private var showsBorder: Bool {
        switch variant {
        case .outline: return true
        default: return false
        }
    }

    private var borderColor: Color {
        DesignTokens.border
    }
}

public extension ButtonStyle where Self == DButtonStyle {
    static func dispersion(_ variant: DButtonVariant = .primary, size: DButtonSize = .default) -> DButtonStyle {
        DButtonStyle(variant: variant, size: size)
    }
}
