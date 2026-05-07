// Themed confirmation dialog that matches the app's design language.
// Uses .confirmationDialog for a native bottom-sheet feel on iOS.

import SwiftUI

public struct DConfirmDialog: ViewModifier {
    @Binding var isPresented: Bool
    var title: String
    var message: String?
    var confirmLabel: String
    var danger: Bool
    var onConfirm: () -> Void

    public func body(content: Content) -> some View {
        content
            .confirmationDialog(title, isPresented: $isPresented, titleVisibility: .visible) {
                Button(confirmLabel, role: danger ? .destructive : nil) {
                    Haptics.medium()
                    onConfirm()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if let message {
                    Text(message)
                }
            }
    }
}

public extension View {
    func confirmAction(
        _ title: String,
        isPresented: Binding<Bool>,
        message: String? = nil,
        confirmLabel: String = "Confirm",
        danger: Bool = false,
        onConfirm: @escaping () -> Void
    ) -> some View {
        modifier(DConfirmDialog(
            isPresented: isPresented,
            title: title,
            message: message,
            confirmLabel: confirmLabel,
            danger: danger,
            onConfirm: onConfirm
        ))
    }
}
