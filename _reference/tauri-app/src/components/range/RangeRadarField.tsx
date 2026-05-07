import { useRef } from "react";
import { motion } from "framer-motion";

export type RangeShot = { lat: number; long: number };

type Props = {
    targetYards: number;
    /** Used to size the visible field — typically the club's stored σ. */
    referenceCarrySd: number;
    referenceLateralSd: number;
    /** Computed from current session shots — drives the live ellipse + bias. */
    carrySd: number;
    lateralSd: number;
    longBias: number;
    latBias: number;
    shots: RangeShot[];
    onTap?: (shot: RangeShot) => void;
    readOnly?: boolean;
    width?: number;
    height?: number;
};

/**
 * Polar-radar tap surface. Replaces the plain orthogonal grid with concentric
 * sigma rings + radial spokes centered on the target. Tap math identical to the
 * old grid — the visual is what changed.
 */
export function RangeRadarField({
    targetYards,
    referenceCarrySd,
    referenceLateralSd,
    carrySd,
    lateralSd,
    longBias,
    latBias,
    shots,
    onTap,
    readOnly = false,
    width = 360,
    height = 420,
}: Props) {
    const ref = useRef<SVGSVGElement>(null);

    const longSpan = Math.max(referenceCarrySd * 3.5, 25);
    const latSpan = Math.max(referenceLateralSd * 3.5, 18);

    const padX = 28;
    const padY = 22;
    const sxScale = (width - padX * 2) / (latSpan * 2);
    const syScale = (height - padY * 2) / (longSpan * 2);
    const sx = (lat: number) => padX + (lat + latSpan) * sxScale;
    const sy = (lng: number) => padY + (longSpan - lng) * syScale;
    const inverseLat = (px: number) => (px - padX) / sxScale - latSpan;
    const inverseLong = (py: number) => longSpan - (py - padY) / syScale;

    function handleClick(e: React.MouseEvent<SVGSVGElement>) {
        if (readOnly || !onTap) return;
        const svg = ref.current;
        if (!svg) return;
        const pt = svg.createSVGPoint();
        pt.x = e.clientX;
        pt.y = e.clientY;
        const ctm = svg.getScreenCTM();
        if (!ctm) return;
        const local = pt.matrixTransform(ctm.inverse());
        const lat = inverseLat(local.x);
        const long = inverseLong(local.y);
        onTap({ lat, long });
    }

    const cx = sx(0);
    const cy = sy(0);
    const polygonReady = shots.length >= 2 && carrySd > 0 && lateralSd > 0;
    const last = shots[shots.length - 1];

    // Concentric sigma ellipses anchored on the target (not on the bias).
    // Reference rings — what the *stored* club says we should see.
    const refRings = [1, 2, 3];

    // Radial spokes every 30°
    const spokes = [0, 30, 60, 90, 120, 150];

    // Distance ticks along the vertical center line — every 10 yards if it fits.
    const tickStep = pickTickStep(longSpan);
    const longTicks: number[] = [];
    for (
        let v = -Math.floor(longSpan / tickStep) * tickStep;
        v <= longSpan;
        v += tickStep
    ) {
        if (v !== 0) longTicks.push(v);
    }

    return (
        <svg
            ref={ref}
            width="100%"
            height="100%"
            viewBox={`0 0 ${width} ${height}`}
            preserveAspectRatio="none"
            onClick={handleClick}
            style={{
                display: "block",
                overflow: "visible",
                cursor: readOnly ? "default" : "crosshair",
                touchAction: "manipulation",
            }}
        >
            <defs>
                <radialGradient id="rfield-bg" cx="50%" cy="50%" r="60%">
                    <stop offset="0%" stopColor="#0e1a13" stopOpacity="1" />
                    <stop offset="100%" stopColor="#070d0a" stopOpacity="1" />
                </radialGradient>
                <radialGradient id="rfield-target" cx="50%" cy="50%" r="50%">
                    <stop offset="0%" stopColor="#e85d4d" stopOpacity="0.22" />
                    <stop offset="60%" stopColor="#e85d4d" stopOpacity="0" />
                </radialGradient>
                <radialGradient id="rfield-bloom" cx="50%" cy="50%" r="50%">
                    <stop offset="0%" stopColor="#a9d18e" stopOpacity="0.55" />
                    <stop offset="60%" stopColor="#a9d18e" stopOpacity="0.0" />
                </radialGradient>
                <pattern
                    id="rfield-noise"
                    x="0"
                    y="0"
                    width="3"
                    height="3"
                    patternUnits="userSpaceOnUse"
                >
                    <rect
                        width="3"
                        height="3"
                        fill="rgba(246,241,225,0.012)"
                    />
                    <circle cx="0.5" cy="0.5" r="0.4" fill="rgba(246,241,225,0.04)" />
                </pattern>
            </defs>

            <rect width={width} height={height} fill="url(#rfield-bg)" />
            <rect width={width} height={height} fill="url(#rfield-noise)" />

            {/* Reference σ rings (ellipses anchored at target) */}
            <g
                fill="none"
                stroke="rgba(246,241,225,0.08)"
                strokeWidth="0.6"
            >
                {refRings.map((k) => (
                    <ellipse
                        key={`ref${k}`}
                        cx={cx}
                        cy={cy}
                        rx={referenceLateralSd * k * sxScale}
                        ry={referenceCarrySd * k * syScale}
                        strokeDasharray={k === 3 ? "1 4" : "2 3"}
                    />
                ))}
            </g>

            {/* Sigma ring labels */}
            <g
                fontFamily="ui-monospace, monospace"
                fontSize="8.5"
                fill="rgba(246,241,225,0.32)"
                pointerEvents="none"
            >
                {refRings.map((k) => (
                    <text
                        key={`refl${k}`}
                        x={cx + referenceLateralSd * k * sxScale + 4}
                        y={cy - 2}
                    >
                        {k}σ
                    </text>
                ))}
            </g>

            {/* Radial spokes — sweeping every 30° */}
            <g stroke="rgba(246,241,225,0.05)" strokeWidth="0.5">
                {spokes.map((deg) => {
                    const rad = (deg * Math.PI) / 180;
                    const r = Math.max(width, height);
                    const x1 = cx + Math.cos(rad) * r;
                    const y1 = cy + Math.sin(rad) * r;
                    const x2 = cx - Math.cos(rad) * r;
                    const y2 = cy - Math.sin(rad) * r;
                    return (
                        <line
                            key={`sp${deg}`}
                            x1={x1}
                            y1={y1}
                            x2={x2}
                            y2={y2}
                        />
                    );
                })}
            </g>

            {/* Bloom behind target */}
            <circle cx={cx} cy={cy} r={Math.min(width, height) * 0.32} fill="url(#rfield-target)" />

            {/* Vertical "fairway centerline" — dashed, slightly stronger */}
            <line
                x1={cx}
                y1={padY - 6}
                x2={cx}
                y2={height - padY + 6}
                stroke="rgba(246,241,225,0.18)"
                strokeWidth="0.6"
                strokeDasharray="4 5"
            />

            {/* Distance tick marks along centerline */}
            <g
                fontFamily="ui-monospace, monospace"
                fontSize="8.5"
                fill="rgba(246,241,225,0.4)"
                pointerEvents="none"
            >
                {longTicks.map((d) => {
                    const yd = Math.round(targetYards + d);
                    if (yd <= 0) return null;
                    return (
                        <g key={`tk${d}`}>
                            <line
                                x1={cx - 5}
                                y1={sy(d)}
                                x2={cx + 5}
                                y2={sy(d)}
                                stroke="rgba(246,241,225,0.22)"
                                strokeWidth="0.7"
                            />
                            <text x={cx + 9} y={sy(d) + 3}>
                                {yd}
                            </text>
                        </g>
                    );
                })}
            </g>

            {/* Target line — horizontal accent */}
            <line
                x1={padX - 6}
                y1={cy}
                x2={width - padX + 6}
                y2={cy}
                stroke="rgba(232,93,77,0.55)"
                strokeWidth="0.9"
            />
            <text
                x={width - padX + 4}
                y={cy + 3}
                textAnchor="start"
                fontFamily="ui-monospace, monospace"
                fontSize="9"
                fill="rgba(232,93,77,0.85)"
                letterSpacing="0.08em"
                pointerEvents="none"
            >
                {targetYards}y
            </text>

            {/* Live dispersion ellipse (centered on bias, not target) */}
            {polygonReady && (
                <g style={{ mixBlendMode: "screen" }}>
                    {[2.5, 1.8, 1.2].map((k, i) => {
                        const opacity = [0.18, 0.28, 0.4][i] ?? 0.3;
                        return (
                            <ellipse
                                key={k}
                                cx={sx(latBias)}
                                cy={sy(longBias)}
                                rx={lateralSd * k * sxScale}
                                ry={carrySd * k * syScale}
                                fill="#62b375"
                                fillOpacity={opacity}
                            />
                        );
                    })}
                </g>
            )}

            {/* Bias arrow from target to mean */}
            {polygonReady && (
                <g>
                    <line
                        x1={cx}
                        y1={cy}
                        x2={sx(latBias)}
                        y2={sy(longBias)}
                        stroke="#a9d18e"
                        strokeOpacity="0.55"
                        strokeWidth="1"
                        strokeDasharray="2 2"
                    />
                    <circle
                        cx={sx(latBias)}
                        cy={sy(longBias)}
                        r="3"
                        fill="#a9d18e"
                    />
                </g>
            )}

            {/* Target reticle */}
            <g pointerEvents="none">
                <circle cx={cx} cy={cy} r="9" fill="none" stroke="#e85d4d" strokeWidth="1.2" />
                <circle cx={cx} cy={cy} r="2" fill="#e85d4d" />
                <line
                    x1={cx - 14}
                    y1={cy}
                    x2={cx - 4}
                    y2={cy}
                    stroke="#e85d4d"
                    strokeWidth="1"
                />
                <line
                    x1={cx + 4}
                    y1={cy}
                    x2={cx + 14}
                    y2={cy}
                    stroke="#e85d4d"
                    strokeWidth="1"
                />
                <line
                    x1={cx}
                    y1={cy - 14}
                    x2={cx}
                    y2={cy - 4}
                    stroke="#e85d4d"
                    strokeWidth="1"
                />
                <line
                    x1={cx}
                    y1={cy + 4}
                    x2={cx}
                    y2={cy + 14}
                    stroke="#e85d4d"
                    strokeWidth="1"
                />
            </g>

            {/* Logged shots — phosphor dots, latest gets a halo */}
            {shots.map((s, i) => {
                const isLast = i === shots.length - 1;
                return (
                    <g key={i}>
                        <circle
                            cx={sx(s.lat)}
                            cy={sy(s.long)}
                            r="3.5"
                            fill="#f6f1e1"
                        />
                        <circle
                            cx={sx(s.lat)}
                            cy={sy(s.long)}
                            r="3.5"
                            fill="none"
                            stroke="#070d0a"
                            strokeWidth="1"
                        />
                        {isLast && (
                            <circle
                                cx={sx(s.lat)}
                                cy={sy(s.long)}
                                r="14"
                                fill="url(#rfield-bloom)"
                            />
                        )}
                    </g>
                );
            })}

            {/* Last-shot pulse ring */}
            {last && (
                <motion.circle
                    key={`pulse-${shots.length}`}
                    cx={sx(last.lat)}
                    cy={sy(last.long)}
                    r="6"
                    fill="none"
                    stroke="#a9d18e"
                    strokeWidth="1.2"
                    initial={{ opacity: 0.85, scale: 0.6 }}
                    animate={{ opacity: 0, scale: 3.2 }}
                    transition={{ duration: 0.9, ease: "easeOut" }}
                    style={{ transformBox: "fill-box", transformOrigin: "center" }}
                />
            )}

            {/* Empty-state hint */}
            {shots.length === 0 && (
                <g
                    pointerEvents="none"
                    fontFamily="ui-monospace, monospace"
                    fontSize="9"
                    fill="rgba(246,241,225,0.45)"
                    letterSpacing="0.18em"
                >
                    <text x={cx} y={cy + 32} textAnchor="middle">
                        TAP WHERE IT LANDED
                    </text>
                </g>
            )}
        </svg>
    );
}

function pickTickStep(longSpan: number): number {
    if (longSpan > 50) return 20;
    if (longSpan > 30) return 10;
    if (longSpan > 15) return 5;
    return 5;
}
