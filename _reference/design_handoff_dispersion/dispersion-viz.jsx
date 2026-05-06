// DispersionViz — polygonal heat-map of a shot dispersion ellipse.
// The polygon IS the figure. The target gets a subtle pin + crosshair only.
// No dotted box.

function DispersionViz({
    width = 360,
    height = 480,
    carry = 165,
    carrySd = 8,
    lateralSd = 6,
    distanceToTarget = 165,
    zoneWidth = 25,
    zoneDepth = 30,
    zoneOffsetLong = 0,
    zoneOffsetLat = 0,
    palette = ['#0b3d2e', '#16624a', '#2c8a5e', '#62b375', '#a9d18e', '#e8e0a8'],
    contours = 6,
    facets = 24,
    showGrid = true,
    showLabels = true,
    showZone = false,
    accent = '#f6f1e1',
    bg = '#0e1f17',
    gridColor = 'rgba(246,241,225,0.05)',
    textColor = 'rgba(246,241,225,0.6)',
    style = {},
    landingDot = true,
    targetDot = true,
    bleed = true,
    tailFactor = 1.4,
}) {
    // Override globals from Tweaks panel.
    if (typeof window !== 'undefined') {
        if (window.__VIZ_PALETTE) palette = window.__VIZ_PALETTE;
        if (window.__VIZ_FACETS) facets = window.__VIZ_FACETS;
        if (window.__VIZ_CONTOURS) contours = window.__VIZ_CONTOURS;
    }

    // World units: yards. Long = vertical (target up the page).
    // Tighter bounds so the polygon fills the canvas.
    const longSpan = Math.max(carrySd * 3.0 * tailFactor, Math.abs(distanceToTarget - carry) + carrySd * 2);
    const latSpan = Math.max(lateralSd * 3.0, lateralSd * 2.4);

    const longMin = carry - longSpan;
    const longMax = carry + longSpan;
    const latMin = -latSpan;
    const latMax = latSpan;

    const worldW = latMax - latMin;
    const worldH = longMax - longMin;

    // Uniform scale: polygon shape is invariant, canvas just letterboxes.
    // The polygon's aspect ratio comes from carrySd/lateralSd alone.
    const scale = Math.max(width / worldW, height / worldH);
    const sx = (lat) => width / 2 + lat * scale;
    const sy = (lng) => height / 2 - (lng - carry) * scale;

    // Build a faceted ellipse at radius k·σ — the polygon shape that real
    // dispersion makes, visibly elongated long when carrySd > lateralSd.
    const ringPath = (k) => {
        const pts = [];
        for (let i = 0; i < facets; i++) {
            const theta = (i / facets) * Math.PI * 2;
            const dx = Math.cos(theta) * k * lateralSd;
            const dy = Math.sin(theta) * k * carrySd;
            pts.push([sx(dx), sy(carry + dy)]);
        }
        return 'M' + pts.map((p) => p.map((n) => n.toFixed(1)).join(',')).join(' L') + ' Z';
    };

    const rings = [];
    for (let i = contours; i >= 1; i--) {
        const k = (i / contours) * 2.6;
        const colorIdx = Math.min(palette.length - 1, contours - i);
        rings.push({ d: ringPath(k), fill: palette[colorIdx], k });
    }

    const gridLong = [];
    const longStart = Math.ceil(longMin / 10) * 10;
    for (let y = longStart; y <= longMax; y += 10) gridLong.push(y);
    const gridLat = [];
    const latStart = Math.ceil(latMin / 5) * 5;
    for (let x = latStart; x <= latMax; x += 5) gridLat.push(x);

    return (
        <svg width={width} height={height} viewBox={`0 0 ${width} ${height}`} style={{ display: 'block', ...style }}>
            <defs>
                <radialGradient id={`dv-vignette-${carry}-${distanceToTarget}`} cx="50%" cy="50%" r="55%">
                    <stop offset="60%" stopColor="rgba(0,0,0,0)" />
                    <stop offset="100%" stopColor="rgba(0,0,0,0.55)" />
                </radialGradient>
            </defs>

            {/* ground */}
            <rect x="0" y="0" width={width} height={height} fill={bg} />

            {/* yardage grid */}
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

            {/* center axis (target line) */}
            <line x1={sx(0)} y1="0" x2={sx(0)} y2={height} stroke={accent} strokeWidth="0.5" strokeDasharray="2 5" opacity="0.25" />

            {/* heat-map rings — additive blending makes overlaps glow */}
            <g style={{ mixBlendMode: 'screen' }}>
                {rings.map((r, i) => (
                    <path key={i} d={r.d} fill={r.fill} opacity={0.85} />
                ))}
            </g>

            {/* faceted polygon outlines — emphasize the polygon-ness */}
            <g fill="none" stroke={accent} strokeWidth="0.5" opacity="0.22">
                {rings.map((r, i) => (
                    <path key={`o${i}`} d={r.d} />
                ))}
            </g>

            {/* edge vignette */}
            <rect x="0" y="0" width={width} height={height} fill={`url(#dv-vignette-${carry}-${distanceToTarget})`} pointerEvents="none" />

            {/* expected landing — small "X marks expected" */}
            {landingDot && (
                <g>
                    <circle cx={sx(0)} cy={sy(carry)} r="3" fill={accent} />
                </g>
            )}

            {/* target — pin + crosshair */}
            {targetDot && (
                <g>
                    <line x1={sx(zoneOffsetLat) - 8} y1={sy(distanceToTarget + zoneOffsetLong)} x2={sx(zoneOffsetLat) + 8} y2={sy(distanceToTarget + zoneOffsetLong)} stroke="#e85d4d" strokeWidth="1" />
                    <line x1={sx(zoneOffsetLat)} y1={sy(distanceToTarget + zoneOffsetLong) - 8} x2={sx(zoneOffsetLat)} y2={sy(distanceToTarget + zoneOffsetLong) + 8} stroke="#e85d4d" strokeWidth="1" />
                    <circle cx={sx(zoneOffsetLat)} cy={sy(distanceToTarget + zoneOffsetLong)} r="3" fill="none" stroke="#e85d4d" strokeWidth="1.4" />
                </g>
            )}

            {/* axis labels */}
            {showLabels && (
                <g fill={textColor} fontFamily="ui-monospace, 'SF Mono', monospace" fontSize="9.5" letterSpacing="0.04em">
                    <text x="10" y={sy(carry) - 6}>EXP {Math.round(carry)}y</text>
                    <text x="10" y={sy(distanceToTarget) - 6} fill="#e85d4d">TGT {Math.round(distanceToTarget)}y</text>
                    <text x={width - 10} y={height - 12} textAnchor="end">σ {carrySd.toFixed(1)} × {lateralSd.toFixed(1)}y</text>
                </g>
            )}
        </svg>
    );
}

window.DispersionViz = DispersionViz;
