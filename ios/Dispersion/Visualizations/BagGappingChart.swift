// Port of app/src/components/primitives/BagGappingChart.tsx. Horizontal bars
// per club showing carry ± 2σ; flagged gaps highlighted in red.

import SwiftUI

public struct BagGappingChart: View {
    public var clubs: [Club]
    public var unit: DistanceUnit
    public var height: CGFloat?

    public init(clubs: [Club], unit: DistanceUnit, height: CGFloat? = nil) {
        self.clubs = clubs
        self.unit = unit
        self.height = height
    }

    public var body: some View {
        Canvas { ctx, size in
            drawScene(ctx: ctx, size: size)
        }
        .frame(height: computedHeight)
    }

    private var computedHeight: CGFloat {
        if let h = height { return h }
        let rows = max(clubs.count, 1)
        return CGFloat(rows) * (rowHeight + rowGap) + padTop + padBottom
    }

    // MARK: layout constants

    private let rowHeight: CGFloat = 24
    private let rowGap: CGFloat = 6
    private let padLeft: CGFloat = 72
    private let padRight: CGFloat = 18
    private let padTop: CGFloat = 24
    private let padBottom: CGFloat = 30

    // MARK: drawing

    private func drawScene(ctx: GraphicsContext, size: CGSize) {
        guard !clubs.isEmpty else { return }
        let convert: (Double) -> Double = { Units.from(yards: $0, in: unit) }
        let sorted = clubs.sorted { $0.carryYards > $1.carryYards }

        let lows = sorted.map { convert($0.carryYards - $0.carrySd * 2.5) }
        let highs = sorted.map { convert($0.carryYards + $0.carrySd * 2.5) }
        let minBound = max(0, (lows.min() ?? 0) - 5)
        let maxBound = (highs.max() ?? 0) + 5
        let span = max(maxBound - minBound, 50)

        let innerW = size.width - padLeft - padRight
        func sx(_ val: Double) -> CGFloat {
            padLeft + CGFloat((val - minBound) / span) * innerW
        }

        // Tick rule.
        let tickStep = chooseTick(span)
        var ticks: [Double] = []
        var v = (minBound / tickStep).rounded(.up) * tickStep
        while v <= maxBound {
            ticks.append(v); v += tickStep
        }
        for t in ticks {
            let line = Path { p in
                p.move(to: CGPoint(x: sx(t), y: padTop - 6))
                p.addLine(to: CGPoint(x: sx(t), y: size.height - padBottom + 4))
            }
            ctx.stroke(line, with: .color(DesignTokens.foreground.opacity(0.06)),
                       style: StrokeStyle(lineWidth: 0.5, dash: [2, 4]))
            ctx.draw(
                Text("\(Int(t))\(unit.label)")
                    .font(DispersionType.mono(9, weight: .regular))
                    .foregroundStyle(DesignTokens.foreground.opacity(0.45)),
                at: CGPoint(x: sx(t), y: size.height - padBottom + 16)
            )
        }

        // Per-club row.
        for (i, club) in sorted.enumerated() {
            let carry = convert(club.carryYards)
            let sd = convert(club.carrySd)
            let x1 = sx(carry - sd * 2)
            let x2 = sx(carry + sd * 2)
            let xc = sx(carry)
            let y = padTop + CGFloat(i) * (rowHeight + rowGap)

            // Label.
            ctx.draw(
                Text(truncateName(club.name))
                    .font(DispersionType.ui(11, weight: .medium))
                    .foregroundStyle(DesignTokens.foreground.opacity(0.7)),
                at: CGPoint(x: padLeft - 8, y: y + rowHeight / 2 + 1),
                anchor: .trailing
            )

            // Bar.
            let bar = RoundedRectangle(cornerRadius: 4).path(in: CGRect(
                x: x1, y: y, width: max(2, x2 - x1), height: rowHeight
            ))
            ctx.fill(bar, with: .color(DesignTokens.bentgrass.opacity(0.3)))
            ctx.stroke(bar, with: .color(DesignTokens.fairwayShadow.opacity(0.6)), lineWidth: 0.8)

            // Center mark + carry label.
            let cm = Path { p in
                p.move(to: CGPoint(x: xc, y: y + 2))
                p.addLine(to: CGPoint(x: xc, y: y + rowHeight - 2))
            }
            ctx.stroke(cm, with: .color(DesignTokens.foreground), lineWidth: 1)
            ctx.draw(
                Text("\(Int(carry))")
                    .font(DispersionType.mono(9, weight: .medium))
                    .foregroundStyle(DesignTokens.foreground),
                at: CGPoint(x: xc, y: y + rowHeight / 2 + 1)
            )
        }

        // Gaps — stagger labels so close gaps don't overlap.
        let gaps = findGaps(sorted, convert: convert)
        for (gi, g) in gaps.enumerated() {
            let gx1 = sx(g.from)
            let gx2 = sx(g.to)
            let gapWidth = gx2 - gx1

            // Only draw the highlight if the gap is visible
            guard gapWidth > 4 else { continue }

            let r = CGRect(
                x: gx1,
                y: padTop - 6,
                width: gapWidth,
                height: CGFloat(sorted.count) * (rowHeight + rowGap) + 10
            )
            let path = Path(roundedRect: r, cornerRadius: 4)
            ctx.fill(path, with: .color(DesignTokens.flag.opacity(0.05)))
            ctx.stroke(path, with: .color(DesignTokens.flag.opacity(0.35)),
                       style: StrokeStyle(lineWidth: 0.7, dash: [3, 3]))

            // Label — skip if gap too narrow to fit text, stagger odd/even
            if gapWidth > 30 {
                let staggerY: CGFloat = gi % 2 == 0 ? padTop - 10 : padTop - 20
                ctx.draw(
                    Text("\(Int(g.to - g.from))\(unit.label)")
                        .font(DispersionType.mono(8, weight: .medium))
                        .foregroundStyle(DesignTokens.flag),
                    at: CGPoint(x: (gx1 + gx2) / 2, y: staggerY)
                )
            }
        }
    }

    // MARK: helpers

    private struct Gap { var from: Double; var to: Double }

    private func chooseTick(_ span: Double) -> Double {
        if span > 400 { return 50 }
        if span > 200 { return 25 }
        if span > 100 { return 20 }
        if span > 60 { return 10 }
        return 5
    }

    private func truncateName(_ name: String) -> String {
        name.count > 12 ? String(name.prefix(11)) + "…" : name
    }

    private func findGaps(_ clubs: [Club], convert: (Double) -> Double) -> [Gap] {
        guard clubs.count >= 2 else { return [] }
        let ranges = clubs
            .map { c in
                (min: convert(c.carryYards - c.carrySd * 2),
                 max: convert(c.carryYards + c.carrySd * 2))
            }
            .sorted { $0.min < $1.min }
        var gaps: [Gap] = []
        var coverEnd = ranges[0].max
        for i in 1..<ranges.count {
            let r = ranges[i]
            if r.min > coverEnd + 4 {
                gaps.append(Gap(from: coverEnd, to: r.min))
            }
            if r.max > coverEnd { coverEnd = r.max }
        }
        return gaps
    }
}
