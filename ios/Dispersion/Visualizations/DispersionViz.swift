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

        // World units span: fit both the σ ellipses and the zone.
        let zoneHalfW = (zoneWidth ?? 0) / 2 + 5
        let zoneHalfD = (zoneDepth ?? 0) / 2 + 5
        let longSpan = max(carrySd * 3.5, zoneHalfD, 25)
        let latSpan = max(lateralSd * 3.5, zoneHalfW, 18)

        // Uniform scale so equal yard values render equal pixel sizes
        // (a 25x25 zone looks square).
        let fitScaleX = (size.width - pad * 2) / (latSpan * 2)
        let fitScaleY = (size.height - pad * 2) / (longSpan * 2)
        let uniformScale = min(fitScaleX, fitScaleY)
        let scaleX = uniformScale
        let scaleY = uniformScale

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

        let n = kSteps.count
        for (i, k) in kSteps.enumerated().reversed() {
            let path = ellipsePath(
                center: meanCenter,
                rx: CGFloat(lateralSd) * CGFloat(k) * scaleX,
                ry: CGFloat(carrySd) * CGFloat(k) * scaleY,
                facets: facets
            )
            // Outer rings nearly invisible, inner rings brighter
            let t = Double(i) / Double(max(n - 1, 1))
            let alpha = 0.05 + t * 0.55
            let color = palette[min(i, palette.count - 1)].opacity(alpha)
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
            let zonePath = Path(roundedRect: rect, cornerRadius: 4)
            // Subtle dashed border
            ctx.stroke(zonePath, with: .color(Color.white.opacity(0.35)),
                       style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
            // Corner ticks for visibility
            let tickLen: CGFloat = 10
            let corners: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
                (rect.minX, rect.minY, 1, 1),
                (rect.maxX, rect.minY, -1, 1),
                (rect.minX, rect.maxY, 1, -1),
                (rect.maxX, rect.maxY, -1, -1),
            ]
            for (cx, cy, dx, dy) in corners {
                var tick = Path()
                tick.move(to: CGPoint(x: cx, y: cy + tickLen * dy))
                tick.addLine(to: CGPoint(x: cx, y: cy))
                tick.addLine(to: CGPoint(x: cx + tickLen * dx, y: cy))
                ctx.stroke(tick, with: .color(Color.white.opacity(0.55)), lineWidth: 1.5)
            }
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
        let color = Color.white.opacity(0.6)
        let outer = Path(ellipseIn: CGRect(x: point.x - 8, y: point.y - 8, width: 16, height: 16))
        ctx.stroke(outer, with: .color(color), lineWidth: 1)
        let core = Path(ellipseIn: CGRect(x: point.x - 1.5, y: point.y - 1.5, width: 3, height: 3))
        ctx.fill(core, with: .color(color))

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
        ctx.stroke(ticks, with: .color(color), lineWidth: 0.8)
    }
}
