// Port of app/src/components/range/RangeRadarField.tsx. Polar radar tap
// surface for range mode. Concentric reference σ rings + radial spokes around
// the target, live measured ellipse (drawn from session shots), tap-to-add
// gesture.

import SwiftUI

public struct RangeRadarField: View {
    public var targetYards: Double
    public var referenceCarrySd: Double
    public var referenceLateralSd: Double
    public var measured: DispersionStats
    public var shots: [ShotXY]
    public var onTap: ((ShotXY) -> Void)?
    public var readOnly: Bool

    public init(
        targetYards: Double,
        referenceCarrySd: Double,
        referenceLateralSd: Double,
        measured: DispersionStats,
        shots: [ShotXY],
        onTap: ((ShotXY) -> Void)? = nil,
        readOnly: Bool = false
    ) {
        self.targetYards = targetYards
        self.referenceCarrySd = referenceCarrySd
        self.referenceLateralSd = referenceLateralSd
        self.measured = measured
        self.shots = shots
        self.onTap = onTap
        self.readOnly = readOnly
    }

    public var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let geom = layout(in: size)
            ZStack {
                Canvas { ctx, _ in
                    drawScene(ctx: ctx, size: size, geom: geom)
                }
                if !readOnly, let onTap {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            TapGesture()
                                .sequenced(before: DragGesture(minimumDistance: 0))
                                .onEnded { value in
                                    if case .second(_, let drag?) = value {
                                        let p = drag.location
                                        onTap(geom.toShot(p))
                                    }
                                }
                        )
                        .onTapGesture { p in
                            onTap(geom.toShot(p))
                        }
                }
            }
        }
    }

    // MARK: layout

    private struct Geom {
        var center: CGPoint
        var scaleX: CGFloat
        var scaleY: CGFloat
        var longSpan: Double
        var latSpan: Double
        var size: CGSize

        func sx(_ lat: Double) -> CGFloat { center.x + CGFloat(lat) * scaleX }
        func sy(_ long: Double) -> CGFloat { center.y - CGFloat(long) * scaleY }
        func toShot(_ p: CGPoint) -> ShotXY {
            let lat = (p.x - center.x) / scaleX
            let long = (center.y - p.y) / scaleY
            return ShotXY(lat: Double(lat), long: Double(long))
        }
    }

    private func layout(in size: CGSize) -> Geom {
        let pad: CGFloat = 28
        let longSpan = max(referenceCarrySd * 3.5, 25)
        let latSpan = max(referenceLateralSd * 3.5, 18)
        return Geom(
            center: CGPoint(x: size.width / 2, y: size.height / 2),
            scaleX: (size.width - pad * 2) / CGFloat(latSpan * 2),
            scaleY: (size.height - pad * 2) / CGFloat(longSpan * 2),
            longSpan: longSpan,
            latSpan: latSpan,
            size: size
        )
    }

    // MARK: draw

    private func drawScene(ctx: GraphicsContext, size: CGSize, geom: Geom) {
        let center = geom.center
        let pad: CGFloat = 28

        // Background gradient.
        let bgRect = CGRect(origin: .zero, size: size)
        ctx.fill(Path(bgRect), with: .radialGradient(
            Gradient(colors: [DesignTokens.background, DesignTokens.backgroundDeep]),
            center: center,
            startRadius: 0,
            endRadius: max(size.width, size.height) * 0.6
        ))

        // Reference σ ellipses (1, 2, 3σ).
        for k in 1...3 {
            let kf = Double(k)
            let path = Path(ellipseIn: CGRect(
                x: center.x - CGFloat(referenceLateralSd * kf) * geom.scaleX,
                y: center.y - CGFloat(referenceCarrySd * kf) * geom.scaleY,
                width: CGFloat(referenceLateralSd * kf * 2) * geom.scaleX,
                height: CGFloat(referenceCarrySd * kf * 2) * geom.scaleY
            ))
            ctx.stroke(
                path,
                with: .color(Color.white.opacity(0.08)),
                style: StrokeStyle(lineWidth: 0.6, dash: k == 3 ? [1, 4] : [2, 3])
            )

            // Label
            let labelX = center.x + CGFloat(referenceLateralSd * kf) * geom.scaleX + 4
            ctx.draw(
                Text("\(k)σ")
                    .font(DispersionType.mono(8, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.32)),
                at: CGPoint(x: labelX, y: center.y - 4)
            )
        }

        // Radial spokes every 30°.
        let r = max(size.width, size.height)
        for deg in stride(from: 0.0, to: 180.0, by: 30) {
            let rad = deg * .pi / 180
            let spoke = Path { p in
                p.move(to: CGPoint(x: center.x + CGFloat(cos(rad)) * r, y: center.y + CGFloat(sin(rad)) * r))
                p.addLine(to: CGPoint(x: center.x - CGFloat(cos(rad)) * r, y: center.y - CGFloat(sin(rad)) * r))
            }
            ctx.stroke(spoke, with: .color(Color.white.opacity(0.05)), lineWidth: 0.5)
        }

        // Centerline (dashed vertical).
        let centerline = Path { p in
            p.move(to: CGPoint(x: center.x, y: pad - 6))
            p.addLine(to: CGPoint(x: center.x, y: size.height - pad + 6))
        }
        ctx.stroke(
            centerline,
            with: .color(Color.white.opacity(0.18)),
            style: StrokeStyle(lineWidth: 0.6, dash: [4, 5])
        )

        // Target line (horizontal accent).
        let targetLine = Path { p in
            p.move(to: CGPoint(x: pad - 6, y: center.y))
            p.addLine(to: CGPoint(x: size.width - pad + 6, y: center.y))
        }
        ctx.stroke(targetLine, with: .color(DesignTokens.flag.opacity(0.55)), lineWidth: 0.9)

        ctx.draw(
            Text("\(Int(targetYards))y")
                .font(DispersionType.mono(9, weight: .regular))
                .foregroundStyle(DesignTokens.flag.opacity(0.85)),
            at: CGPoint(x: size.width - pad + 6, y: center.y + 3),
            anchor: .leading
        )

        // Measured live ellipse (centered on bias, not target).
        if measured.n >= 2, measured.carrySd > 0, measured.lateralSd > 0 {
            let biasCenter = CGPoint(
                x: center.x + CGFloat(measured.latBias) * geom.scaleX,
                y: center.y - CGFloat(measured.longBias) * geom.scaleY
            )
            for (k, opacity) in [(2.5, 0.18), (1.8, 0.28), (1.2, 0.40)] {
                let path = Path(ellipseIn: CGRect(
                    x: biasCenter.x - CGFloat(measured.lateralSd * k) * geom.scaleX,
                    y: biasCenter.y - CGFloat(measured.carrySd * k) * geom.scaleY,
                    width: CGFloat(measured.lateralSd * k * 2) * geom.scaleX,
                    height: CGFloat(measured.carrySd * k * 2) * geom.scaleY
                ))
                ctx.fill(path, with: .color(DesignTokens.bentgrass.opacity(opacity)))
            }
            // Bias arrow.
            let arrow = Path { p in
                p.move(to: center)
                p.addLine(to: biasCenter)
            }
            ctx.stroke(
                arrow,
                with: .color(DesignTokens.heat4.opacity(0.55)),
                style: StrokeStyle(lineWidth: 1, dash: [2, 2])
            )
            let dot = Path(ellipseIn: CGRect(x: biasCenter.x - 3, y: biasCenter.y - 3, width: 6, height: 6))
            ctx.fill(dot, with: .color(DesignTokens.heat4))
        }

        // Target reticle.
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
                 at: CGPoint(x: center.x, y: pad - 10), anchor: .center)
        ctx.draw(Text("SHORT").font(compassFont).foregroundStyle(compassColor),
                 at: CGPoint(x: center.x, y: size.height - pad + 12), anchor: .center)
        ctx.draw(Text("L").font(compassFont).foregroundStyle(compassColor),
                 at: CGPoint(x: pad - 10, y: center.y), anchor: .center)
        ctx.draw(Text("R").font(compassFont).foregroundStyle(compassColor),
                 at: CGPoint(x: size.width - pad + 10, y: center.y), anchor: .center)

        // Logged shots
        for (i, shot) in shots.enumerated() {
            let p = CGPoint(x: geom.sx(shot.lat), y: geom.sy(shot.long))
            let isLatest = i == shots.count - 1

            // Halo on latest shot
            if isLatest && shots.count > 0 {
                let halo = Path(ellipseIn: CGRect(x: p.x - 10, y: p.y - 10, width: 20, height: 20))
                ctx.fill(halo, with: .color(DesignTokens.primary.opacity(0.2)))
            }

            let r: CGFloat = isLatest ? 5 : 3.5
            let dot = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
            ctx.fill(dot, with: .color(isLatest ? DesignTokens.primary : DesignTokens.cream))
            ctx.stroke(dot, with: .color(DesignTokens.backgroundDeep), lineWidth: 1)

            // Shot number
            if shots.count <= 20 {
                ctx.draw(
                    Text("\(i + 1)")
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.5)),
                    at: CGPoint(x: p.x, y: p.y - r - 6)
                )
            }
        }

        // Empty hint
        if shots.isEmpty {
            ctx.draw(
                Text("TAP WHERE IT LANDED")
                    .font(DispersionType.mono(9, weight: .regular))
                    .tracking(2)
                    .foregroundStyle(Color.white.opacity(0.45)),
                at: CGPoint(x: center.x, y: center.y + 32)
            )
        }
    }
}
