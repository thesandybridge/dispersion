// Port of app/src/components/primitives/TrendChart.tsx. Line chart showing
// sigma values over time with optional reference line.

import SwiftUI

public struct TrendPoint: Hashable {
    public var date: Date
    public var value: Double
}

public struct TrendChart: View {
    public var points: [TrendPoint]
    public var accent: Color
    public var fill: Color
    public var label: String?
    public var suffix: String
    public var referenceValue: Double?
    public var referenceLabel: String?

    public init(
        points: [TrendPoint],
        accent: Color = DesignTokens.fairwayShadow,
        fill: Color = DesignTokens.bentgrass,
        label: String? = nil,
        suffix: String = "y",
        referenceValue: Double? = nil,
        referenceLabel: String? = nil
    ) {
        self.points = points
        self.accent = accent
        self.fill = fill
        self.label = label
        self.suffix = suffix
        self.referenceValue = referenceValue
        self.referenceLabel = referenceLabel
    }

    public var body: some View {
        if points.count < 2 {
            EmptyView()
        } else {
            Canvas { ctx, size in
                drawChart(ctx: ctx, size: size)
            }
            .frame(height: 140)
        }
    }

    private func drawChart(ctx: GraphicsContext, size: CGSize) {
        let padTop: CGFloat = label != nil ? 18 : 8
        let padBottom: CGFloat = 22
        let padLeft: CGFloat = 36
        let padRight: CGFloat = 14
        let chartW = size.width - padLeft - padRight
        let chartH = size.height - padTop - padBottom

        guard let first = points.first, let last = points.last else { return }

        let t0 = first.date.timeIntervalSince1970
        let tN = last.date.timeIntervalSince1970
        let tSpan = max(tN - t0, 1)

        var allVals = points.map(\.value)
        if let ref = referenceValue { allVals.append(ref) }
        let vMin = (allVals.min() ?? 0)
        let vMax = (allVals.max() ?? 1)
        let vSpan = max(vMax - vMin, 0.5)
        let yMin = vMin - vSpan * 0.15
        let yMax = vMax + vSpan * 0.15
        let yRange = yMax - yMin

        let sx = { (t: Double) -> CGFloat in
            padLeft + CGFloat((t - t0) / tSpan) * chartW
        }
        let sy = { (v: Double) -> CGFloat in
            padTop + CGFloat(1 - (v - yMin) / yRange) * chartH
        }

        // Y-axis gridlines
        let ticks = [yMin + yRange * 0.1, yMin + yRange * 0.5, yMin + yRange * 0.9]
        let dashStyle = StrokeStyle(lineWidth: 0.5, dash: [3, 3])
        let gridColor = Color.white.opacity(0.08)
        let labelFont = Font.system(size: 9, design: .monospaced)
        for tick in ticks {
            let yy = sy(tick)
            var line = Path()
            line.move(to: CGPoint(x: padLeft, y: yy))
            line.addLine(to: CGPoint(x: size.width - padRight, y: yy))
            ctx.stroke(line, with: .color(gridColor), style: dashStyle)
            ctx.draw(
                Text(String(format: "%.1f", tick)).font(labelFont).foregroundStyle(Color.white.opacity(0.35)),
                at: CGPoint(x: padLeft - 4, y: yy), anchor: .trailing
            )
        }

        // Reference line
        if let ref = referenceValue {
            let ry = sy(ref)
            var refLine = Path()
            refLine.move(to: CGPoint(x: padLeft, y: ry))
            refLine.addLine(to: CGPoint(x: size.width - padRight, y: ry))
            ctx.stroke(refLine, with: .color(DesignTokens.flag.opacity(0.5)),
                       style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            if let rLabel = referenceLabel {
                ctx.draw(
                    Text(rLabel).font(Font.system(size: 8, design: .monospaced)).foregroundStyle(DesignTokens.flag.opacity(0.6)),
                    at: CGPoint(x: size.width - padRight, y: ry - 8), anchor: .trailing
                )
            }
        }

        // Area fill
        var areaPath = Path()
        for (i, p) in points.enumerated() {
            let x = sx(p.date.timeIntervalSince1970)
            let y = sy(p.value)
            if i == 0 { areaPath.move(to: CGPoint(x: x, y: y)) }
            else { areaPath.addLine(to: CGPoint(x: x, y: y)) }
        }
        areaPath.addLine(to: CGPoint(x: sx(last.date.timeIntervalSince1970), y: padTop + chartH))
        areaPath.addLine(to: CGPoint(x: sx(first.date.timeIntervalSince1970), y: padTop + chartH))
        areaPath.closeSubpath()
        ctx.fill(areaPath, with: .color(fill.opacity(0.14)))

        // Line
        var linePath = Path()
        for (i, p) in points.enumerated() {
            let x = sx(p.date.timeIntervalSince1970)
            let y = sy(p.value)
            if i == 0 { linePath.move(to: CGPoint(x: x, y: y)) }
            else { linePath.addLine(to: CGPoint(x: x, y: y)) }
        }
        ctx.stroke(linePath, with: .color(accent),
                   style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))

        // Dots
        for p in points {
            let x = sx(p.date.timeIntervalSince1970)
            let y = sy(p.value)
            let dot = Path(ellipseIn: CGRect(x: x - 2.5, y: y - 2.5, width: 5, height: 5))
            ctx.fill(dot, with: .color(accent))
        }

        // Date labels
        let dateFont = Font.system(size: 8, design: .monospaced)
        let dateColor = Color.white.opacity(0.35)
        ctx.draw(
            Text(formatShort(first.date)).font(dateFont).foregroundStyle(dateColor),
            at: CGPoint(x: padLeft, y: size.height - 4), anchor: .leading
        )
        ctx.draw(
            Text(formatShort(last.date)).font(dateFont).foregroundStyle(dateColor),
            at: CGPoint(x: size.width - padRight, y: size.height - 4), anchor: .trailing
        )

        // Current value
        ctx.draw(
            Text("\(String(format: "%.1f", last.value))\(suffix)")
                .font(Font.system(size: 11, design: .monospaced).weight(.medium))
                .foregroundStyle(accent),
            at: CGPoint(x: size.width - padRight, y: 6), anchor: .trailing
        )

        // Label
        if let label {
            ctx.draw(
                Text(label).font(Font.system(size: 9, design: .monospaced).weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.45)),
                at: CGPoint(x: padLeft, y: 6), anchor: .leading
            )
        }
    }

    private func formatShort(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }
}
