// Port of app/src/components/primitives/DispersionViz.tsx +
// ResponsiveDispersionViz.tsx. Renders a club's dispersion as nested probability
// contours centered on the expected landing point, with the target reticle and
// optional safe-zone overlay.
//
// SwiftUI Canvas replaces SVG. Drawing is purely vectorial; layout is driven
// by GeometryReader so the same view can be used full-bleed (calculator) or
// inline (club edit form preview).

import SwiftUI

public struct DispersionViz: View {
    public var carry: Double
    public var carrySd: Double
    public var lateralSd: Double
    public var distanceToTarget: Double
    public var zoneWidth: Double?
    public var zoneDepth: Double?
    public var contours: Int
    public var facets: Int
    public var background: Color

    public init(
        carry: Double,
        carrySd: Double,
        lateralSd: Double,
        distanceToTarget: Double,
        zoneWidth: Double? = nil,
        zoneDepth: Double? = nil,
        contours: Int = 6,
        facets: Int = 28,
        background: Color = DesignTokens.backgroundDeep
    ) {
        self.carry = carry
        self.carrySd = carrySd
        self.lateralSd = lateralSd
        self.distanceToTarget = distanceToTarget
        self.zoneWidth = zoneWidth
        self.zoneDepth = zoneDepth
        self.contours = contours
        self.facets = facets
        self.background = background
    }

    public var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                drawScene(ctx: ctx, size: size)
            }
            .background(background)
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func drawScene(ctx: GraphicsContext, size: CGSize) {
        let pad: CGFloat = 28

        // World units span: roughly 3.5σ around mean + a bit of headroom.
        let longSpan = max(carrySd * 3.5, 25)
        let latSpan = max(lateralSd * 3.5, 18)

        // Vertical axis: target at the top, our shot landing somewhere below
        // (or above if club is too short / too long).
        let scaleX = (size.width - pad * 2) / (latSpan * 2)
        let scaleY = (size.height - pad * 2) / (longSpan * 2)

        let targetCenter = CGPoint(x: size.width / 2, y: size.height / 2)
        let meanLong = carry - distanceToTarget // y delta in yards (positive = past target)
        let meanCenter = CGPoint(
            x: targetCenter.x,
            y: targetCenter.y - CGFloat(meanLong) * scaleY
        )

        // 1. Concentric probability contours (heat palette outermost → innermost).
        let kSteps = stride(from: 0.6, through: 2.6, by: (2.6 - 0.6) / Double(max(contours - 1, 1))).map { $0 }
        let palette: [Color] = [
            DesignTokens.heat0, DesignTokens.heat1, DesignTokens.heat2,
            DesignTokens.heat3, DesignTokens.heat4, DesignTokens.heat5,
        ]

        for (i, k) in kSteps.enumerated().reversed() {
            let path = ellipsePath(
                center: meanCenter,
                rx: CGFloat(lateralSd) * CGFloat(k) * scaleX,
                ry: CGFloat(carrySd) * CGFloat(k) * scaleY,
                facets: facets
            )
            let color = palette[min(i, palette.count - 1)].opacity(0.6)
            ctx.fill(path, with: .color(color))
        }

        // 2. Safe zone overlay (if any).
        if let zw = zoneWidth, let zd = zoneDepth {
            let rect = CGRect(
                x: targetCenter.x - CGFloat(zw / 2) * scaleX,
                y: targetCenter.y - CGFloat(zd / 2) * scaleY,
                width: CGFloat(zw) * scaleX,
                height: CGFloat(zd) * scaleY
            )
            let zonePath = Path(roundedRect: rect, cornerRadius: 6)
            ctx.stroke(zonePath, with: .color(DesignTokens.flag.opacity(0.55)), lineWidth: 1)
            ctx.fill(zonePath, with: .color(DesignTokens.flag.opacity(0.05)))
        }

        // 3. Mean → target vector.
        let line = Path { p in
            p.move(to: targetCenter)
            p.addLine(to: meanCenter)
        }
        ctx.stroke(line, with: .color(DesignTokens.primary.opacity(0.5)),
                   style: StrokeStyle(lineWidth: 0.8, dash: [3, 3]))

        // 4. Mean dot.
        let meanDot = Path(ellipseIn: CGRect(x: meanCenter.x - 3, y: meanCenter.y - 3, width: 6, height: 6))
        ctx.fill(meanDot, with: .color(DesignTokens.primary))

        // 5. Target reticle.
        drawReticle(ctx: ctx, at: targetCenter)
    }

    private func ellipsePath(center: CGPoint, rx: CGFloat, ry: CGFloat, facets: Int) -> Path {
        var p = Path()
        for i in 0...facets {
            let t = (Double(i) / Double(facets)) * .pi * 2
            let x = center.x + CGFloat(cos(t)) * rx
            let y = center.y + CGFloat(sin(t)) * ry
            if i == 0 {
                p.move(to: CGPoint(x: x, y: y))
            } else {
                p.addLine(to: CGPoint(x: x, y: y))
            }
        }
        p.closeSubpath()
        return p
    }

    private func drawReticle(ctx: GraphicsContext, at point: CGPoint) {
        let outer = Path(ellipseIn: CGRect(x: point.x - 9, y: point.y - 9, width: 18, height: 18))
        ctx.stroke(outer, with: .color(DesignTokens.flag), lineWidth: 1.2)
        let core = Path(ellipseIn: CGRect(x: point.x - 2, y: point.y - 2, width: 4, height: 4))
        ctx.fill(core, with: .color(DesignTokens.flag))

        // Crosshair ticks.
        let ticks = Path { p in
            p.move(to: CGPoint(x: point.x - 14, y: point.y))
            p.addLine(to: CGPoint(x: point.x - 4, y: point.y))
            p.move(to: CGPoint(x: point.x + 4, y: point.y))
            p.addLine(to: CGPoint(x: point.x + 14, y: point.y))
            p.move(to: CGPoint(x: point.x, y: point.y - 14))
            p.addLine(to: CGPoint(x: point.x, y: point.y - 4))
            p.move(to: CGPoint(x: point.x, y: point.y + 4))
            p.addLine(to: CGPoint(x: point.x, y: point.y + 14))
        }
        ctx.stroke(ticks, with: .color(DesignTokens.flag), lineWidth: 1)
    }
}
