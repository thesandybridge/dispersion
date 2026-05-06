// Port of the inline ProbabilityDial in app/src/routes/calculator.tsx.
// Circular progress + animated value, rendered with a Trim-clipped Circle.

import SwiftUI

public struct ProbabilityDial: View {
    /// 0...1
    public var value: Double
    public var color: Color
    public var diameter: CGFloat
    public var trackThickness: CGFloat

    public init(value: Double, color: Color, diameter: CGFloat = 86, trackThickness: CGFloat = 6) {
        self.value = value
        self.color = color
        self.diameter = diameter
        self.trackThickness = trackThickness
    }

    public var body: some View {
        let pct = Int((value * 100).rounded())
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: trackThickness)
            Circle()
                .trim(from: 0, to: max(min(value, 1), 0))
                .stroke(color, style: StrokeStyle(lineWidth: trackThickness, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.45, dampingFraction: 0.78), value: value)

            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("\(pct)")
                    .font(DispersionType.display(diameter * 0.33, weight: .regular))
                    .foregroundStyle(color)
                    .contentTransition(.numericText(value: Double(pct)))
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: pct)
                Text("%")
                    .font(DispersionType.display(diameter * 0.16, weight: .regular))
                    .foregroundStyle(color.opacity(0.7))
                    .baselineOffset(diameter * 0.05)
            }
            .monospacedDigit()
        }
        .frame(width: diameter, height: diameter)
    }
}
