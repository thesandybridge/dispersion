// Port of app/src/components/ui/sheet.tsx. Uses native `.sheet()` with a
// large detent and our editorial header treatment.

import SwiftUI

public struct DSheetHeader: View {
    public var eyebrow: String?
    public var title: String

    public init(eyebrow: String? = nil, title: String) {
        self.eyebrow = eyebrow
        self.title = title
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let eyebrow {
                Text(eyebrow).eyebrow()
            }
            Text(title)
                .font(DispersionType.display(24, weight: .regular))
                .tracking(-0.5)
                .foregroundStyle(DesignTokens.foreground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Convenience modifier so calling code reads cleanly.
///
///   .dispersionSheet(isPresented: $isOpen, detents: [.medium, .large]) {
///       DSheetHeader(eyebrow: "Adjust", title: "Target & zone")
///       VStack { ... }
///   }
public extension View {
    func dispersionSheet<Content: View>(
        isPresented: Binding<Bool>,
        detents: Set<PresentationDetent> = [.medium, .large],
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        sheet(isPresented: isPresented) {
            DSheetContainer(content: content)
                .presentationDetents(detents)
                .presentationDragIndicator(.visible)
                .presentationBackground(DesignTokens.popover)
        }
    }
}

public struct DSheetContainer<Content: View>: View {
    @ViewBuilder var content: () -> Content
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                content()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
    }
}
