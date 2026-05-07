import { useRef } from "react";

export type FacePoint = { id?: string; x: number; y: number };

type Props = {
    width?: number;
    height?: number;
    strikes: FacePoint[];
    cursor?: FacePoint | null;
    onTap?: (p: FacePoint) => void;
    selectedId?: string | null;
    onSelect?: (id: string) => void;
};

export function ClubFaceViz({
    width = 320,
    height = 220,
    strikes,
    cursor,
    onTap,
    selectedId,
    onSelect,
}: Props) {
    const ref = useRef<SVGSVGElement>(null);

    const padX = 32;
    const padY = 36;
    const w = width - padX * 2;
    const h = height - padY * 2;

    const sx = (x: number) => padX + ((x + 1) / 2) * w;
    const sy = (y: number) => padY + ((1 - (y + 1) / 2)) * h;
    const inverseX = (px: number) => ((px - padX) / w) * 2 - 1;
    const inverseY = (py: number) => 1 - ((py - padY) / h) * 2;

    function handleClick(e: React.MouseEvent<SVGSVGElement>) {
        if (!onTap) return;
        const svg = ref.current;
        if (!svg) return;
        const pt = svg.createSVGPoint();
        pt.x = e.clientX;
        pt.y = e.clientY;
        const ctm = svg.getScreenCTM();
        if (!ctm) return;
        const local = pt.matrixTransform(ctm.inverse());
        const x = clamp(inverseX(local.x), -1, 1);
        const y = clamp(inverseY(local.y), -1, 1);
        onTap({ x, y });
    }

    return (
        <svg
            ref={ref}
            width="100%"
            height="100%"
            viewBox={`0 0 ${width} ${height}`}
            preserveAspectRatio="xMidYMid meet"
            onClick={handleClick}
            style={{
                display: "block",
                cursor: onTap ? "crosshair" : "default",
            }}
        >
            <defs>
                <linearGradient id="cfv-face" x1="0%" y1="0%" x2="0%" y2="100%">
                    <stop offset="0%" stopColor="#202a23" />
                    <stop offset="100%" stopColor="#0e1a13" />
                </linearGradient>
                <radialGradient id="cfv-sweet" cx="50%" cy="50%" r="40%">
                    <stop offset="0%" stopColor="rgba(98,179,117,0.18)" />
                    <stop offset="100%" stopColor="rgba(98,179,117,0)" />
                </radialGradient>
            </defs>

            <rect
                x={padX}
                y={padY}
                width={w}
                height={h}
                rx={20}
                fill="url(#cfv-face)"
                stroke="rgba(246,241,225,0.18)"
                strokeWidth="1"
            />

            {/* sweet spot glow */}
            <ellipse
                cx={sx(0)}
                cy={sy(0)}
                rx={w * 0.18}
                ry={h * 0.22}
                fill="url(#cfv-sweet)"
            />

            {/* groove lines */}
            <g
                stroke="rgba(246,241,225,0.08)"
                strokeWidth="0.6"
            >
                {[-0.7, -0.4, -0.1, 0.2, 0.5, 0.8].map((y) => (
                    <line
                        key={y}
                        x1={sx(-0.95)}
                        y1={sy(y)}
                        x2={sx(0.95)}
                        y2={sy(y)}
                    />
                ))}
            </g>

            {/* center crosshair */}
            <line
                x1={sx(0)}
                y1={padY + 4}
                x2={sx(0)}
                y2={padY + h - 4}
                stroke="rgba(246,241,225,0.18)"
                strokeWidth="0.5"
                strokeDasharray="3 4"
            />
            <line
                x1={padX + 4}
                y1={sy(0)}
                x2={padX + w - 4}
                y2={sy(0)}
                stroke="rgba(246,241,225,0.18)"
                strokeWidth="0.5"
                strokeDasharray="3 4"
            />

            {/* labels */}
            <g
                fontFamily="ui-monospace, monospace"
                fontSize="10"
                fill="rgba(246,241,225,0.5)"
                pointerEvents="none"
            >
                <text x={padX} y={padY - 10}>CROWN</text>
                <text x={padX} y={padY + h + 18}>SOLE</text>
                <text x={padX - 4} y={sy(0) - 6} textAnchor="end">
                    HEEL
                </text>
                <text x={padX + w + 4} y={sy(0) - 6}>
                    TOE
                </text>
            </g>

            {/* strike dots */}
            {strikes.map((s, i) => {
                const id = s.id ?? `${i}`;
                const selected = selectedId === id;
                return (
                    <g key={id}>
                        <circle
                            cx={sx(s.x)}
                            cy={sy(s.y)}
                            r={selected ? 7 : 5}
                            fill={selected ? "#a9d18e" : "#f6f1e1"}
                            stroke="#0a1410"
                            strokeWidth="1.2"
                            onClick={(e) => {
                                e.stopPropagation();
                                if (s.id && onSelect) onSelect(s.id);
                            }}
                            style={{
                                cursor: onSelect ? "pointer" : "default",
                            }}
                        />
                    </g>
                );
            })}

            {cursor && (
                <g pointerEvents="none">
                    <circle
                        cx={sx(cursor.x)}
                        cy={sy(cursor.y)}
                        r="9"
                        fill="rgba(232,93,77,0.18)"
                        stroke="#e85d4d"
                        strokeWidth="1.4"
                    />
                    <circle
                        cx={sx(cursor.x)}
                        cy={sy(cursor.y)}
                        r="2.5"
                        fill="#e85d4d"
                    />
                </g>
            )}
        </svg>
    );
}

function clamp(v: number, lo: number, hi: number): number {
    return Math.min(hi, Math.max(lo, v));
}
