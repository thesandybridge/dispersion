// String-input twin of NumericField. Same problem, same fix: a TextField
// bound directly to a parent @State property re-renders the entire sheet
// per keystroke, which makes long edit sheets feel laggy and trips the
// "System gesture gate timed out" warning when there's also a ScrollView
// in the tree.
//
// BufferedTextField holds an internal @State String and only commits to
// the bound `value` when the field loses focus or the user submits. The
// parent's body doesn't re-evaluate while the user is typing.

import SwiftUI

public struct BufferedTextField: View {
    public let placeholder: String
    @Binding public var value: String
    public var capitalization: TextInputAutocapitalization
    public var keyboard: UIKeyboardType

    public init(
        _ placeholder: String,
        value: Binding<String>,
        capitalization: TextInputAutocapitalization = .sentences,
        keyboard: UIKeyboardType = .default
    ) {
        self.placeholder = placeholder
        self._value = value
        self.capitalization = capitalization
        self.keyboard = keyboard
    }

    @State private var text: String = ""
    @FocusState private var focused: Bool

    public var body: some View {
        TextField(placeholder, text: $text)
            .textInputAutocapitalization(capitalization)
            .keyboardType(keyboard)
            .focused($focused)
            .onAppear { text = value }
            .onChange(of: focused) { _, isNowFocused in
                if !isNowFocused { commit() }
            }
            .onChange(of: value) { _, _ in
                if !focused { text = value }
            }
            .onSubmit { commit() }
    }

    private func commit() {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        value = trimmed
        text = trimmed
    }
}
