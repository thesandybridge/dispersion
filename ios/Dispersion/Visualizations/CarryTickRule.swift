// Lightweight tick-rule used in the BagHero card to visualize where every
// club sits in the carry range.

import SwiftUI

public struct CarryTickRule: View {
    public var carriesYards: [Double]
    public var unit: DistanceUnit
    public var height: CGFloat

    public init(carriesYards: [Double], unit: DistanceUnit, height: CGFloat = 34) {
        self.carriesYards = carriesYards
        self.unit = unit
        self.height = height
    }

    public var body: some View {
        Canvas { ctx, size in
            guard !carriesYards.isEmpty else { return }
            let converted = carriesYards.map { Units.from(yards: $0, in: unit) }
            let minV = converted.min() ?? 0
            let maxV = converted.max() ?? 0
            let span = max(maxV - minV, 1)

            let bg = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: size.height / 2)
            ctx.fill(bg, with: .color(Color.white.opacity(0.06)))
            ctx.fill(bg, with: .linearGradient(
                Gradient(colors: [
                    DesignTokens.bentgrass.opacity(0),
                    DesignTokens.bentgrass.opacity(0.16),
                    DesignTokens.bentgrass.opacity(0),
                ]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: size.width, y: 0)
            ))

            // Tick per carry.
            for c in converted {
                let pct = (c - minV) / span
                let x = CGFloat(pct) * size.width
                let tick = Path { p in
                    p.move(to: CGPoint(x: x, y: size.height / 2 - 8))
                    p.addLine(to: CGPoint(x: x, y: size.height / 2 + 8))
                }
                ctx.stroke(tick, with: .color(Color.white.opacity(0.55)), lineWidth: 1)
            }

            // End labels.
            ctx.draw(
                Text("\(Int(minV))")
                    .font(DispersionType.mono(10, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.55)),
                at: CGPoint(x: 8, y: size.height / 2),
                anchor: .leading
            )
            ctx.draw(
                Text("\(Int(maxV))")
                    .font(DispersionType.mono(10, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.55)),
                at: CGPoint(x: size.width - 8, y: size.height / 2),
                anchor: .trailing
            )
        }
        .frame(height: height)
    }
}
