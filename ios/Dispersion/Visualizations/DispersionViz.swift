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
    public var carry: Double
    public var carrySd: Double
    public var lateralSd: Double
    public var distanceToTarget: Double
    public var zoneWidth: Double?
    public var zoneDepth: Double?
    public var aimLateralYards: Double
    public var pinPosition: PinPosition?
    public var liveProbability: Double?
    public var contours: Int
    public var facets: Int
    public var background: Color
    /// Optional callback for tap on the pin glyph — used by the calculator
    /// so the user can tap the pin to cycle front/middle/back without
    /// going to the header pill.
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

        // Pin position offsets within the green (front = closer to player,
        // back = farther). The viz has +Y = away from player, so pinPosition
        // maps to a fractional offset along the safe zone's depth.
        let pinFraction = pinFractionForPosition(pinPosition)
        let pinY: CGFloat = {
            guard let zd = zoneDepth else { return targetCenter.y }
            // Front pin: y > center (closer to player on screen, since +Y is up = away).
            // Wait — in the viz, smaller y = top of screen = farther from player.
            // So "back" pin (farther) → smaller y, "front" pin (closer) → larger y.
            return targetCenter.y - CGFloat(zd / 2 * pinFraction) * scale
        }()
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
            ctx.stroke(p, with: .color(DesignTokens.primary.opacity(0.55)),
                       style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }

        // 4. Mean dot — where the average shot lands.
        let meanDot = Path(ellipseIn: CGRect(
            x: layout.meanCenter.x - 4,
            y: layout.meanCenter.y - 4,
            width: 8, height: 8
        ))
        ctx.fill(meanDot, with: .color(DesignTokens.primary))
        let meanRing = Path(ellipseIn: CGRect(
            x: layout.meanCenter.x - 6,
            y: layout.meanCenter.y - 6,
            width: 12, height: 12
        ))
        ctx.stroke(meanRing, with: .color(DesignTokens.primary.opacity(0.4)), lineWidth: 1)

        // 5. Flag pin glyph — always at the pin point.
        drawPin(ctx: ctx, at: layout.pinPoint)
    }

    private func drawContours(ctx: GraphicsContext, meanCenter: CGPoint, scale: CGFloat) {
        let kSteps = stride(
            from: 0.6,
            through: 2.6,
            by: (2.6 - 0.6) / Double(max(contours - 1, 1))
        ).map { $0 }
        let palette: [Color] = [
            DesignTokens.heat0, DesignTokens.heat1, DesignTokens.heat2,
            DesignTokens.heat3, DesignTokens.heat4, DesignTokens.heat5,
        ]
        let n = kSteps.count
        for (i, k) in kSteps.enumerated().reversed() {
            let path = ellipsePath(
                center: meanCenter,
                rx: CGFloat(lateralSd) * CGFloat(k) * scale,
                ry: CGFloat(carrySd) * CGFloat(k) * scale,
                facets: facets
            )
            let t = Double(i) / Double(max(n - 1, 1))
            let alpha = 0.05 + t * 0.55
            let color = palette[min(i, palette.count - 1)].opacity(alpha)
            ctx.fill(path, with: .color(color))
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
                    DesignTokens.bentgrass.opacity(0.18),
                    DesignTokens.fairwayShadow.opacity(0.10)
                ]),
                startPoint: CGPoint(x: rect.midX, y: rect.minY),
                endPoint: CGPoint(x: rect.midX, y: rect.maxY)
            )
        )

        // Accent-tinted border, thicker than before.
        ctx.stroke(
            path,
            with: .color(DesignTokens.bentgrass.opacity(0.65)),
            style: StrokeStyle(lineWidth: 1.5)
        )

        // Inner highlight ring at ~80% size — gives the green a "depth" feel.
        let innerRect = rect.insetBy(dx: rect.width * 0.04, dy: rect.height * 0.04)
        let innerR = min(innerRect.width, innerRect.height) * 0.32
        let innerPath = Path(roundedRect: innerRect, cornerRadius: innerR)
        ctx.stroke(
            innerPath,
            with: .color(.white.opacity(0.10)),
            style: StrokeStyle(lineWidth: 0.5)
        )
    }

    private func drawPin(ctx: GraphicsContext, at point: CGPoint) {
        // Stick — vertical line ~22pt tall above the point.
        let stickTop = CGPoint(x: point.x, y: point.y - 22)
        var stick = Path()
        stick.move(to: point)
        stick.addLine(to: stickTop)
        ctx.stroke(stick, with: .color(.white.opacity(0.9)), lineWidth: 1.5)

        // Flag — small triangle at the top, accent-colored.
        var flag = Path()
        flag.move(to: stickTop)
        flag.addLine(to: CGPoint(x: stickTop.x + 12, y: stickTop.y + 4))
        flag.addLine(to: CGPoint(x: stickTop.x, y: stickTop.y + 8))
        flag.closeSubpath()
        ctx.fill(flag, with: .color(DesignTokens.flag))
        ctx.stroke(flag, with: .color(DesignTokens.flag.opacity(0.8)), lineWidth: 0.5)

        // Cup — dark circle at the base.
        let cup = Path(ellipseIn: CGRect(
            x: point.x - 3, y: point.y - 1.5, width: 6, height: 3
        ))
        ctx.fill(cup, with: .color(.black.opacity(0.55)))
        ctx.stroke(cup, with: .color(.white.opacity(0.6)), lineWidth: 0.8)
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

        // Tap target on the pin/flag — 44pt invisible button so the user can
        // cycle pin position by tapping the visualized pin directly.
        if let onPinTap {
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

        // Live probability badge — positioned just above the pin's flag.
        if let p = liveProbability {
            probabilityBadge(p)
                .position(
                    x: layout.pinPoint.x,
                    y: max(28, layout.pinPoint.y - 48)
                )
        }

        // Aim badge — bottom-center of the viz, only when there's a non-zero aim.
        if abs(aimLateralYards) > 0.5 {
            aimBadge
                .position(x: size.width / 2, y: size.height - 38)
        }
    }

    private func probabilityBadge(_ p: Double) -> some View {
        let pct = Int((p * 100).rounded())
        let color = ProbLabelRegistry.of(p).color
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

    private var aimBadge: some View {
        let yards = Int(abs(aimLateralYards).rounded())
        let direction = aimLateralYards < 0 ? "left" : "right"
        let icon = aimLateralYards < 0 ? "arrow.left" : "arrow.right"
        return HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
            Text("Aim \(yards)y \(direction)")
                .font(DispersionType.mono(11, weight: .medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(.black.opacity(0.55))
                .overlay(
                    Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
        .transition(.opacity.combined(with: .scale(scale: 0.92)))
    }
}
