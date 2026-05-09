// Linear putting lane visualization. Putting is a directional skill — you
// stand at one end and aim down the line at the cup — so a top-down lane
// reads more naturally than concentric rings ever did. The cup sits at
// the top, the player sits at the bottom, distance ticks run up the
// middle, and the user taps where the ball came to rest.
//
// Tapping inside the cup zone counts as a make. Tapping anywhere else
// records the residual distance from the cup (used for lag stats).

import SwiftUI

public struct PuttingGreenField: View {
    @Environment(\.palette) private var palette

    /// Practice distance in feet — the distance from the player tee at the
    /// bottom of the view to the cup at the top.
    public var practiceDistanceFeet: Double

    /// Last logged ball position (feet from cup, +X right, +Y past cup).
    public var lastLandingFeet: CGPoint?

    /// Cup radius in feet — anything tapped within this distance counts
    /// as made. Forgiving multiplier applied at tap time so the cup is
    /// finger-friendly without claiming everything as a make.
    public var cupRadiusFeet: Double = 0.21

    public var onLog: ((PuttingGreenField.Tap) -> Void)?
    public var onDrag: ((PuttingGreenField.Tap?) -> Void)?

    public struct Tap: Sendable {
        public let made: Bool
        public let residualFeet: Double
        public let x: Double          // feet, right of cup
        public let y: Double          // feet, past cup (toward back of green)
    }

    @State private var dragLanding: CGPoint?

    public init(
        practiceDistanceFeet: Double,
        lastLandingFeet: CGPoint? = nil,
        cupRadiusFeet: Double = 0.21,
        onLog: ((Tap) -> Void)? = nil,
        onDrag: ((Tap?) -> Void)? = nil
    ) {
        self.practiceDistanceFeet = practiceDistanceFeet
        self.lastLandingFeet = lastLandingFeet
        self.cupRadiusFeet = cupRadiusFeet
        self.onLog = onLog
        self.onDrag = onDrag
    }

    public var body: some View {
        GeometryReader { geo in
            let geom = layout(in: geo.size)
            ZStack {
                Canvas { ctx, _ in
                    drawScene(
                        ctx: ctx,
                        size: geo.size,
                        geom: geom,
                        liveLanding: dragLanding ?? lastLandingFeet,
                        isDragging: dragLanding != nil
                    )
                }
                if onLog != nil {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let xFeet = Double((value.location.x - geom.cup.x) / geom.scale)
                                    let yFeet = Double((geom.cup.y - value.location.y) / geom.scale)
                                    if dragLanding == nil { Haptics.light() }
                                    dragLanding = CGPoint(x: xFeet, y: yFeet)
                                    onDrag?(makeTap(x: xFeet, y: yFeet))
                                }
                                .onEnded { value in
                                    let xFeet = Double((value.location.x - geom.cup.x) / geom.scale)
                                    let yFeet = Double((geom.cup.y - value.location.y) / geom.scale)
                                    let tap = makeTap(x: xFeet, y: yFeet)
                                    dragLanding = nil
                                    onDrag?(nil)
                                    Haptics.medium()
                                    onLog?(tap)
                                }
                        )
                }
            }
        }
    }

    private func makeTap(x: Double, y: Double) -> Tap {
        let residual = sqrt(x * x + y * y)
        let made = residual <= cupRadiusFeet * 8
        return Tap(made: made, residualFeet: residual, x: x, y: y)
    }

    // MARK: - Layout

    private struct Geom {
        var cup: CGPoint        // anchor point — cup center
        var tee: CGPoint        // player tee at the bottom of the lane
        var scale: CGFloat      // pixels per foot
        var laneWidth: CGFloat
        var size: CGSize
    }

    private func layout(in size: CGSize) -> Geom {
        // Lane runs vertically. Reserve some headroom so the flag/cup don't
        // crowd the top, and footer space for the tee.
        let topPad: CGFloat = 56
        let bottomPad: CGFloat = 64
        let usableHeight = max(size.height - topPad - bottomPad, 100)
        // Distance from cup (top) to tee (bottom) in feet, with a touch of
        // slack past the practice distance so a long miss has room to land.
        let visibleFeet = max(practiceDistanceFeet * 1.1, practiceDistanceFeet + 2)
        let scale = usableHeight / CGFloat(visibleFeet)
        let cup = CGPoint(x: size.width / 2, y: topPad)
        let tee = CGPoint(x: size.width / 2, y: topPad + CGFloat(practiceDistanceFeet) * scale)
        let laneWidth = min(size.width * 0.55, 220)
        return Geom(cup: cup, tee: tee, scale: scale, laneWidth: laneWidth, size: size)
    }

    // MARK: - Draw

    private func drawScene(
        ctx: GraphicsContext,
        size: CGSize,
        geom: Geom,
        liveLanding: CGPoint?,
        isDragging: Bool
    ) {
        let bgRect = CGRect(origin: .zero, size: size)

        // 1. Green field — soft radial gradient bg.
        ctx.fill(
            Path(bgRect),
            with: .radialGradient(
                Gradient(colors: [
                    DesignTokens.bentgrass.opacity(0.32),
                    DesignTokens.fairwayShadow.opacity(0.22),
                    DesignTokens.pine.opacity(0.30),
                ]),
                center: CGPoint(x: size.width / 2, y: size.height * 0.55),
                startRadius: 0,
                endRadius: max(size.width, size.height) * 0.7
            )
        )

        // 2. Faint horizontal grain — gives the green texture without
        // competing for attention. Lines run perpendicular to the putt line
        // so they don't fight the eye's vertical reading direction.
        let grainSpacing: CGFloat = 14
        var y: CGFloat = 0
        while y < size.height {
            var p = Path()
            p.move(to: CGPoint(x: 0, y: y))
            p.addLine(to: CGPoint(x: size.width, y: y))
            ctx.stroke(p, with: .color(.white.opacity(0.025)), lineWidth: 0.5)
            y += grainSpacing
        }

        // 3. Putting lane — soft cream/tan rounded-rect stripe running from
        // tee to slightly past the cup. Reads as a polished line on the green.
        let laneRect = CGRect(
            x: geom.cup.x - geom.laneWidth / 2,
            y: geom.cup.y - 18,
            width: geom.laneWidth,
            height: (geom.tee.y - geom.cup.y) + 36
        )
        let lanePath = Path(roundedRect: laneRect, cornerRadius: geom.laneWidth * 0.45)
        ctx.fill(
            lanePath,
            with: .linearGradient(
                Gradient(colors: [
                    DesignTokens.bentgrass.opacity(0.22),
                    DesignTokens.bentgrass.opacity(0.10),
                ]),
                startPoint: CGPoint(x: laneRect.midX, y: laneRect.minY),
                endPoint: CGPoint(x: laneRect.midX, y: laneRect.maxY)
            )
        )
        ctx.stroke(
            lanePath,
            with: .color(DesignTokens.bentgrass.opacity(0.42)),
            lineWidth: 1
        )

        // 4. Putt line — dashed centerline from cup to tee. The visual
        // promise: "send the ball straight down this line."
        var line = Path()
        line.move(to: geom.cup)
        line.addLine(to: geom.tee)
        ctx.stroke(
            line,
            with: .color(.white.opacity(0.20)),
            style: StrokeStyle(lineWidth: 1, dash: [4, 5])
        )

        // 5. Distance ticks along the line. Step depends on practice
        // distance — coarser for long putts so the lane doesn't get crowded.
        let tickStep: Double = practiceDistanceFeet >= 20
            ? 5
            : (practiceDistanceFeet >= 10 ? 3 : 1)
        var d = tickStep
        while d <= practiceDistanceFeet - 0.1 {
            let yPos = geom.cup.y + CGFloat(d) * geom.scale
            // tick mark
            var tick = Path()
            tick.move(to: CGPoint(x: geom.cup.x - 14, y: yPos))
            tick.addLine(to: CGPoint(x: geom.cup.x - 6, y: yPos))
            tick.move(to: CGPoint(x: geom.cup.x + 6, y: yPos))
            tick.addLine(to: CGPoint(x: geom.cup.x + 14, y: yPos))
            ctx.stroke(tick, with: .color(.white.opacity(0.40)), lineWidth: 1)

            ctx.draw(
                Text("\(Int(d)) ft")
                    .font(DispersionType.mono(9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55)),
                at: CGPoint(x: geom.cup.x + 18, y: yPos),
                anchor: .leading
            )
            d += tickStep
        }

        // 6. Cup glyph at the top — clean dark hole + flag pin rising above.
        let cupR: CGFloat = 9
        let cupRect = CGRect(x: geom.cup.x - cupR, y: geom.cup.y - cupR, width: cupR * 2, height: cupR * 2)
        ctx.fill(Path(ellipseIn: cupRect), with: .color(.black.opacity(0.85)))
        ctx.stroke(Path(ellipseIn: cupRect), with: .color(.white.opacity(0.7)), lineWidth: 1.2)
        // Pin
        var pin = Path()
        pin.move(to: geom.cup)
        pin.addLine(to: CGPoint(x: geom.cup.x, y: geom.cup.y - 38))
        ctx.stroke(pin, with: .color(.white.opacity(0.92)), lineWidth: 1.6)
        // Flag
        var flag = Path()
        flag.move(to: CGPoint(x: geom.cup.x, y: geom.cup.y - 38))
        flag.addLine(to: CGPoint(x: geom.cup.x + 14, y: geom.cup.y - 33))
        flag.addLine(to: CGPoint(x: geom.cup.x, y: geom.cup.y - 28))
        flag.closeSubpath()
        ctx.fill(flag, with: .color(palette.flag))

        // 7. Distance label above the flag.
        ctx.draw(
            Text("\(Int(practiceDistanceFeet)) ft")
                .font(DispersionType.mono(11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85)),
            at: CGPoint(x: geom.cup.x, y: geom.cup.y - 50),
            anchor: .center
        )

        // 8. Tee marker at the bottom — small ground tick + label.
        let teeBarW: CGFloat = 32
        var teeBar = Path()
        teeBar.move(to: CGPoint(x: geom.tee.x - teeBarW / 2, y: geom.tee.y))
        teeBar.addLine(to: CGPoint(x: geom.tee.x + teeBarW / 2, y: geom.tee.y))
        ctx.stroke(teeBar, with: .color(.white.opacity(0.55)), lineWidth: 2)
        ctx.draw(
            Text("YOU")
                .font(DispersionType.mono(9, weight: .semibold))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.65)),
            at: CGPoint(x: geom.tee.x, y: geom.tee.y + 16),
            anchor: .center
        )

        // 9. Landing point — shows the user's last logged putt (or live drag
        // preview while finger is down). During a drag we additionally render
        // a dashed "lag line" from cup to landing so the user can see the
        // residual at a glance.
        if let landing = liveLanding {
            let p = CGPoint(
                x: geom.cup.x + CGFloat(landing.x) * geom.scale,
                y: geom.cup.y + CGFloat(-landing.y) * geom.scale
            )
            // (note: landing.y > 0 means past the cup — moves UP the screen
            //  from cup, which is decreasing y in screen coords. landing.y < 0
            //  means short — moves DOWN. -landing.y handles both.)

            if isDragging {
                // Lag line from cup to live cursor.
                var lag = Path()
                lag.move(to: geom.cup)
                lag.addLine(to: p)
                ctx.stroke(
                    lag,
                    with: .color(palette.primary.opacity(0.65)),
                    style: StrokeStyle(lineWidth: 1.2, dash: [3, 3])
                )
            }

            let halo = Path(ellipseIn: CGRect(x: p.x - 14, y: p.y - 14, width: 28, height: 28))
            ctx.fill(halo, with: .color(palette.primary.opacity(isDragging ? 0.40 : 0.30)))
            let dotR: CGFloat = isDragging ? 7 : 5.5
            let dot = Path(ellipseIn: CGRect(x: p.x - dotR, y: p.y - dotR, width: dotR * 2, height: dotR * 2))
            ctx.fill(dot, with: .color(palette.primary))
            ctx.stroke(dot, with: .color(.white.opacity(0.7)), lineWidth: 1.2)
        }

        // 10. Empty hint — only when no landing has been logged or previewed.
        if liveLanding == nil {
            ctx.draw(
                Text("TAP OR DRAG WHERE IT STOPPED")
                    .font(DispersionType.mono(10, weight: .semibold))
                    .tracking(2.4)
                    .foregroundStyle(.white.opacity(0.45)),
                at: CGPoint(x: size.width / 2, y: size.height - 28),
                anchor: .center
            )
        }
    }
}
