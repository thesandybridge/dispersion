type Point = { date: Date; value: number };

type Props = {
    points: Point[];
    height?: number;
    accent?: string;
    fill?: string;
    label?: string;
    suffix?: string;
    referenceValue?: number;
    referenceLabel?: string;
};

export function TrendChart({
    points,
    height = 160,
    accent = "#2c8a5e",
    fill = "#62b375",
    label,
    suffix = "y",
    referenceValue,
    referenceLabel,
}: Props) {
    if (points.length < 2) return null;

    const padTop = label ? 18 : 8;
    const padBottom = 22;
    const padLeft = 36;
    const padRight = 14;
    const width = 600;

    const t0 = points[0]!.date.getTime();
    const tN = points[points.length - 1]!.date.getTime();
    const tSpan = Math.max(tN - t0, 1);

    const values = points.map((p) => p.value);
    const refList =
        referenceValue != null ? [...values, referenceValue] : values;
    const min = Math.min(...refList);
    const max = Math.max(...refList);
    const ySpan = Math.max(max - min, 0.5);
    const yMin = min - ySpan * 0.15;
    const yMax = max + ySpan * 0.15;
    const yRange = yMax - yMin;

    const innerW = width - padLeft - padRight;
    const innerH = height - padTop - padBottom;

    const sx = (t: number) =>
        padLeft + ((t - t0) / tSpan) * innerW;
    const sy = (v: number) =>
        padTop + (1 - (v - yMin) / yRange) * innerH;

    const path = points
        .map((p, i) => {
            const x = sx(p.date.getTime());
            const y = sy(p.value);
            return `${i === 0 ? "M" : "L"}${x.toFixed(1)},${y.toFixed(1)}`;
        })
        .join(" ");

    const areaPath =
        path +
        ` L${sx(tN).toFixed(1)},${(padTop + innerH).toFixed(1)}` +
        ` L${padLeft.toFixed(1)},${(padTop + innerH).toFixed(1)} Z`;

    const yTicks = [yMin, (yMin + yMax) / 2, yMax];
    const refY = referenceValue != null ? sy(referenceValue) : null;

    return (
        <svg
            viewBox={`0 0 ${width} ${height}`}
            preserveAspectRatio="none"
            width="100%"
            height={height}
            style={{ display: "block" }}
        >
            {label && (
                <text
                    x={padLeft}
                    y={11}
                    fill="rgba(26,36,25,0.55)"
                    fontFamily="ui-monospace, monospace"
                    fontSize="9.5"
                    letterSpacing="0.1em"
                >
                    {label.toUpperCase()}
                </text>
            )}

            <g
                stroke="rgba(26,36,25,0.08)"
                strokeWidth="0.5"
                strokeDasharray="2 4"
            >
                {yTicks.map((v) => (
                    <line
                        key={v}
                        x1={padLeft}
                        y1={sy(v)}
                        x2={width - padRight}
                        y2={sy(v)}
                    />
                ))}
            </g>

            <g
                fill="rgba(26,36,25,0.5)"
                fontFamily="ui-monospace, monospace"
                fontSize="9.5"
            >
                {yTicks.map((v) => (
                    <text
                        key={v}
                        x={padLeft - 4}
                        y={sy(v) + 3}
                        textAnchor="end"
                    >
                        {v.toFixed(1)}
                    </text>
                ))}
            </g>

            {refY != null && (
                <>
                    <line
                        x1={padLeft}
                        y1={refY}
                        x2={width - padRight}
                        y2={refY}
                        stroke="rgba(232,93,77,0.6)"
                        strokeWidth="0.8"
                        strokeDasharray="3 3"
                    />
                    {referenceLabel && (
                        <text
                            x={width - padRight}
                            y={refY - 4}
                            textAnchor="end"
                            fill="#e85d4d"
                            fontFamily="ui-monospace, monospace"
                            fontSize="9"
                        >
                            {referenceLabel}
                        </text>
                    )}
                </>
            )}

            <path d={areaPath} fill={fill} fillOpacity="0.14" />
            <path
                d={path}
                stroke={accent}
                strokeWidth="1.6"
                fill="none"
                strokeLinecap="round"
                strokeLinejoin="round"
            />

            {points.map((p, i) => (
                <circle
                    key={i}
                    cx={sx(p.date.getTime())}
                    cy={sy(p.value)}
                    r="2.5"
                    fill={accent}
                />
            ))}

            <g
                fill="rgba(26,36,25,0.5)"
                fontFamily="ui-monospace, monospace"
                fontSize="9.5"
            >
                <text
                    x={padLeft}
                    y={height - 6}
                    textAnchor="start"
                >
                    {formatShortDate(points[0]!.date)}
                </text>
                <text
                    x={width - padRight}
                    y={height - 6}
                    textAnchor="end"
                >
                    {formatShortDate(points[points.length - 1]!.date)}
                </text>
            </g>

            <text
                x={width - padRight}
                y={padTop + 11}
                textAnchor="end"
                fill={accent}
                fontFamily="ui-monospace, monospace"
                fontSize="10.5"
                fontWeight="500"
            >
                {points[points.length - 1]!.value.toFixed(1)}
                {suffix}
            </text>
        </svg>
    );
}

function formatShortDate(d: Date): string {
    return d.toLocaleDateString([], {
        month: "short",
        day: "numeric",
    });
}
