// Range practice field. Concentric distance arcs radiate from the target at
// regular yard intervals. Uniform scale (1 yard = same pixels in both axes)
// so tapped coordinates map accurately to real distances.

import SwiftUI

public struct RangeRadarField: View {
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

    // MARK: layout

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
        // Uniform scale — constrained by the narrower dimension
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

    // MARK: draw

    private func drawScene(ctx: GraphicsContext, size: CGSize, geom: Geom, displayShots: [ShotXY]) {
        let center = geom.center

        // Background gradient
        let bgRect = CGRect(origin: .zero, size: size)
        ctx.fill(Path(bgRect), with: .radialGradient(
            Gradient(colors: [DesignTokens.background, DesignTokens.backgroundDeep]),
            center: center,
            startRadius: 0,
            endRadius: max(size.width, size.height) * 0.6
        ))

        // Distance arcs — concentric circles at regular yard intervals
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
                with: .color(Color.white.opacity(isMainArc ? 0.10 : 0.05)),
                style: StrokeStyle(lineWidth: 0.6, dash: [2, 3])
            )

            // Label on the right, just above the target line
            let showLabel = step < 10 ? dist.truncatingRemainder(dividingBy: 10) == 0 || dist == step : true
            if showLabel {
                ctx.draw(
                    Text("\(Int(dist))y")
                        .font(DispersionType.mono(8, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.25)),
                    at: CGPoint(x: center.x + r + 2, y: center.y - 6),
                    anchor: .leading
                )
            }
            dist += step
        }

        // Centerline (dashed vertical)
        let centerline = Path { p in
            p.move(to: CGPoint(x: center.x, y: 0))
            p.addLine(to: CGPoint(x: center.x, y: size.height))
        }
        ctx.stroke(
            centerline,
            with: .color(Color.white.opacity(0.15)),
            style: StrokeStyle(lineWidth: 0.6, dash: [4, 5])
        )

        // Target line (horizontal accent)
        let targetLine = Path { p in
            p.move(to: CGPoint(x: 0, y: center.y))
            p.addLine(to: CGPoint(x: size.width, y: center.y))
        }
        ctx.stroke(targetLine, with: .color(DesignTokens.flag.opacity(0.45)), lineWidth: 0.7)

        // Target yardage label
        ctx.draw(
            Text("\(Int(targetYards))y")
                .font(DispersionType.mono(9, weight: .regular))
                .foregroundStyle(DesignTokens.flag.opacity(0.85)),
            at: CGPoint(x: size.width - 8, y: center.y - 8),
            anchor: .trailing
        )

        // Measured live ellipse (centered on bias)
        if measured.n >= 2, measured.carrySd > 0, measured.lateralSd > 0 {
            let biasCenter = CGPoint(
                x: center.x + CGFloat(measured.latBias) * geom.scale,
                y: center.y - CGFloat(measured.longBias) * geom.scale
            )
            for (k, opacity) in [(2.5, 0.18), (1.8, 0.28), (1.2, 0.40)] as [(Double, Double)] {
                let path = Path(ellipseIn: CGRect(
                    x: biasCenter.x - CGFloat(measured.lateralSd * k) * geom.scale,
                    y: biasCenter.y - CGFloat(measured.carrySd * k) * geom.scale,
                    width: CGFloat(measured.lateralSd * k * 2) * geom.scale,
                    height: CGFloat(measured.carrySd * k * 2) * geom.scale
                ))
                ctx.fill(path, with: .color(DesignTokens.bentgrass.opacity(opacity)))
            }
            // Bias arrow
            let arrow = Path { p in
                p.move(to: center)
                p.addLine(to: biasCenter)
            }
            ctx.stroke(
                arrow,
                with: .color(DesignTokens.heat4.opacity(0.55)),
                style: StrokeStyle(lineWidth: 1, dash: [2, 2])
            )
            let biasDot = Path(ellipseIn: CGRect(x: biasCenter.x - 3, y: biasCenter.y - 3, width: 6, height: 6))
            ctx.fill(biasDot, with: .color(DesignTokens.heat4))
        }

        // Target reticle
        let reticle = Path(ellipseIn: CGRect(x: center.x - 9, y: center.y - 9, width: 18, height: 18))
        ctx.stroke(reticle, with: .color(DesignTokens.flag), lineWidth: 1.2)
        ctx.fill(
            Path(ellipseIn: CGRect(x: center.x - 2, y: center.y - 2, width: 4, height: 4)),
            with: .color(DesignTokens.flag)
        )

        // Compass labels
        let compassFont = Font.system(size: 8, design: .monospaced).weight(.medium)
        let compassColor = Color.white.opacity(0.2)
        ctx.draw(Text("LONG").font(compassFont).foregroundStyle(compassColor),
                 at: CGPoint(x: center.x, y: 14), anchor: .center)
        ctx.draw(Text("SHORT").font(compassFont).foregroundStyle(compassColor),
                 at: CGPoint(x: center.x, y: size.height - 14), anchor: .center)
        ctx.draw(Text("L").font(compassFont).foregroundStyle(compassColor),
                 at: CGPoint(x: 12, y: center.y), anchor: .center)
        ctx.draw(Text("R").font(compassFont).foregroundStyle(compassColor),
                 at: CGPoint(x: size.width - 12, y: center.y), anchor: .center)

        // Logged shots
        for (i, shot) in displayShots.enumerated() {
            let p = CGPoint(x: geom.sx(shot.lat), y: geom.sy(shot.long))
            let isLatest = i == displayShots.count - 1

            if isLatest && !displayShots.isEmpty {
                let halo = Path(ellipseIn: CGRect(x: p.x - 10, y: p.y - 10, width: 20, height: 20))
                ctx.fill(halo, with: .color(DesignTokens.primary.opacity(0.2)))
            }

            let r: CGFloat = isLatest ? 5 : 3.5
            let dot = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
            ctx.fill(dot, with: .color(isLatest ? DesignTokens.primary : DesignTokens.cream))
            ctx.stroke(dot, with: .color(DesignTokens.backgroundDeep), lineWidth: 1)

            if displayShots.count <= 20 {
                ctx.draw(
                    Text("\(i + 1)")
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.5)),
                    at: CGPoint(x: p.x, y: p.y - r - 6)
                )
            }
        }

        // Empty hint
        if displayShots.isEmpty {
            ctx.draw(
                Text("TAP WHERE IT LANDED")
                    .font(DispersionType.mono(9, weight: .regular))
                    .tracking(2)
                    .foregroundStyle(Color.white.opacity(0.45)),
                at: CGPoint(x: center.x, y: center.y + 32)
            )
        }
    }

    private func arcStep(for span: Double) -> Double {
        if span <= 15 { return 3 }
        if span <= 35 { return 5 }
        if span <= 70 { return 10 }
        return 20
    }
}
