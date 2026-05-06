// Port of app/src/components/primitives/DispersionGlyph.tsx. Compact ellipse
// glyph used inline in the bag list rows.

import SwiftUI

public struct DispersionGlyph: View {
    public var carrySd: Double
    public var lateralSd: Double
    public var width: CGFloat
    public var height: CGFloat
    public var fill: Color
    public var stroke: Color

    public init(
        carrySd: Double,
        lateralSd: Double,
        width: CGFloat = 44,
        height: CGFloat = 28,
        fill: Color,
        stroke: Color
    ) {
        self.carrySd = carrySd
        self.lateralSd = lateralSd
        self.width = width
        self.height = height
        self.fill = fill
        self.stroke = stroke
    }

    public var body: some View {
        Canvas { ctx, size in
            let cx = size.width / 2
            let cy = size.height / 2
            let rx = min(14, lateralSd * 0.7)
            let ry = min(10, carrySd * 0.5)

            let ellipse = Path { p in
                p.addEllipse(in: CGRect(
                    x: cx - rx,
                    y: cy - ry,
                    width: rx * 2,
                    height: ry * 2
                ))
            }
            ctx.fill(ellipse, with: .color(fill.opacity(0.25)))
            ctx.stroke(ellipse, with: .color(stroke), lineWidth: 0.8)

            let dot = Path(ellipseIn: CGRect(x: cx - 1.4, y: cy - 1.4, width: 2.8, height: 2.8))
            ctx.fill(dot, with: .color(stroke))
        }
        .frame(width: width, height: height)
    }
}
