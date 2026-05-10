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
    /// as made. Defaults to a regulation cup (4.25 in diameter →
    /// 0.177 ft radius). The user has a finger-precise drag, so we use
    /// the real cup size — no forgiving margin.
    public var cupRadiusFeet: Double = 0.177

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
        cupRadiusFeet: Double = 0.177,
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
        let made = residual <= cupRadiusFeet
        return Tap(made: made, residualFeet: residual, x: x, y: y)
    }

    // MARK: - Layout

    private struct Geom {
        var cup: CGPoint        // cup center (anchor — y=0 in feet)
        var tee: CGPoint        // player tee at the bottom of the line
        var scale: CGFloat      // pixels per foot
        var size: CGSize
    }

    private func layout(in size: CGSize) -> Geom {
        // Reserve modest headroom for the cup + landing dots that may sit
        // past the cup, plus enough footer space that the tee marker isn't
        // hugging the bottom edge.
        let topPad: CGFloat = 40
        let bottomPad: CGFloat = 48
        let usableHeight = max(size.height - topPad - bottomPad, 100)
        let visibleFeet = max(practiceDistanceFeet * 1.1, practiceDistanceFeet + 2)
        let scale = usableHeight / CGFloat(visibleFeet)
        let cup = CGPoint(x: size.width / 2, y: topPad)
        let tee = CGPoint(x: size.width / 2, y: topPad + CGFloat(practiceDistanceFeet) * scale)
        return Geom(cup: cup, tee: tee, scale: scale, size: size)
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

        // 1. Green — soft bentgrass radial gradient with a darker rim. No
        // grain lines, no lane stripe. Just a clean field.
        ctx.fill(
            Path(bgRect),
            with: .radialGradient(
                Gradient(colors: [
                    DesignTokens.bentgrass.opacity(0.30),
                    DesignTokens.fairwayShadow.opacity(0.22),
                    DesignTokens.pine.opacity(0.32),
                ]),
                center: CGPoint(x: size.width / 2, y: size.height * 0.55),
                startRadius: 0,
                endRadius: max(size.width, size.height) * 0.72
            )
        )

        // 2. Centerline — thin solid white at low opacity. Subtle, doesn't
        // shout "putt down here" the way a dashed lane did.
        var line = Path()
        line.move(to: CGPoint(x: geom.cup.x, y: geom.cup.y + 4))
        line.addLine(to: CGPoint(x: geom.tee.x, y: geom.tee.y))
        ctx.stroke(
            line,
            with: .color(.white.opacity(0.10)),
            lineWidth: 1
        )

        // 3. Distance ticks — small marks on the right of the line, numbers
        // only (no "ft" suffix; redundant once the user has the context).
        let tickStep: Double = practiceDistanceFeet >= 20
            ? 5
            : (practiceDistanceFeet >= 10 ? 3 : 1)
        var d = tickStep
        while d <= practiceDistanceFeet - 0.1 {
            let yPos = geom.cup.y + CGFloat(d) * geom.scale
            var tick = Path()
            tick.move(to: CGPoint(x: geom.cup.x + 4, y: yPos))
            tick.addLine(to: CGPoint(x: geom.cup.x + 12, y: yPos))
            ctx.stroke(tick, with: .color(.white.opacity(0.30)), lineWidth: 0.8)

            ctx.draw(
                Text("\(Int(d))")
                    .font(DispersionType.mono(9, weight: .regular))
                    .foregroundStyle(.white.opacity(0.45)),
                at: CGPoint(x: geom.cup.x + 18, y: yPos),
                anchor: .leading
            )
            d += tickStep
        }

        // 4. Cup at the top — concentric circles for depth (rim + hole),
        // no flag pin. Top-down views read better without perspective props.
        let cupR: CGFloat = 8
        let rimR = cupR + 3
        ctx.fill(
            Path(ellipseIn: CGRect(x: geom.cup.x - rimR, y: geom.cup.y - rimR, width: rimR * 2, height: rimR * 2)),
            with: .color(.white.opacity(0.10))
        )
        let cupRect = CGRect(x: geom.cup.x - cupR, y: geom.cup.y - cupR, width: cupR * 2, height: cupR * 2)
        ctx.fill(Path(ellipseIn: cupRect), with: .color(.black.opacity(0.78)))
        ctx.stroke(Path(ellipseIn: cupRect), with: .color(.white.opacity(0.55)), lineWidth: 1)

        // 5. Tee marker at the bottom — minimal inline tick, no caption.
        let teeR: CGFloat = 4
        ctx.fill(
            Path(ellipseIn: CGRect(x: geom.tee.x - teeR, y: geom.tee.y - teeR, width: teeR * 2, height: teeR * 2)),
            with: .color(.white.opacity(0.45))
        )
        ctx.stroke(
            Path(ellipseIn: CGRect(x: geom.tee.x - 7, y: geom.tee.y - 7, width: 14, height: 14)),
            with: .color(.white.opacity(0.18)),
            lineWidth: 0.8
        )

        // 6. Landing point — last logged putt or live drag preview. During a
        // drag, render a faint accent line from cup to cursor so the residual
        // distance reads visually alongside the badge readout.
        if let landing = liveLanding {
            let p = CGPoint(
                x: geom.cup.x + CGFloat(landing.x) * geom.scale,
                y: geom.cup.y + CGFloat(-landing.y) * geom.scale
            )
            // (landing.y > 0 = past the cup → moves UP the screen
            //  landing.y < 0 = short → moves DOWN. -landing.y handles both.)

            if isDragging {
                var lag = Path()
                lag.move(to: geom.cup)
                lag.addLine(to: p)
                ctx.stroke(
                    lag,
                    with: .color(palette.primary.opacity(0.55)),
                    lineWidth: 1
                )
            }

            let haloR: CGFloat = isDragging ? 14 : 11
            let halo = Path(ellipseIn: CGRect(x: p.x - haloR, y: p.y - haloR, width: haloR * 2, height: haloR * 2))
            ctx.fill(halo, with: .color(palette.primary.opacity(isDragging ? 0.32 : 0.22)))
            let dotR: CGFloat = isDragging ? 6 : 5
            let dot = Path(ellipseIn: CGRect(x: p.x - dotR, y: p.y - dotR, width: dotR * 2, height: dotR * 2))
            ctx.fill(dot, with: .color(palette.primary))
            ctx.stroke(dot, with: .color(.white.opacity(0.7)), lineWidth: 1)
        }

        // 7. Empty hint — sentence case, low contrast, sized for ambience.
        if liveLanding == nil {
            ctx.draw(
                Text("Tap or drag where it stopped")
                    .font(DispersionType.mono(10, weight: .regular))
                    .foregroundStyle(.white.opacity(0.35)),
                at: CGPoint(x: size.width / 2, y: size.height - 24),
                anchor: .center
            )
        }
    }
}
