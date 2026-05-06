// Port of app/src/components/ui/slider.tsx. Wraps the native Slider with our
// styling; uses a custom track + thumb so the look matches the Tauri build.

import SwiftUI

public struct DSlider: View {
    @Binding public var value: Double
    public var range: ClosedRange<Double>
    public var step: Double?

    public init(value: Binding<Double>, in range: ClosedRange<Double>, step: Double? = nil) {
        self._value = value
        self.range = range
        self.step = step
    }

    public var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let pct = clamp((value - range.lowerBound) / (range.upperBound - range.lowerBound), 0, 1)

            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(DesignTokens.muted.opacity(0.6))
                    .frame(height: 6)

                // Filled portion
                Capsule()
                    .fill(DesignTokens.primary)
                    .frame(width: max(0, pct * width), height: 6)

                // Thumb
                Circle()
                    .strokeBorder(DesignTokens.primary, lineWidth: 2)
                    .background(Circle().fill(DesignTokens.background))
                    .frame(width: 22, height: 22)
                    .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 2)
                    .offset(x: pct * width - 11)
            }
            .frame(height: 22)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        let raw = clamp(g.location.x / width, 0, 1)
                        var raw01 = raw * (range.upperBound - range.lowerBound) + range.lowerBound
                        if let step, step > 0 {
                            raw01 = (raw01 / step).rounded() * step
                        }
                        value = clamp(raw01, range.lowerBound, range.upperBound)
                    }
            )
        }
        .frame(height: 22)
    }
}

private func clamp<T: Comparable>(_ v: T, _ lo: T, _ hi: T) -> T {
    min(max(v, lo), hi)
}
