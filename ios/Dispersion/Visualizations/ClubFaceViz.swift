// Port of app/src/components/primitives/ClubFaceViz.tsx. Renders a club face
// with groove lines, sweet spot glow, and strike mark dots.

import SwiftUI

public struct FacePoint: Identifiable, Hashable {
    public var id: String
    public var x: Double  // -1...1 heel to toe
    public var y: Double  // -1...1 sole to crown
}

public struct ClubFaceViz: View {
    public var strikes: [FacePoint]
    public var selectedId: String?
    public var onTap: ((FacePoint) -> Void)?
    public var onSelect: ((String) -> Void)?

    private let padX: CGFloat = 28
    private let padY: CGFloat = 32

    public init(
        strikes: [FacePoint],
        selectedId: String? = nil,
        onTap: ((FacePoint) -> Void)? = nil,
        onSelect: ((String) -> Void)? = nil
    ) {
        self.strikes = strikes
        self.selectedId = selectedId
        self.onTap = onTap
        self.onSelect = onSelect
    }

    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width - padX * 2
            let h = geo.size.height - padY * 2

            Canvas { ctx, size in
                drawFace(ctx: ctx, size: size, innerW: w, innerH: h)
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(
                        colors: [hex("#202a23"), hex("#0e1a13")],
                        startPoint: .top, endPoint: .bottom
                    ))
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contentShape(Rectangle())
            .onTapGesture { location in
                let nx = ((location.x - padX) / w) * 2 - 1
                let ny = 1 - ((location.y - padY) / h) * 2
                let cx = min(max(nx, -1), 1)
                let cy = min(max(ny, -1), 1)

                // Check if tap is near an existing strike
                let hitRadius = 0.15
                if let hit = strikes.first(where: { s in
                    let dx = s.x - cx
                    let dy = s.y - cy
                    return sqrt(dx * dx + dy * dy) < hitRadius
                }) {
                    onSelect?(hit.id)
                    return
                }

                onTap?(FacePoint(id: UUID().uuidString, x: cx, y: cy))
            }
        }
        .aspectRatio(1.45, contentMode: .fit)
    }

    private func drawFace(ctx: GraphicsContext, size: CGSize, innerW: CGFloat, innerH: CGFloat) {
        let sx = { (x: Double) -> CGFloat in padX + CGFloat((x + 1) / 2) * innerW }
        let sy = { (y: Double) -> CGFloat in padY + CGFloat(1 - (y + 1) / 2) * innerH }

        // Sweet spot glow
        let centerX = sx(0)
        let centerY = sy(0)
        let glowRx = innerW * 0.18
        let glowRy = innerH * 0.22
        let glowRect = CGRect(x: centerX - glowRx, y: centerY - glowRy, width: glowRx * 2, height: glowRy * 2)
        ctx.fill(
            Path(ellipseIn: glowRect),
            with: .color(DesignTokens.primary.opacity(0.08))
        )

        // Groove lines
        let grooveYs: [Double] = [-0.7, -0.4, -0.1, 0.2, 0.5, 0.8]
        for gy in grooveYs {
            let yy = sy(gy)
            var line = Path()
            line.move(to: CGPoint(x: padX + 8, y: yy))
            line.addLine(to: CGPoint(x: padX + innerW - 8, y: yy))
            ctx.stroke(line, with: .color(Color.white.opacity(0.06)), lineWidth: 0.5)
        }

        // Crosshair
        let dashStyle = StrokeStyle(lineWidth: 0.5, dash: [4, 4])
        var vLine = Path()
        vLine.move(to: CGPoint(x: centerX, y: padY))
        vLine.addLine(to: CGPoint(x: centerX, y: padY + innerH))
        ctx.stroke(vLine, with: .color(Color.white.opacity(0.08)), style: dashStyle)

        var hLine = Path()
        hLine.move(to: CGPoint(x: padX, y: centerY))
        hLine.addLine(to: CGPoint(x: padX + innerW, y: centerY))
        ctx.stroke(hLine, with: .color(Color.white.opacity(0.08)), style: dashStyle)

        // Labels
        let labelColor = Color.white.opacity(0.25)
        let labelFont = Font.system(size: 8, design: .monospaced).weight(.medium)
        ctx.draw(Text("CROWN").font(labelFont).foregroundStyle(labelColor),
                 at: CGPoint(x: centerX, y: padY - 10), anchor: .center)
        ctx.draw(Text("SOLE").font(labelFont).foregroundStyle(labelColor),
                 at: CGPoint(x: centerX, y: padY + innerH + 12), anchor: .center)
        ctx.draw(Text("HEEL").font(labelFont).foregroundStyle(labelColor),
                 at: CGPoint(x: padX - 6, y: centerY), anchor: .trailing)
        ctx.draw(Text("TOE").font(labelFont).foregroundStyle(labelColor),
                 at: CGPoint(x: padX + innerW + 6, y: centerY), anchor: .leading)

        // Strike dots
        for strike in strikes {
            let px = sx(strike.x)
            let py = sy(strike.y)
            let selected = strike.id == selectedId
            let r: CGFloat = selected ? 7 : 5
            let dot = Path(ellipseIn: CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2))
            ctx.fill(dot, with: .color(selected ? DesignTokens.primary : DesignTokens.cream))
            ctx.stroke(dot, with: .color(DesignTokens.backgroundDeep), lineWidth: 1.2)
        }
    }
}
