import SwiftUI

public struct DSeparator: View {
    public var orientation: Axis = .horizontal
    public init(_ orientation: Axis = .horizontal) { self.orientation = orientation }
    public var body: some View {
        Rectangle()
            .fill(DesignTokens.border)
            .frame(
                width: orientation == .vertical ? 1 : nil,
                height: orientation == .horizontal ? 1 : nil
            )
    }
}
