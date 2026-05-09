// Range practice field. The user taps where their shot landed; we map the
// tap into a (lat, long) yardage delta from the target and append it to
// the session.
//
// Visual language: warm and unfussy, not a military radar HUD. A soft
// bentgrass-tinted field, thin solid distance arcs at the major
// intervals only, and a clean accent crosshair at the target — no flag,
// no concentric dashed rings. Heat-mapped probability contours fill in
// once we have enough shots so the surface earns its visual weight from
// the session itself.

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

        // Canvas is transparent — the parent (RangeScreen) paints the
        // background + warm wash for the entire screen so there's no edge
        // transition where the canvas ends.

        // 1. Distance arcs — *only* the major intervals, and only the ones
        // that fit fully inside the visible field. Drawing arcs that bleed
        // off the edge gets clipped to the canvas bounds, which looks like
        // sudden cuts. Bound maxArc by the narrower dimension so every
        // ring is a complete circle.
        let majorStep = arcStep(for: geom.span)
        let labelMargin: CGFloat = 24   // room for the "Ny" label tail on the right
        let maxRingPx = min(
            min(size.width / 2, size.height / 2) - labelMargin,
            CGFloat(geom.span * 1.5) * geom.scale
        )
        let maxArc = max(majorStep, Double(maxRingPx / geom.scale))
        var dist = majorStep
        while dist <= maxArc {
            let r = CGFloat(dist) * geom.scale
            let arcPath = Path(ellipseIn: CGRect(
                x: center.x - r, y: center.y - r,
                width: r * 2, height: r * 2
            ))
            ctx.stroke(
                arcPath,
                with: .color(DesignTokens.bentgrass.opacity(0.16)),
                lineWidth: 0.7
            )

            ctx.draw(
                Text("\(Int(dist))y")
                    .font(DispersionType.mono(8, weight: .regular))
                    .foregroundStyle(DesignTokens.subtleForeground),
                at: CGPoint(x: center.x + r + 2, y: center.y - 6),
                anchor: .leading
            )
            dist += majorStep
        }

        // 3. Heat-mapped probability contours from measured σ — only once we
        // have a meaningful sample. Builds in as the session grows.
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
                let alpha = 0.06 + t * 0.28
                let color = ramp[min(i + 2, ramp.count - 1)].opacity(alpha)
                ctx.fill(path, with: .color(color))
            }

            // Bias arrow + mean dot, only if the bias is meaningful.
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

        // 4. Target crosshair — clean accent reticle, no pin, no flag. Just
        // enough chrome to say "aim here." Cross arms are short so the dot
        // reads first.
        let crossLen: CGFloat = 14
        let crossInner: CGFloat = 5
        let accent = DesignTokens.primary
        var cross = Path()
        cross.move(to: CGPoint(x: center.x - crossLen, y: center.y))
        cross.addLine(to: CGPoint(x: center.x - crossInner, y: center.y))
        cross.move(to: CGPoint(x: center.x + crossInner, y: center.y))
        cross.addLine(to: CGPoint(x: center.x + crossLen, y: center.y))
        cross.move(to: CGPoint(x: center.x, y: center.y - crossLen))
        cross.addLine(to: CGPoint(x: center.x, y: center.y - crossInner))
        cross.move(to: CGPoint(x: center.x, y: center.y + crossInner))
        cross.addLine(to: CGPoint(x: center.x, y: center.y + crossLen))
        ctx.stroke(cross, with: .color(accent.opacity(0.85)), lineWidth: 1.4)
        let centerDot = Path(ellipseIn: CGRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6))
        ctx.fill(centerDot, with: .color(accent))

        // 5. Target yardage label, anchored to the right edge.
        ctx.draw(
            Text("\(Int(targetYards))y")
                .font(DispersionType.mono(10, weight: .medium))
                .foregroundStyle(accent),
            at: CGPoint(x: size.width - 10, y: center.y - 10),
            anchor: .trailing
        )

        // 6. Compass labels — adapt to light/dark via subtleForeground.
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

        // 7. Logged shot dots. Latest shot pops with an accent halo + brand
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

        // 8. Empty hint.
        if displayShots.isEmpty {
            ctx.draw(
                Text("TAP WHERE IT LANDED")
                    .font(DispersionType.mono(10, weight: .semibold))
                    .tracking(2.4)
                    .foregroundStyle(DesignTokens.foreground.opacity(0.55)),
                at: CGPoint(x: center.x, y: center.y + 40)
            )
        }
    }

    private func arcStep(for span: Double) -> Double {
        if span <= 15 { return 5 }
        if span <= 35 { return 10 }
        if span <= 70 { return 20 }
        return 30
    }
}
