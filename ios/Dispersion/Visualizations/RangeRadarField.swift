// Range practice field. Concentric distance arcs radiate from the target
// at regular yard intervals (uniform scale — 1 yard maps to the same number
// of pixels in both axes), so tapped coordinates land where the user
// expects.
//
// Visual language is borrowed from DispersionViz so practice and
// calculation feel like siblings: a soft "green" target zone with a flag
// pin, heat-mapped probability contours that fill in as the session
// builds up, and warm/playful colors. The radar is still readable in
// both light and dark mode via DesignTokens semantic colors.

import SwiftUI

public struct RangeRadarField: View {
    @Environment(\.palette) private var palette

    public var targetYards: Double
    public var referenceCarrySd: Double
    public var referenceLateralSd: Double
    public var measured: DispersionStats
    public var shots: [ShotXY]
    public var onTap: ((ShotXY) -> Void)?
    public var onDrag: ((ShotXY?) -> Void)?
    public var readOnly: Bool

    public init(
        targetYards: Double,
        referenceCarrySd: Double,
        referenceLateralSd: Double,
        measured: DispersionStats,
        shots: [ShotXY],
        onTap: ((ShotXY) -> Void)? = nil,
        onDrag: ((ShotXY?) -> Void)? = nil,
        readOnly: Bool = false
    ) {
        self.targetYards = targetYards
        self.referenceCarrySd = referenceCarrySd
        self.referenceLateralSd = referenceLateralSd
        self.measured = measured
        self.shots = shots
        self.onTap = onTap
        self.onDrag = onDrag
        self.readOnly = readOnly
    }

    @State private var dragShot: ShotXY?
    @State private var isDragging = false

    public var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let geom = layout(in: size)
            let allShots = shots + (dragShot.map { [$0] } ?? [])
            ZStack {
                Canvas { ctx, _ in
                    drawScene(ctx: ctx, size: size, geom: geom, displayShots: allShots)
                }
                if !readOnly {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    isDragging = true
                                    let shot = geom.toShot(value.location)
                                    if dragShot == nil { Haptics.light() }
                                    dragShot = shot
                                    onDrag?(shot)
                                }
                                .onEnded { value in
                                    isDragging = false
                                    let shot = geom.toShot(value.location)
                                    dragShot = nil
                                    onDrag?(nil)
                                    Haptics.medium()
                                    onTap?(shot)
                                }
                        )
                }
            }
        }
    }

    // MARK: - Geometry

    private struct Geom {
        var center: CGPoint
        var scale: CGFloat
        var span: Double
        var size: CGSize

        func sx(_ lat: Double) -> CGFloat { center.x + CGFloat(lat) * scale }
        func sy(_ long: Double) -> CGFloat { center.y - CGFloat(long) * scale }
        func toShot(_ p: CGPoint) -> ShotXY {
            let lat = (p.x - center.x) / scale
            let long = (center.y - p.y) / scale
            return ShotXY(lat: Double(lat), long: Double(long))
        }
    }

    private func layout(in size: CGSize) -> Geom {
        let pad: CGFloat = 28
        let maxShotLong = shots.map { abs($0.long) }.max() ?? 0
        let maxShotLat = shots.map { abs($0.lat) }.max() ?? 0
        let span = max(
            referenceCarrySd * 3.5,
            referenceLateralSd * 3.5,
            maxShotLong * 1.3,
            maxShotLat * 1.3,
            25
        )
        let fitScaleX = (size.width - pad * 2) / CGFloat(span * 2)
        let fitScaleY = (size.height - pad * 2) / CGFloat(span * 2)
        let scale = min(fitScaleX, fitScaleY)
        return Geom(
            center: CGPoint(x: size.width / 2, y: size.height / 2),
            scale: scale,
            span: span,
            size: size
        )
    }

    // MARK: - Draw

    private func drawScene(ctx: GraphicsContext, size: CGSize, geom: Geom, displayShots: [ShotXY]) {
        let center = geom.center

        // 1. Background gradient — pine in dark mode, soft cream in light mode.
        let bgRect = CGRect(origin: .zero, size: size)
        ctx.fill(Path(bgRect), with: .radialGradient(
            Gradient(colors: [DesignTokens.background, DesignTokens.backgroundDeep]),
            center: center,
            startRadius: 0,
            endRadius: max(size.width, size.height) * 0.65
        ))

        // Subtle bentgrass wash so the radar reads as a "field" rather than a
        // blank panel. Stronger than before — gives the surface identity.
        ctx.fill(
            Path(bgRect),
            with: .radialGradient(
                Gradient(colors: [
                    DesignTokens.bentgrass.opacity(0.10),
                    DesignTokens.bentgrass.opacity(0.0),
                ]),
                center: center,
                startRadius: 0,
                endRadius: max(size.width, size.height) * 0.55
            )
        )

        // 2. Distance arcs — concentric, dashed, in a bentgrass tint that
        // stays subtle but warmer than plain border lines.
        let step = arcStep(for: geom.span)
        let maxArc = geom.span * 1.5
        var dist = step
        while dist <= maxArc {
            let r = CGFloat(dist) * geom.scale
            let arcPath = Path(ellipseIn: CGRect(
                x: center.x - r, y: center.y - r,
                width: r * 2, height: r * 2
            ))
            let isMainArc = dist.truncatingRemainder(dividingBy: step * 2) == 0 || step >= 10
            ctx.stroke(
                arcPath,
                with: .color(DesignTokens.bentgrass.opacity(isMainArc ? 0.22 : 0.10)),
                style: StrokeStyle(lineWidth: 0.7, dash: [2, 3])
            )

            let showLabel = step < 10 ? dist.truncatingRemainder(dividingBy: 10) == 0 || dist == step : true
            if showLabel {
                ctx.draw(
                    Text("\(Int(dist))y")
                        .font(DispersionType.mono(8, weight: .regular))
                        .foregroundStyle(DesignTokens.subtleForeground),
                    at: CGPoint(x: center.x + r + 2, y: center.y - 6),
                    anchor: .leading
                )
            }
            dist += step
        }

        // 3. Centerline (dashed vertical) — sight line from player to target.
        let centerline = Path { p in
            p.move(to: CGPoint(x: center.x, y: 0))
            p.addLine(to: CGPoint(x: center.x, y: size.height))
        }
        ctx.stroke(
            centerline,
            with: .color(DesignTokens.border),
            style: StrokeStyle(lineWidth: 0.7, dash: [4, 5])
        )

        // 4. Target green — soft rounded-rect polygon with bentgrass gradient
        // fill and accent border. Same idiom as DispersionViz.drawSafeZone.
        // Default 25y across so a real green is depicted at the target.
        let zoneSize = CGFloat(25) * geom.scale
        let zoneRect = CGRect(
            x: center.x - zoneSize / 2,
            y: center.y - zoneSize / 2,
            width: zoneSize,
            height: zoneSize
        )
        let r = min(zoneRect.width, zoneRect.height) * 0.32
        let zonePath = Path(roundedRect: zoneRect, cornerRadius: r)
        ctx.fill(
            zonePath,
            with: .linearGradient(
                Gradient(colors: [
                    DesignTokens.bentgrass.opacity(0.22),
                    DesignTokens.fairwayShadow.opacity(0.14),
                ]),
                startPoint: CGPoint(x: zoneRect.midX, y: zoneRect.minY),
                endPoint: CGPoint(x: zoneRect.midX, y: zoneRect.maxY)
            )
        )
        ctx.stroke(
            zonePath,
            with: .color(DesignTokens.bentgrass.opacity(0.70)),
            style: StrokeStyle(lineWidth: 1.5)
        )
        let innerRect = zoneRect.insetBy(dx: zoneRect.width * 0.05, dy: zoneRect.height * 0.05)
        let innerR = min(innerRect.width, innerRect.height) * 0.32
        ctx.stroke(
            Path(roundedRect: innerRect, cornerRadius: innerR),
            with: .color(.white.opacity(0.10)),
            style: StrokeStyle(lineWidth: 0.5)
        )

        // 5. Heat-mapped probability contours from measured σ — dim outer to
        // bright inner, like DispersionViz. Builds in as the session grows.
        if measured.n >= 3, measured.carrySd > 0, measured.lateralSd > 0 {
            let biasCenter = CGPoint(
                x: center.x + CGFloat(measured.latBias) * geom.scale,
                y: center.y - CGFloat(measured.longBias) * geom.scale
            )
            let kSteps = [2.6, 2.0, 1.4, 0.8] as [Double]
            let ramp = palette.heatRamp
            for (i, k) in kSteps.enumerated().reversed() {
                let rx = CGFloat(measured.lateralSd * k) * geom.scale
                let ry = CGFloat(measured.carrySd * k) * geom.scale
                let path = Path(ellipseIn: CGRect(
                    x: biasCenter.x - rx,
                    y: biasCenter.y - ry,
                    width: rx * 2,
                    height: ry * 2
                ))
                let t = Double(i) / Double(max(kSteps.count - 1, 1))
                let alpha = 0.06 + t * 0.30
                let color = ramp[min(i + 2, ramp.count - 1)].opacity(alpha)
                ctx.fill(path, with: .color(color))
            }

            // Bias arrow + mean dot — only when we have a meaningful bias.
            let biasMagnitude = sqrt(measured.latBias * measured.latBias + measured.longBias * measured.longBias)
            if biasMagnitude > 1.5 {
                var arrow = Path()
                arrow.move(to: center)
                arrow.addLine(to: biasCenter)
                ctx.stroke(
                    arrow,
                    with: .color(palette.primary.opacity(0.55)),
                    style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                )
                let dot = Path(ellipseIn: CGRect(x: biasCenter.x - 4, y: biasCenter.y - 4, width: 8, height: 8))
                ctx.fill(dot, with: .color(palette.primary))
                let ring = Path(ellipseIn: CGRect(x: biasCenter.x - 6, y: biasCenter.y - 6, width: 12, height: 12))
                ctx.stroke(ring, with: .color(palette.primary.opacity(0.4)), lineWidth: 1)
            }
        }

        // 6. Flag pin at the target — same glyph as DispersionViz.drawPin.
        drawPin(ctx: ctx, at: center)

        // 7. Target yardage label, anchored to the right edge.
        ctx.draw(
            Text("\(Int(targetYards))y")
                .font(DispersionType.mono(10, weight: .medium))
                .foregroundStyle(DesignTokens.flag),
            at: CGPoint(x: size.width - 10, y: center.y - 10),
            anchor: .trailing
        )

        // 8. Compass labels — adapt to light/dark via subtleForeground.
        let compassFont = Font.system(size: 8, design: .monospaced).weight(.medium)
        let compassColor = DesignTokens.subtleForeground
        ctx.draw(Text("LONG").font(compassFont).foregroundStyle(compassColor),
                 at: CGPoint(x: center.x, y: 14), anchor: .center)
        ctx.draw(Text("SHORT").font(compassFont).foregroundStyle(compassColor),
                 at: CGPoint(x: center.x, y: size.height - 14), anchor: .center)
        ctx.draw(Text("L").font(compassFont).foregroundStyle(compassColor),
                 at: CGPoint(x: 12, y: center.y), anchor: .center)
        ctx.draw(Text("R").font(compassFont).foregroundStyle(compassColor),
                 at: CGPoint(x: size.width - 12, y: center.y), anchor: .center)

        // 9. Logged shot dots. Latest shot pops with a bentgrass halo + brand
        // accent fill; older shots use foreground so they stay visible in
        // light mode (cream-on-cream would vanish).
        for (i, shot) in displayShots.enumerated() {
            let p = CGPoint(x: geom.sx(shot.lat), y: geom.sy(shot.long))
            let isLatest = i == displayShots.count - 1

            if isLatest && !displayShots.isEmpty {
                let halo = Path(ellipseIn: CGRect(x: p.x - 11, y: p.y - 11, width: 22, height: 22))
                ctx.fill(halo, with: .color(palette.primary.opacity(0.25)))
            }

            let r: CGFloat = isLatest ? 5.5 : 3.5
            let dot = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
            ctx.fill(dot, with: .color(isLatest ? palette.primary : DesignTokens.foreground))
            ctx.stroke(dot, with: .color(DesignTokens.background), lineWidth: 1.2)

            if displayShots.count <= 20 {
                ctx.draw(
                    Text("\(i + 1)")
                        .font(.system(size: 8, design: .monospaced).weight(.medium))
                        .foregroundStyle(DesignTokens.mutedForeground),
                    at: CGPoint(x: p.x, y: p.y - r - 7)
                )
            }
        }

        // 10. Empty hint — playful prompt, not a debug label.
        if displayShots.isEmpty {
            ctx.draw(
                Text("TAP WHERE IT LANDED")
                    .font(DispersionType.mono(10, weight: .semibold))
                    .tracking(2.4)
                    .foregroundStyle(DesignTokens.foreground.opacity(0.6)),
                at: CGPoint(x: center.x, y: center.y + 60)
            )
        }
    }

    // MARK: - Pin glyph

    /// Borrowed from DispersionViz.drawPin so the practice radar and the
    /// calculator viz share the same target language.
    private func drawPin(ctx: GraphicsContext, at point: CGPoint) {
        // Stick.
        let stickTop = CGPoint(x: point.x, y: point.y - 22)
        var stick = Path()
        stick.move(to: point)
        stick.addLine(to: stickTop)
        ctx.stroke(stick, with: .color(.white.opacity(0.92)), lineWidth: 1.5)

        // Flag triangle.
        var flag = Path()
        flag.move(to: stickTop)
        flag.addLine(to: CGPoint(x: stickTop.x + 12, y: stickTop.y + 4))
        flag.addLine(to: CGPoint(x: stickTop.x, y: stickTop.y + 8))
        flag.closeSubpath()
        ctx.fill(flag, with: .color(palette.flag))
        ctx.stroke(flag, with: .color(palette.flag.opacity(0.8)), lineWidth: 0.5)

        // Cup.
        let cup = Path(ellipseIn: CGRect(
            x: point.x - 3, y: point.y - 1.5, width: 6, height: 3
        ))
        ctx.fill(cup, with: .color(.black.opacity(0.55)))
        ctx.stroke(cup, with: .color(.white.opacity(0.6)), lineWidth: 0.8)
    }

    private func arcStep(for span: Double) -> Double {
        if span <= 15 { return 3 }
        if span <= 35 { return 5 }
        if span <= 70 { return 10 }
        return 20
    }
}
