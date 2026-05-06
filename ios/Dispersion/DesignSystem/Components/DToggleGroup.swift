// Port of app/src/components/ui/toggle-group.tsx (single-select variant).
// Also used for the small horizontal chip rows on the calculator zone sheet.

import SwiftUI

public struct DToggleOption<Value: Hashable>: Identifiable {
    public let id = UUID()
    public let value: Value
    public let label: String
    public let trailing: String?

    public init(value: Value, label: String, trailing: String? = nil) {
        self.value = value
        self.label = label
        self.trailing = trailing
    }
}

public struct DToggleGroup<Value: Hashable>: View {
    public var options: [DToggleOption<Value>]
    @Binding public var selection: Value?

    public init(options: [DToggleOption<Value>], selection: Binding<Value?>) {
        self.options = options
        self._selection = selection
    }

    public var body: some View {
        // Wrap horizontally; on tighter screens this becomes multi-row.
        FlowLayout(spacing: 6, runSpacing: 6) {
            ForEach(options) { opt in
                Button {
                    selection = opt.value
                } label: {
                    HStack(spacing: 4) {
                        Text(opt.label)
                        if let trailing = opt.trailing {
                            Text(trailing)
                                .font(DispersionType.mono(10))
                                .opacity(0.7)
                        }
                    }
                }
                .buttonStyle(DToggleItemStyle(isOn: selection == opt.value))
            }
        }
    }
}

private struct DToggleItemStyle: ButtonStyle {
    var isOn: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DispersionType.ui(13, weight: .medium))
            .foregroundStyle(isOn ? DesignTokens.background : DesignTokens.mutedForeground)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(
                    isOn ? AnyShapeStyle(DesignTokens.foreground)
                         : AnyShapeStyle(DesignTokens.muted.opacity(configuration.isPressed ? 0.85 : 0.4))
                )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.85), value: configuration.isPressed)
    }
}

// MARK: simple flow layout (chip wrapping)

/// Minimal horizontal flow layout. Lays children left-to-right; wraps to next
/// row when width is exceeded. SwiftUI doesn't ship one OOTB before iOS 16,
/// but iOS 17 has Layout protocol — we use it here.
public struct FlowLayout: Layout {
    public var spacing: CGFloat
    public var runSpacing: CGFloat

    public init(spacing: CGFloat = 6, runSpacing: CGFloat = 6) {
        self.spacing = spacing
        self.runSpacing = runSpacing
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        let width = proposal.width ?? .infinity
        let layout = computeLayout(width: width, subviews: subviews)
        return CGSize(width: width.isFinite ? width : layout.maxX, height: layout.totalHeight)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        let layout = computeLayout(width: bounds.width, subviews: subviews)
        for (i, frame) in layout.frames.enumerated() {
            let origin = CGPoint(x: bounds.minX + frame.origin.x, y: bounds.minY + frame.origin.y)
            subviews[i].place(at: origin, anchor: .topLeading, proposal: ProposedViewSize(frame.size))
        }
    }

    public func makeCache(subviews: Subviews) -> Cache { Cache() }

    public struct Cache {}

    private struct Layout {
        var frames: [CGRect]
        var totalHeight: CGFloat
        var maxX: CGFloat
    }

    private func computeLayout(width: CGFloat, subviews: Subviews) -> Layout {
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                x = 0
                y += rowHeight + runSpacing
                rowHeight = 0
            }
            frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x)
        }
        return Layout(frames: frames, totalHeight: y + rowHeight, maxX: maxX)
    }
}
