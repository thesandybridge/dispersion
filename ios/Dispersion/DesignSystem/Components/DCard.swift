// Port of app/src/components/ui/card.tsx.

import SwiftUI

public struct DCard<Content: View>: View {
    @ViewBuilder var content: () -> Content
    public var padding: EdgeInsets

    public init(
        padding: EdgeInsets = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0),
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.padding = padding
        self.content = content
    }

    public var body: some View {
        content()
            .padding(padding)
            .background(
                ThemedCardFill(cornerRadius: DesignTokens.Radius.xl)
                    .shadow(color: .black.opacity(0.25), radius: 1, x: 0, y: 1)
            )
    }
}

public struct DCardHeader<Content: View>: View {
    @ViewBuilder var content: () -> Content
    public init(@ViewBuilder content: @escaping () -> Content) { self.content = content }
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) { content() }
            .padding(.horizontal, 20)
            .padding(.top, 20)
    }
}

public struct DCardTitle: View {
    public var text: String
    public init(_ text: String) { self.text = text }
    public var body: some View {
        Text(text)
            .font(DispersionType.display(18, weight: .regular))
            .tracking(-0.18)
            .foregroundStyle(DesignTokens.cardForeground)
    }
}

public struct DCardDescription: View {
    public var text: String
    public init(_ text: String) { self.text = text }
    public var body: some View {
        Text(text)
            .font(DispersionType.ui(13))
            .foregroundStyle(DesignTokens.mutedForeground)
    }
}

public struct DCardContent<Content: View>: View {
    @ViewBuilder var content: () -> Content
    public init(@ViewBuilder content: @escaping () -> Content) { self.content = content }
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) { content() }
            .padding(20)
    }
}
