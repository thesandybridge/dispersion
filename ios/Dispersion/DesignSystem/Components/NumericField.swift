// Numeric input that avoids SwiftUI's TextField(value:format:) per-keystroke
// formatter. The formatter pattern parses and reformats the bound Double on
// every character — perceptibly laggy with our card-heavy sheets.
//
// NumericField keeps a local `@State String` for the in-flight text and
// commits the parsed Double back to the binding when the field loses focus
// or the user submits. External changes to the bound value re-sync the
// text only when the field isn't focused, so we don't fight the user.

import SwiftUI

public struct NumericField: View {
    public let placeholder: String
    @Binding public var value: Double
    public var precision: Int

    public init(_ placeholder: String, value: Binding<Double>, precision: Int = 1) {
        self.placeholder = placeholder
        self._value = value
        self.precision = precision
    }

    @State private var text: String = ""
    @FocusState private var focused: Bool

    public var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(.decimalPad)
            .monospacedDigit()
            .focused($focused)
            .onAppear { syncFromValue() }
            .onChange(of: focused) { _, isNowFocused in
                if !isNowFocused { commit() }
            }
            .onChange(of: value) { _, _ in
                if !focused { syncFromValue() }
            }
            .onSubmit { commit() }
    }

    private func syncFromValue() {
        text = format(value)
    }

    private func commit() {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            value = 0
            text = format(0)
            return
        }
        if let parsed = Double(trimmed) {
            value = parsed
            text = format(parsed)
        } else {
            // Reject silently — re-show the last good value.
            text = format(value)
        }
    }

    private func format(_ d: Double) -> String {
        if precision <= 0 { return "\(Int(d))" }
        // Trim trailing zeros for cleaner display, but keep something
        // after the decimal so the user can see they're in fractional mode.
        let raw = String(format: "%.\(precision)f", d)
        return raw
    }
}
