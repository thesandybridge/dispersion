import type { Club } from "../../types";

type Props = {
    a: Club;
    b: Club;
    width?: number;
    height?: number;
};

const COLOR_A = { fill: "#62b375", stroke: "#2c8a5e" };
const COLOR_B = { fill: "#e85d4d", stroke: "#a23939" };

export function CompareDispersionViz({
    a,
    b,
    width = 600,
    height = 420,
}: Props) {
    const aCenter = a.carryYards;
    const bCenter = b.carryYards;
    const center = (aCenter + bCenter) / 2;

    const long2 = Math.max(a.carrySd, b.carrySd) * 3.2;
    const lat2 = Math.max(a.lateralSd, b.lateralSd) * 3.2;
    const longSpan = Math.max(
        long2,
        Math.abs(aCenter - center) + a.carrySd * 2.5,
        Math.abs(bCenter - center) + b.carrySd * 2.5,
        25,
    );
    const latSpan = Math.max(lat2, 18);

    const padX = 44;
    const padY = 22;
    const sxScale = (width - padX * 2) / (latSpan * 2);
    const syScale = (height - padY * 2) / (longSpan * 2);
    const scale = Math.min(sxScale, syScale);

    const cx = width / 2;
    const cy = height / 2;
    const sx = (lat: number) => cx + lat * scale;
    const sy = (lng: number) => cy - (lng - center) * scale;

    const ringPath = (
        carry: number,
        carrySd: number,
        lateralSd: number,
        k: number,
    ): string => {
        const facets = 28;
        const pts: string[] = [];
        for (let i = 0; i < facets; i++) {
            const t = (i / facets) * Math.PI * 2;
            const dx = Math.cos(t) * k * lateralSd;
            const dy = Math.sin(t) * k * carrySd;
            pts.push(`${sx(dx).toFixed(1)},${sy(carry + dy).toFixed(1)}`);
        }
        return `M${pts.join(" L")} Z`;
    };

    const ringsFor = (
        club: Club,
        color: { fill: string; stroke: string },
    ) => (
        <g>
            {[2.4, 1.6, 0.9].map((k, i) => (
                <path
                    key={i}
                    d={ringPath(club.carryYards, club.carrySd, club.lateralSd, k)}
                    fill={color.fill}
                    fillOpacity={0.08 + i * 0.07}
                    stroke="none"
                />
            ))}
            <path
                d={ringPath(club.carryYards, club.carrySd, club.lateralSd, 2.0)}
                fill="none"
                stroke={color.stroke}
                strokeWidth="1.5"
            />
            <circle
                cx={sx(0)}
                cy={sy(club.carryYards)}
                r="3"
                fill={color.stroke}
            />
        </g>
    );

    return (
        <svg
            viewBox={`0 0 ${width} ${height}`}
            preserveAspectRatio="xMidYMid meet"
            width="100%"
            height="100%"
            style={{ display: "block" }}
        >
            <rect x="0" y="0" width={width} height={height} fill="#0e1a13" />

            <line
                x1={sx(0)}
                y1={padY}
                x2={sx(0)}
                y2={height - padY}
                stroke="rgba(246,241,225,0.15)"
                strokeWidth="0.5"
                strokeDasharray="3 4"
            />

            {ringsFor(a, COLOR_A)}
            {ringsFor(b, COLOR_B)}

            <g
                fontFamily="ui-monospace, monospace"
                fontSize="10.5"
                pointerEvents="none"
            >
                <text x={padX - 6} y={sy(a.carryYards) + 3} textAnchor="end" fill={COLOR_A.stroke}>
                    {a.name}
                </text>
                <text x={padX - 6} y={sy(b.carryYards) + 3} textAnchor="end" fill={COLOR_B.stroke}>
                    {b.name}
                </text>
            </g>
        </svg>
    );
}
