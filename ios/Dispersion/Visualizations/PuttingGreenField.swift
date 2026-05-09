// Top-down stylized green for putt practice. The cup is at the center; the
// active practice distance defines the outer "tee" ring. Tap anywhere on
// the green to log where the ball ended up — landing inside the cup ring
// is a make, otherwise the distance from the cup is captured as the lag
// residual.

import SwiftUI

public struct PuttingGreenField: View {
    @Environment(\.palette) private var palette

    /// Current practice distance in feet — the radius of the dashed "tee
    /// ring" so the user can see how big the putt they're attempting is
    /// relative to the green.
    public var practiceDistanceFeet: Double

    /// Last logged putt position (feet from cup, +X right, +Y past). Drawn
    /// as a glowing dot; nil means no landing yet.
    public var lastLandingFeet: CGPoint?

    /// Cup radius in feet — anything tapped within this distance counts
    /// as made. 0.21 ft (≈ 2.5 inch radius) is regulation cup size.
    public var cupRadiusFeet: Double = 0.21

    public var onLog: ((PuttingGreenField.Tap) -> Void)?

    public struct Tap: Sendable {
        public let made: Bool
        public let residualFeet: Double
        public let x: Double          // feet, right of cup
        public let y: Double          // feet, past cup (toward back of green)
    }

    public init(
        practiceDistanceFeet: Double,
        lastLandingFeet: CGPoint? = nil,
        cupRadiusFeet: Double = 0.21,
        onLog: ((Tap) -> Void)? = nil
    ) {
        self.practiceDistanceFeet = practiceDistanceFeet
        self.lastLandingFeet = lastLandingFeet
        self.cupRadiusFeet = cupRadiusFeet
        self.onLog = onLog
    }

    public var body: some View {
        GeometryReader { geo in
            let geom = layout(in: geo.size)
            ZStack {
                Canvas { ctx, _ in
                    drawScene(ctx: ctx, size: geo.size, geom: geom)
                }
                if onLog != nil {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { value in
                                    let xFeet = Double((value.location.x - geom.center.x) / geom.scale)
                                    let yFeet = Double((geom.center.y - value.location.y) / geom.scale)
                                    let residual = sqrt(xFeet * xFeet + yFeet * yFeet)
                                    let made = residual <= cupRadiusFeet * 8   // forgiving — exact cup is tiny
                                    Haptics.medium()
                                    onLog?(Tap(made: made, residualFeet: residual, x: xFeet, y: yFeet))
                                }
                        )
                }
            }
        }
    }

    // MARK: - Layout

    private struct Geom {
        var center: CGPoint
        var scale: CGFloat   // pixels per foot
    }

    private func layout(in size: CGSize) -> Geom {
        // Show the practice distance comfortably inside the visible area —
        // the dashed tee ring sits at ~70% of the half-min-side. Doubled for
        // padding so the dot has room when a miss goes long.
        let halfShort = min(size.width, size.height) / 2
        let pad: CGFloat = 28
        let visibleRadiusFeet = max(practiceDistanceFeet * 1.4, 5)
        let scale = (halfShort - pad) / CGFloat(visibleRadiusFeet)
        return Geom(
            center: CGPoint(x: size.width / 2, y: size.height / 2),
            scale: scale
        )
    }

    // MARK: - Draw

    private func drawScene(ctx: GraphicsContext, size: CGSize, geom: Geom) {
        let center = geom.center

        // 1. Green oval — soft radial gradient, lighter at center, deeper at
        // the edges. Sized to fill the canvas.
        let greenRect = CGRect(origin: .zero, size: size).insetBy(dx: 8, dy: 8)
        let greenPath = Path(ellipseIn: greenRect)
        ctx.fill(
            greenPath,
            with: .radialGradient(
                Gradient(colors: [
                    DesignTokens.bentgrass.opacity(0.55),
                    DesignTokens.fairwayShadow.opacity(0.42),
                    DesignTokens.pine.opacity(0.50),
                ]),
                center: center,
                startRadius: 0,
                endRadius: max(size.width, size.height) * 0.55
            )
        )
        // Subtle rim
        ctx.stroke(
            greenPath,
            with: .color(DesignTokens.bentgrass.opacity(0.55)),
            lineWidth: 1
        )

        // 2. Faint grain lines — radial spokes, give the green texture
        // without competing for attention.
        let spokes = 18
        for i in 0..<spokes {
            let angle = (Double(i) / Double(spokes)) * .pi * 2
            let start = CGPoint(
                x: center.x + CGFloat(cos(angle)) * 30,
                y: center.y + CGFloat(sin(angle)) * 30
            )
            let end = CGPoint(
                x: center.x + CGFloat(cos(angle)) * (max(size.width, size.height) * 0.55),
                y: center.y + CGFloat(sin(angle)) * (max(size.width, size.height) * 0.55)
            )
            var p = Path()
            p.move(to: start)
            p.addLine(to: end)
            ctx.stroke(p, with: .color(.white.opacity(0.04)), lineWidth: 0.5)
        }

        // 3. Distance rings around the cup — every 5 ft up to the practice
        // distance + 5. Subtle dashed circles in cream.
        let ringStep: Double = practiceDistanceFeet >= 15 ? 5 : (practiceDistanceFeet >= 6 ? 3 : 1)
        var d = ringStep
        while d <= practiceDistanceFeet + ringStep {
            let r = CGFloat(d) * geom.scale
            let ring = Path(ellipseIn: CGRect(
                x: center.x - r, y: center.y - r,
                width: r * 2, height: r * 2
            ))
            ctx.stroke(
                ring,
                with: .color(.white.opacity(0.08)),
                style: StrokeStyle(lineWidth: 0.7, dash: [3, 4])
            )
            ctx.draw(
                Text("\(Int(d))ft")
                    .font(DispersionType.mono(8, weight: .regular))
                    .foregroundStyle(.white.opacity(0.40)),
                at: CGPoint(x: center.x + r + 3, y: center.y - 6),
                anchor: .leading
            )
            d += ringStep
        }

        // 4. Practice-distance "tee ring" — solid accent at the chosen
        // distance, makes it obvious how far the putt is.
        let teeR = CGFloat(practiceDistanceFeet) * geom.scale
        let teeRing = Path(ellipseIn: CGRect(
            x: center.x - teeR, y: center.y - teeR,
            width: teeR * 2, height: teeR * 2
        ))
        ctx.stroke(
            teeRing,
            with: .color(palette.flag.opacity(0.55)),
            style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
        )

        // 5. Cup glyph — visible dark dot with a cream rim.
        let cupR: CGFloat = 7
        let cupOuter = Path(ellipseIn: CGRect(x: center.x - cupR, y: center.y - cupR, width: cupR * 2, height: cupR * 2))
        ctx.fill(cupOuter, with: .color(.black.opacity(0.85)))
        ctx.stroke(cupOuter, with: .color(.white.opacity(0.7)), lineWidth: 1.2)
        // Flag stick — short pin coming out of the cup.
        var pin = Path()
        pin.move(to: CGPoint(x: center.x, y: center.y))
        pin.addLine(to: CGPoint(x: center.x, y: center.y - 28))
        ctx.stroke(pin, with: .color(.white.opacity(0.85)), lineWidth: 1.4)
        var flag = Path()
        flag.move(to: CGPoint(x: center.x, y: center.y - 28))
        flag.addLine(to: CGPoint(x: center.x + 12, y: center.y - 25))
        flag.addLine(to: CGPoint(x: center.x, y: center.y - 22))
        flag.closeSubpath()
        ctx.fill(flag, with: .color(palette.flag))

        // 6. Last landing point — glowing dot with a thin halo.
        if let landing = lastLandingFeet {
            let p = CGPoint(
                x: center.x + CGFloat(landing.x) * geom.scale,
                y: center.y - CGFloat(landing.y) * geom.scale
            )
            let halo = Path(ellipseIn: CGRect(x: p.x - 11, y: p.y - 11, width: 22, height: 22))
            ctx.fill(halo, with: .color(palette.primary.opacity(0.30)))
            let dot = Path(ellipseIn: CGRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10))
            ctx.fill(dot, with: .color(palette.primary))
            ctx.stroke(dot, with: .color(.white.opacity(0.6)), lineWidth: 1)
        }

        // 7. Helper hint when there's no landing yet.
        if lastLandingFeet == nil {
            ctx.draw(
                Text("TAP WHERE IT STOPPED")
                    .font(DispersionType.mono(10, weight: .semibold))
                    .tracking(2.4)
                    .foregroundStyle(.white.opacity(0.45)),
                at: CGPoint(x: center.x, y: size.height - 24)
            )
        }
    }
}
