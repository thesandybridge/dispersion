type Props = {
    width?: number;
    height?: number;
    carry?: number;
    carrySd?: number;
    lateralSd?: number;
    distanceToTarget?: number;
    zoneWidth?: number;
    zoneDepth?: number;
    showZone?: boolean;
    palette?: ReadonlyArray<string>;
    contours?: number;
    facets?: number;
    showGrid?: boolean;
    showLabels?: boolean;
    accent?: string;
    bg?: string;
    gridColor?: string;
    textColor?: string;
    style?: React.CSSProperties;
    landingDot?: boolean;
    targetDot?: boolean;
    tailFactor?: number;
    className?: string;
    cursorReadout?: boolean;
    fit?: boolean;
};

const DEFAULT_PALETTE = [
    "#0b3d2e",
    "#16624a",
    "#2c8a5e",
    "#62b375",
    "#a9d18e",
    "#e8e0a8",
];

export function DispersionViz({
    width = 360,
    height = 480,
    carry = 165,
    carrySd = 8,
    lateralSd = 6,
    distanceToTarget = 165,
    zoneWidth = 28,
    zoneDepth = 30,
    showZone = false,
    palette = DEFAULT_PALETTE,
    contours = 6,
    facets = 24,
    showGrid = true,
    showLabels = true,
    accent = "#f6f1e1",
    bg = "#0e1f17",
    gridColor = "rgba(246,241,225,0.05)",
    textColor = "rgba(246,241,225,0.6)",
    style,
    landingDot = true,
    targetDot = true,
    tailFactor = 1.4,
    className,
    fit = false,
}: Props) {
    const longSpan = Math.max(
        carrySd * 3.0 * tailFactor,
        Math.abs(distanceToTarget - carry) + carrySd * 2,
    );
    const latSpan = Math.max(lateralSd * 3.0, lateralSd * 2.4);

    const longMin = carry - longSpan;
    const longMax = carry + longSpan;
    const latMin = -latSpan;
    const latMax = latSpan;

    const worldW = latMax - latMin;
    const worldH = longMax - longMin;

    const scale = fit
        ? Math.min(width / worldW, height / worldH)
        : Math.max(width / worldW, height / worldH);
    const sx = (lat: number) => width / 2 + lat * scale;
    const sy = (lng: number) => height / 2 - (lng - carry) * scale;

    const ringPath = (k: number): string => {
        const pts: Array<[number, number]> = [];
        for (let i = 0; i < facets; i++) {
            const theta = (i / facets) * Math.PI * 2;
            const dx = Math.cos(theta) * k * lateralSd;
            const dy = Math.sin(theta) * k * carrySd;
            pts.push([sx(dx), sy(carry + dy)]);
        }
        return (
            "M" +
            pts
                .map((p) => p.map((n) => n.toFixed(1)).join(","))
                .join(" L") +
            " Z"
        );
    };

    const rings: Array<{ d: string; fill: string }> = [];
    for (let i = contours; i >= 1; i--) {
        const k = (i / contours) * 2.6;
        const colorIdx = Math.min(palette.length - 1, contours - i);
        rings.push({ d: ringPath(k), fill: palette[colorIdx] ?? palette[0]! });
    }

    const gridLong: number[] = [];
    const longStart = Math.ceil(longMin / 10) * 10;
    for (let y = longStart; y <= longMax; y += 10) gridLong.push(y);
    const gridLat: number[] = [];
    const latStart = Math.ceil(latMin / 5) * 5;
    for (let x = latStart; x <= latMax; x += 5) gridLat.push(x);

    const vignetteId = `dv-vignette-${carry}-${distanceToTarget}-${carrySd}-${lateralSd}`;

    return (
        <svg
            width={width}
            height={height}
            viewBox={`0 0 ${width} ${height}`}
            preserveAspectRatio={
                fit ? "xMidYMid meet" : "xMidYMid slice"
            }
            className={className}
            style={{ display: "block", ...style }}
        >
            <defs>
                <radialGradient id={vignetteId} cx="50%" cy="50%" r="55%">
                    <stop offset="60%" stopColor="rgba(0,0,0,0)" />
                    <stop offset="100%" stopColor="rgba(0,0,0,0.55)" />
                </radialGradient>
            </defs>

            <rect x="0" y="0" width={width} height={height} fill={bg} />

            {showGrid && (
                <g stroke={gridColor} strokeWidth="0.5">
                    {gridLong.map((y) => (
                        <line key={`l${y}`} x1="0" y1={sy(y)} x2={width} y2={sy(y)} />
                    ))}
                    {gridLat.map((x) => (
                        <line key={`x${x}`} x1={sx(x)} y1="0" x2={sx(x)} y2={height} />
                    ))}
                </g>
            )}

            <line
                x1={sx(0)}
                y1="0"
                x2={sx(0)}
                y2={height}
                stroke={accent}
                strokeWidth="0.5"
                strokeDasharray="2 5"
                opacity="0.25"
            />

            <g style={{ mixBlendMode: "screen" }}>
                {rings.map((r, i) => (
                    <path key={i} d={r.d} fill={r.fill} opacity={0.85} />
                ))}
            </g>

            <g fill="none" stroke={accent} strokeWidth="0.5" opacity="0.22">
                {rings.map((r, i) => (
                    <path key={`o${i}`} d={r.d} />
                ))}
            </g>

            <rect
                x="0"
                y="0"
                width={width}
                height={height}
                fill={`url(#${vignetteId})`}
                pointerEvents="none"
            />

            {showZone && zoneWidth > 0 && zoneDepth > 0 && (
                <rect
                    x={sx(-zoneWidth / 2)}
                    y={sy(distanceToTarget + zoneDepth / 2)}
                    width={zoneWidth * scale}
                    height={zoneDepth * scale}
                    fill="none"
                    stroke="#e85d4d"
                    strokeWidth="1"
                    strokeDasharray="3 4"
                    opacity="0.55"
                />
            )}

            {landingDot && (
                <circle cx={sx(0)} cy={sy(carry)} r="3" fill={accent} />
            )}

            {targetDot && (
                <g>
                    <line
                        x1={sx(0) - 8}
                        y1={sy(distanceToTarget)}
                        x2={sx(0) + 8}
                        y2={sy(distanceToTarget)}
                        stroke="#e85d4d"
                        strokeWidth="1"
                    />
                    <line
                        x1={sx(0)}
                        y1={sy(distanceToTarget) - 8}
                        x2={sx(0)}
                        y2={sy(distanceToTarget) + 8}
                        stroke="#e85d4d"
                        strokeWidth="1"
                    />
                    <circle
                        cx={sx(0)}
                        cy={sy(distanceToTarget)}
                        r="3"
                        fill="none"
                        stroke="#e85d4d"
                        strokeWidth="1.4"
                    />
                </g>
            )}

            {showLabels && (
                <g
                    fill={textColor}
                    fontFamily="ui-monospace, 'SF Mono', monospace"
                    fontSize="9.5"
                    letterSpacing="0.04em"
                >
                    <text x="10" y={sy(carry) - 6}>
                        EXP {Math.round(carry)}y
                    </text>
                    <text x="10" y={sy(distanceToTarget) - 6} fill="#e85d4d">
                        TGT {Math.round(distanceToTarget)}y
                    </text>
                    <text x={width - 10} y={height - 12} textAnchor="end">
                        σ {carrySd.toFixed(1)} × {lateralSd.toFixed(1)}y
                    </text>
                </g>
            )}
        </svg>
    );
}
