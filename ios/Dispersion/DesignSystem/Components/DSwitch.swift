// Wrapper around native Toggle with a brand tint.

import SwiftUI

public struct DSwitch: View {
    @Binding public var isOn: Bool
    public init(_ isOn: Binding<Bool>) { self._isOn = isOn }
    public var body: some View {
        Toggle("", isOn: $isOn)
            .labelsHidden()
            .toggleStyle(SwitchToggleStyle(tint: DesignTokens.primary))
    }
}
