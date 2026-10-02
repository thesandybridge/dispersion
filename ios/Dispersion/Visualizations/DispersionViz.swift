// Calculator's marquee visual — a golf-y "target situation" rather than a math
// diagram. Renders:
//
//   • Concentric probability contours (heat palette, outermost faintest)
//   • The safe zone as a soft green-shaped polygon with subtle gradient fill
//     and an accent-tinted border
//   • A flag-pin glyph at the target center, positioned within the green based
//     on pinPosition (front / middle / back)
//   • The dispersion mean shifted laterally by the player's aim offset
//   • An optional live P(zone) % badge floating beside the pin
//   • A slim "aim X y left/right" badge if the lateral aim is non-zero
//
// SwiftUI Canvas + a SwiftUI overlay for the badges (so text reflows naturally
// and animates with .contentTransition).

import SwiftUI

public struct DispersionViz: View {
    @Environment(\.palette) private var palette

    public var carry: Double
    public var carrySd: Double
    public var lateralSd: Double
    public var distanceToTarget: Double
    public var zoneWidth: Double?
    public var zoneDepth: Double?
    public var aimLateralYards: Double
    public var pinPosition: PinPosition?
    /// Whether the target represents a green (with a flag pin) or a
    /// fairway-style corridor (no pin — show a clean aim crosshair).
    /// Defaults to .green for backward compatibility with the bag preview.
    public var zoneKind: ZoneKind
    public var liveProbability: Double?
    public var contours: Int
    public var facets: Int
    public var background: Color
    /// Optional callback for tap on the pin glyph — used by the calculator
    /// so the user can tap the pin to cycle front/middle/back without
    /// going to the header pill. Only invoked when `zoneKind == .green`.
    public var onPinTap: (() -> Void)?

    public init(
        carry: Double,
        carrySd: Double,
        lateralSd: Double,
        distanceToTarget: Double,
        zoneWidth: Double? = nil,
        zoneDepth: Double? = nil,
        aimLateralYards: Double = 0,
        pinPosition: PinPosition? = nil,
        zoneKind: ZoneKind = .green,
        liveProbability: Double? = nil,
        contours: Int = 6,
        facets: Int = 28,
        background: Color = DesignTokens.backgroundDeep,
        onPinTap: (() -> Void)? = nil
    ) {
        self.carry = carry
        self.carrySd = carrySd
        self.lateralSd = lateralSd
        self.distanceToTarget = distanceToTarget
        self.zoneWidth = zoneWidth
        self.zoneDepth = zoneDepth
        self.aimLateralYards = aimLateralYards
        self.pinPosition = pinPosition
        self.zoneKind = zoneKind
        self.liveProbability = liveProbability
        self.contours = contours
        self.facets = facets
        self.background = background
        self.onPinTap = onPinTap
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                Canvas { ctx, size in
                    drawScene(ctx: ctx, size: size)
                }
                .background(background)

                // Floating SwiftUI overlays positioned in viz coordinate space.
                overlays(size: geo.size)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    // MARK: - Geometry helpers

    private struct Layout {
        let scale: CGFloat
        let targetCenter: CGPoint
        let meanCenter: CGPoint
        let zoneRect: CGRect?
        let pinPoint: CGPoint
    }

    private func computeLayout(in size: CGSize) -> Layout {
        let pad: CGFloat = 28
        let zoneHalfW = (zoneWidth ?? 0) / 2 + 5
        let zoneHalfD = (zoneDepth ?? 0) / 2 + 5
        let longSpan = max(carrySd * 3.5, zoneHalfD, 25)
        let latSpan = max(
            lateralSd * 3.5 + abs(aimLateralYards),
            zoneHalfW + abs(aimLateralYards),
            18
        )
        let fitScaleX = (size.width - pad * 2) / (latSpan * 2)
        let fitScaleY = (size.height - pad * 2) / (longSpan * 2)
        let scale = min(fitScaleX, fitScaleY)

        let targetCenter = CGPoint(x: size.width / 2, y: size.height / 2)
        let meanLong = carry - distanceToTarget
        let meanCenter = CGPoint(
            x: targetCenter.x + CGFloat(aimLateralYards) * scale,
            y: targetCenter.y - CGFloat(meanLong) * scale
        )

        var zoneRect: CGRect?
        if let zw = zoneWidth, let zd = zoneDepth {
            zoneRect = CGRect(
                x: targetCenter.x - CGFloat(zw / 2) * scale,
                y: targetCenter.y - CGFloat(zd / 2) * scale,
                width: CGFloat(zw) * scale,
                height: CGFloat(zd) * scale
            )
        }

        // Pin position offsets only apply to greens — fairway targets aim at
        // the geometric center of the corridor.
        let pinY: CGFloat
        if zoneKind == .green, let zd = zoneDepth {
            // Front pin: closer to the player, which is *down* on screen
            // (the viz puts the player at +Y / bottom). So front → larger y.
            let pinFraction = pinFractionForPosition(pinPosition)
            pinY = targetCenter.y - CGFloat(zd / 2 * pinFraction) * scale
        } else {
            pinY = targetCenter.y
        }
        let pinPoint = CGPoint(x: targetCenter.x, y: pinY)

        return Layout(
            scale: scale,
            targetCenter: targetCenter,
            meanCenter: meanCenter,
            zoneRect: zoneRect,
            pinPoint: pinPoint
        )
    }

    /// -1 (front, near edge) → 0 (middle) → +1 (back, far edge).
    private func pinFractionForPosition(_ pos: PinPosition?) -> Double {
        switch pos {
        case .some(.front):  return -0.65
        case .some(.middle), .none: return 0
        case .some(.back):   return 0.65
        }
    }

    // MARK: - Canvas drawing

    private func drawScene(ctx: GraphicsContext, size: CGSize) {
        let layout = computeLayout(in: size)

        // 1. Probability contours, dim → bright as we go inward.
        drawContours(ctx: ctx, meanCenter: layout.meanCenter, scale: layout.scale)

        // 2. Safe-zone "green" — soft polygon with gradient fill.
        if let rect = layout.zoneRect {
            drawSafeZone(ctx: ctx, rect: rect)
        }

        // 3. Aim line — connects pin to dispersion mean. Tells the user
        // "your shots will cluster *here*, away from the pin."
        if abs(aimLateralYards) > 0.5 || abs(carry - distanceToTarget) > 0.5 {
            var p = Path()
            p.move(to: layout.pinPoint)
            p.addLine(to: layout.meanCenter)
            ctx.stroke(p, with: .color(palette.primary.opacity(0.55)),
                       style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }

        // 4. Mean dot — where the average shot lands.
        let meanDot = Path(ellipseIn: CGRect(
            x: layout.meanCenter.x - 4,
            y: layout.meanCenter.y - 4,
            width: 8, height: 8
        ))
        ctx.fill(meanDot, with: .color(palette.primary))
        let meanRing = Path(ellipseIn: CGRect(
            x: layout.meanCenter.x - 6,
            y: layout.meanCenter.y - 6,
            width: 12, height: 12
        ))
        ctx.stroke(meanRing, with: .color(palette.primary.opacity(0.4)), lineWidth: 1)

        // 5. Target glyph — flag pin for greens, corridor crosshair for fairway.
        switch zoneKind {
        case .green:
            drawPin(ctx: ctx, at: layout.pinPoint)
        case .fairway:
            drawFairwayMarker(ctx: ctx, at: layout.pinPoint)
        }
    }

    private func drawContours(ctx: GraphicsContext, meanCenter: CGPoint, scale: CGFloat) {
        let kSteps = stride(
            from: 0.6,
            through: 2.6,
            by: (2.6 - 0.6) / Double(max(contours - 1, 1))
        ).map { $0 }
        let ramp = palette.heatRamp
        let n = kSteps.count
        for (i, k) in kSteps.enumerated().reversed() {
            let path = ellipsePath(
                center: meanCenter,
                rx: CGFloat(lateralSd) * CGFloat(k) * scale,
                ry: CGFloat(carrySd) * CGFloat(k) * scale,
                facets: max(facets, 96)
            )
            let density = 1 - Double(i) / Double(max(n - 1, 1))
            let color = ramp[Int(density * Double(ramp.count - 1))]
            ctx.fill(path, with: .color(color.opacity(0.08 + density * 0.3)))
            ctx.stroke(path, with: .color(color.opacity(0.25 + density * 0.35)), lineWidth: 1)
        }
    }

    private func drawSafeZone(ctx: GraphicsContext, rect: CGRect) {
        // A green-shaped polygon: rounded rect with very generous corner
        // radius (almost stadium-shaped if the zone is roughly square).
        let r = min(rect.width, rect.height) * 0.32
        let path = Path(roundedRect: rect, cornerRadius: r)

        // Soft fill — not opaque; the contours behind it should still read.
        ctx.fill(
            path,
            with: .linearGradient(
                Gradient(colors: [
                    palette.primary.opacity(0.08),
                    palette.primary.opacity(0.03)
                ]),
                startPoint: CGPoint(x: rect.midX, y: rect.minY),
                endPoint: CGPoint(x: rect.midX, y: rect.maxY)
            )
        )

        // Accent-tinted border, thicker than before.
        ctx.stroke(
            path,
            with: .color(palette.primary.opacity(0.5)),
            style: StrokeStyle(lineWidth: 1.5)
        )

        // Inner highlight ring at ~80% size — gives the green a "depth" feel.
        let innerRect = rect.insetBy(dx: rect.width * 0.04, dy: rect.height * 0.04)
        let innerR = min(innerRect.width, innerRect.height) * 0.32
        let innerPath = Path(roundedRect: innerRect, cornerRadius: innerR)
        ctx.stroke(
            innerPath,
            with: .color(DesignTokens.foreground.opacity(0.10)),
            style: StrokeStyle(lineWidth: 0.5)
        )
    }

    /// Aim marker for fairway-style targets — a clean reticle ring with
    /// short tick marks. No flag (there's nothing to aim AT, just a corridor
    /// to land IN), no cup (no hole), but still a clear "aim here" signal.
    private func drawFairwayMarker(ctx: GraphicsContext, at point: CGPoint) {
        let outerRadius: CGFloat = 11
        let coreRadius: CGFloat = 2.5
        let tickInner: CGFloat = 4
        let tickOuter: CGFloat = 16

        let ring = Path(ellipseIn: CGRect(
            x: point.x - outerRadius,
            y: point.y - outerRadius,
            width: outerRadius * 2,
            height: outerRadius * 2
        ))
        ctx.stroke(ring, with: .color(DesignTokens.foreground.opacity(0.85)), lineWidth: 1.2)

        let core = Path(ellipseIn: CGRect(
            x: point.x - coreRadius,
            y: point.y - coreRadius,
            width: coreRadius * 2,
            height: coreRadius * 2
        ))
        ctx.fill(core, with: .color(DesignTokens.foreground.opacity(0.95)))

        var ticks = Path()
        ticks.move(to: CGPoint(x: point.x - tickOuter, y: point.y))
        ticks.addLine(to: CGPoint(x: point.x - tickInner, y: point.y))
        ticks.move(to: CGPoint(x: point.x + tickInner, y: point.y))
        ticks.addLine(to: CGPoint(x: point.x + tickOuter, y: point.y))
        ticks.move(to: CGPoint(x: point.x, y: point.y - tickOuter))
        ticks.addLine(to: CGPoint(x: point.x, y: point.y - tickInner))
        ticks.move(to: CGPoint(x: point.x, y: point.y + tickInner))
        ticks.addLine(to: CGPoint(x: point.x, y: point.y + tickOuter))
        ctx.stroke(ticks, with: .color(DesignTokens.foreground.opacity(0.7)), lineWidth: 1)
    }

    private func drawPin(ctx: GraphicsContext, at point: CGPoint) {
        // Stick — vertical line ~22pt tall above the point.
        let stickTop = CGPoint(x: point.x, y: point.y - 22)
        var stick = Path()
        stick.move(to: point)
        stick.addLine(to: stickTop)
        ctx.stroke(stick, with: .color(DesignTokens.foreground.opacity(0.9)), lineWidth: 1.5)

        // Flag — small triangle at the top, accent-colored.
        var flag = Path()
        flag.move(to: stickTop)
        flag.addLine(to: CGPoint(x: stickTop.x + 12, y: stickTop.y + 4))
        flag.addLine(to: CGPoint(x: stickTop.x, y: stickTop.y + 8))
        flag.closeSubpath()
        ctx.fill(flag, with: .color(palette.flag))
        ctx.stroke(flag, with: .color(palette.flag.opacity(0.8)), lineWidth: 0.5)

        // Cup — dark circle at the base.
        let cup = Path(ellipseIn: CGRect(
            x: point.x - 3, y: point.y - 1.5, width: 6, height: 3
        ))
        ctx.fill(cup, with: .color(.black.opacity(0.55)))
        ctx.stroke(cup, with: .color(DesignTokens.foreground.opacity(0.6)), lineWidth: 0.8)
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

    // MARK: - SwiftUI overlays

    @ViewBuilder
    private func overlays(size: CGSize) -> some View {
        let layout = computeLayout(in: size)

        // Tap target on the pin — only for green zones. 44pt invisible
        // button so the user can cycle pin position by tapping the
        // visualized pin directly.
        if zoneKind == .green, let onPinTap {
            Button {
                onPinTap()
            } label: {
                Color.clear
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .position(
                x: layout.pinPoint.x,
                // Pin glyph center is at pinPoint.y - 11 (stick midpoint)
                y: layout.pinPoint.y - 11
            )
            .accessibilityLabel("Pin position")
            .accessibilityHint("Tap to cycle front, middle, back")
        }

        // Live probability badge — placed above the target glyph. The flag
        // is taller than the fairway crosshair, so we offset further when
        // there's a pin to clear.
        if let p = liveProbability {
            let badgeOffset: CGFloat = (zoneKind == .green) ? 48 : 30
            probabilityBadge(p)
                .position(
                    x: layout.pinPoint.x,
                    y: max(28, layout.pinPoint.y - badgeOffset)
                )
        }

        // Aim status badge intentionally lives outside the viz now —
        // CalculatorScreen renders it in the conditions row above the
        // recommended card so the system tab bar can't clip it.
    }

    private func probabilityBadge(_ p: Double) -> some View {
        let pct = Int((p * 100).rounded())
        let color = ProbLabelRegistry.of(p, palette: palette).color
        return Text("\(pct)%")
            .font(DispersionType.display(20, weight: .regular))
            .monospacedDigit()
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(.black.opacity(0.55))
                    .overlay(
                        Capsule().strokeBorder(color.opacity(0.45), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.45), radius: 8, y: 3)
            .contentTransition(.numericText())
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: pct)
    }

}
