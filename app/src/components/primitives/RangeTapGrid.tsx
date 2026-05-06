import { useRef } from "react";

export type RangeShot = { lat: number; long: number };

type Props = {
    targetYards: number;
    referenceCarrySd: number;
    referenceLateralSd: number;
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

export function RangeTapGrid({
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
    const padX = 44;
    const padY = 28;
    const ref = useRef<SVGSVGElement>(null);

    const longSpan = Math.max(referenceCarrySd * 3.5, 25);
    const latSpan = Math.max(referenceLateralSd * 3.5, 18);

    const sxScale = (width - padX * 2) / (latSpan * 2);
    const syScale = (height - padY * 2) / (longSpan * 2);
    const sx = (lat: number) => padX + (lat + latSpan) * sxScale;
    const sy = (lng: number) => padY + (longSpan - lng) * syScale;
    const inverseLat = (px: number) => (px - padX) / sxScale - latSpan;
    const inverseLong = (py: number) => longSpan - (py - padY) / syScale;

    const worldLeft = padX;
    const worldRight = width - padX;
    const worldTop = padY;
    const worldBottom = height - padY;

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

    const colors = ["#0b3d2e", "#2c8a5e", "#62b375", "#a9d18e"];
    const last = shots[shots.length - 1];

    const longLines = computeLongTicks(longSpan);
    const latLines = computeLatTicks(latSpan);

    const polygonReady = shots.length >= 2 && carrySd > 0 && lateralSd > 0;

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
            }}
        >
            <defs>
                <radialGradient id="rg-target" cx="50%" cy="50%" r="50%">
                    <stop offset="0%" stopColor="#e85d4d" stopOpacity="0.18" />
                    <stop offset="60%" stopColor="#e85d4d" stopOpacity="0" />
                </radialGradient>
            </defs>
            <rect x="0" y="0" width={width} height={height} fill="#0e1a13" />

            {/* horizontal range lines (constant yardage from tee) */}
            <g stroke="rgba(246,241,225,0.06)" strokeWidth="0.5">
                {longLines.map((delta) => (
                    <line
                        key={`hl${delta}`}
                        x1={worldLeft - 4}
                        y1={sy(delta)}
                        x2={worldRight + 4}
                        y2={sy(delta)}
                    />
                ))}
                {latLines.map((dx) => (
                    <line
                        key={`vl${dx}`}
                        x1={sx(dx)}
                        y1={worldTop - 4}
                        x2={sx(dx)}
                        y2={worldBottom + 4}
                    />
                ))}
            </g>

            {/* center axes (target line + target latitude) */}
            <line
                x1={sx(0)}
                y1={worldTop}
                x2={sx(0)}
                y2={worldBottom}
                stroke="rgba(246,241,225,0.18)"
                strokeWidth="0.5"
                strokeDasharray="3 4"
            />
            <line
                x1={worldLeft}
                y1={sy(0)}
                x2={worldRight}
                y2={sy(0)}
                stroke="rgba(232,93,77,0.45)"
                strokeWidth="0.7"
            />

            {/* dispersion polygon — centered on shot mean, not target */}
            {polygonReady &&
                [2.5, 1.8, 1.2, 0.7].map((k, i) => {
                    const facets = 24;
                    const pts: string[] = [];
                    for (let j = 0; j < facets; j++) {
                        const t = (j / facets) * Math.PI * 2;
                        const x = latBias + Math.cos(t) * k * lateralSd;
                        const y = longBias + Math.sin(t) * k * carrySd;
                        pts.push(`${sx(x)},${sy(y)}`);
                    }
                    return (
                        <polygon
                            key={i}
                            points={pts.join(" ")}
                            fill={colors[i]}
                            fillOpacity="0.6"
                            style={{ mixBlendMode: "screen" }}
                        />
                    );
                })}

            {/* target reticle (always at origin) */}
            <circle cx={sx(0)} cy={sy(0)} r="36" fill="url(#rg-target)" />
            <circle
                cx={sx(0)}
                cy={sy(0)}
                r="5"
                fill="none"
                stroke="#e85d4d"
                strokeWidth="1.4"
            />
            <line
                x1={sx(0) - 12}
                y1={sy(0)}
                x2={sx(0) + 12}
                y2={sy(0)}
                stroke="#e85d4d"
                strokeWidth="1"
            />
            <line
                x1={sx(0)}
                y1={sy(0) - 12}
                x2={sx(0)}
                y2={sy(0) + 12}
                stroke="#e85d4d"
                strokeWidth="1"
            />

            {/* shot mean marker */}
            {polygonReady && (
                <g>
                    <circle
                        cx={sx(latBias)}
                        cy={sy(longBias)}
                        r="2.5"
                        fill="#a9d18e"
                    />
                    <line
                        x1={sx(0)}
                        y1={sy(0)}
                        x2={sx(latBias)}
                        y2={sy(longBias)}
                        stroke="#a9d18e"
                        strokeOpacity="0.4"
                        strokeWidth="0.8"
                        strokeDasharray="2 3"
                    />
                </g>
            )}

            {/* logged shots */}
            {shots.map((s, i) => (
                <g key={i}>
                    <circle cx={sx(s.lat)} cy={sy(s.long)} r="3.5" fill="#f6f1e1" />
                    <circle
                        cx={sx(s.lat)}
                        cy={sy(s.long)}
                        r="3.5"
                        fill="none"
                        stroke="#0a1410"
                        strokeWidth="1"
                    />
                </g>
            ))}

            {last && (
                <circle
                    cx={sx(last.lat)}
                    cy={sy(last.long)}
                    r="9"
                    fill="none"
                    stroke="#a9d18e"
                    strokeWidth="1.2"
                    opacity="0.6"
                />
            )}

            {shots.length === 0 && (
                <g opacity="0.4" pointerEvents="none">
                    <circle
                        cx={sx(2)}
                        cy={sy(-3)}
                        r="10"
                        fill="none"
                        stroke="#f6f1e1"
                        strokeWidth="0.8"
                        strokeDasharray="2 3"
                    />
                </g>
            )}

            {/* yard labels */}
            <g
                fontFamily="ui-monospace, monospace"
                fontSize="9.5"
                pointerEvents="none"
            >
                {longLines.map((delta) => {
                    const yd = Math.round(targetYards + delta);
                    if (yd <= 0) return null;
                    const isTarget = delta === 0;
                    return (
                        <text
                            key={`yt${delta}`}
                            x={worldLeft - 6}
                            y={sy(delta) + 3}
                            textAnchor="end"
                            fill={
                                isTarget
                                    ? "rgba(232,93,77,0.95)"
                                    : "rgba(246,241,225,0.5)"
                            }
                        >
                            {yd}y
                        </text>
                    );
                })}
                {latLines
                    .filter((dx) => dx !== 0)
                    .map((dx) => {
                        const sign = dx > 0 ? "R" : "L";
                        return (
                            <text
                                key={`xt${dx}`}
                                x={sx(dx)}
                                y={worldBottom + 14}
                                textAnchor="middle"
                                fill="rgba(246,241,225,0.4)"
                            >
                                {Math.abs(dx)}
                                {sign}
                            </text>
                        );
                    })}
            </g>
        </svg>
    );
}

function computeLongTicks(longSpan: number): number[] {
    const stepCandidates = [5, 10, 15, 20, 25, 50];
    const target = 5;
    let step = 25;
    for (const s of stepCandidates) {
        if ((longSpan * 2) / s >= target) {
            step = s;
            break;
        }
    }
    const out: number[] = [];
    const limit = Math.floor(longSpan / step) * step;
    for (let v = -limit; v <= limit; v += step) out.push(v);
    return out;
}

function computeLatTicks(latSpan: number): number[] {
    const stepCandidates = [5, 10, 15, 20, 25];
    const target = 5;
    let step = 10;
    for (const s of stepCandidates) {
        if ((latSpan * 2) / s >= target) {
            step = s;
            break;
        }
    }
    const out: number[] = [];
    const limit = Math.floor(latSpan / step) * step;
    for (let v = -limit; v <= limit; v += step) out.push(v);
    return out;
}
