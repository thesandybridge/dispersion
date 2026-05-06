// Port of app/src/components/ui/badge.tsx.

import SwiftUI

public enum DBadgeVariant {
    case `default`     // primary tint
    case secondary
    case outline
    case solid
    case accent
    case destructive
}

public struct DBadge<Content: View>: View {
    public var variant: DBadgeVariant
    @ViewBuilder var content: () -> Content

    public init(variant: DBadgeVariant = .default, @ViewBuilder content: @escaping () -> Content) {
        self.variant = variant
        self.content = content
    }

    public var body: some View {
        HStack(spacing: 4) {
            content()
        }
        .font(DispersionType.mono(10, weight: .medium))
        .tracking(1.8)
        .textCase(.uppercase)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .foregroundStyle(foreground)
        .background(background)
        .overlay(
            Capsule().strokeBorder(borderColor, lineWidth: borderWidth)
        )
        .clipShape(Capsule())
        .fixedSize()
    }

    private var foreground: Color {
        switch variant {
        case .default:     return DesignTokens.primary
        case .secondary:   return DesignTokens.secondaryForeground
        case .outline:     return DesignTokens.mutedForeground
        case .solid:       return DesignTokens.background
        case .accent:      return DesignTokens.accent
        case .destructive: return DesignTokens.destructive
        }
    }

    @ViewBuilder
    private var background: some View {
        switch variant {
        case .default:     DesignTokens.primary.opacity(0.15)
        case .secondary:   DesignTokens.secondary
        case .outline:     Color.clear
        case .solid:       DesignTokens.foreground
        case .accent:      DesignTokens.accent.opacity(0.20)
        case .destructive: DesignTokens.destructive.opacity(0.15)
        }
    }

    private var borderColor: Color {
        switch variant {
        case .default:     return DesignTokens.primary.opacity(0.25)
        case .secondary:   return DesignTokens.border
        case .outline:     return DesignTokens.border
        case .solid:       return Color.clear
        case .accent:      return DesignTokens.accent.opacity(0.30)
        case .destructive: return DesignTokens.destructive.opacity(0.30)
        }
    }

    private var borderWidth: CGFloat {
        variant == .solid ? 0 : 1
    }
}

/// Convenience init for plain text badges.
public extension DBadge where Content == Text {
    init(_ label: String, variant: DBadgeVariant = .default) {
        self.init(variant: variant) { Text(label) }
    }
}
