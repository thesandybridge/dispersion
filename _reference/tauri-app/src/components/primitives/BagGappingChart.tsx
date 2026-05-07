import type { Club } from "../../types";
import { fromYards, unitLabel } from "../../lib/units";

type Props = {
    clubs: Club[];
    unit: "yards" | "meters";
    height?: number;
};

const ROW_H = 22;
const ROW_GAP = 4;

export function BagGappingChart({ clubs, unit, height }: Props) {
    if (clubs.length === 0) return null;
    const u = unitLabel(unit);
    const sorted = [...clubs].sort((a, b) => b.carryYards - a.carryYards);

    const fromY = (yards: number) => fromYards(yards, unit);
    const minBound = Math.max(
        0,
        Math.min(...sorted.map((c) => fromY(c.carryYards - c.carrySd * 2.5))) -
            5,
    );
    const maxBound =
        Math.max(...sorted.map((c) => fromY(c.carryYards + c.carrySd * 2.5))) +
        5;
    const span = Math.max(maxBound - minBound, 50);

    const padLeft = 56;
    const padRight = 18;
    const padTop = 22;
    const rowsHeight = sorted.length * (ROW_H + ROW_GAP);
    const padBottom = 26;
    const totalH = height ?? padTop + rowsHeight + padBottom;
    const width = 800;
    const innerW = width - padLeft - padRight;

    const sx = (val: number) =>
        padLeft + ((val - minBound) / span) * innerW;

    const tickStep = chooseTick(span);
    const ticks: number[] = [];
    const start = Math.ceil(minBound / tickStep) * tickStep;
    for (let v = start; v <= maxBound; v += tickStep) ticks.push(v);

    const gaps = findGaps(sorted, fromY);

    return (
        <svg
            viewBox={`0 0 ${width} ${totalH}`}
            preserveAspectRatio="none"
            width="100%"
            height={totalH}
            style={{ display: "block" }}
        >
            <g
                stroke="rgba(26,36,25,0.06)"
                strokeWidth="0.5"
                strokeDasharray="2 4"
            >
                {ticks.map((t) => (
                    <line
                        key={`g${t}`}
                        x1={sx(t)}
                        y1={padTop - 6}
                        x2={sx(t)}
                        y2={padTop + rowsHeight + 4}
                    />
                ))}
            </g>

            {gaps.map((g, i) => (
                <g key={`gap${i}`}>
                    <rect
                        x={sx(g.from)}
                        y={padTop - 6}
                        width={sx(g.to) - sx(g.from)}
                        height={rowsHeight + 10}
                        fill="rgba(232,93,77,0.05)"
                        stroke="rgba(232,93,77,0.45)"
                        strokeWidth="0.7"
                        strokeDasharray="3 3"
                    />
                    <text
                        x={(sx(g.from) + sx(g.to)) / 2}
                        y={padTop - 9}
                        textAnchor="middle"
                        fill="#e85d4d"
                        fontFamily="ui-monospace, monospace"
                        fontSize="9.5"
                    >
                        gap {(g.to - g.from).toFixed(0)}
                        {u}
                    </text>
                </g>
            ))}

            {sorted.map((club, i) => {
                const carry = fromY(club.carryYards);
                const sd = fromY(club.carrySd);
                const x1 = sx(carry - sd * 2);
                const x2 = sx(carry + sd * 2);
                const xC = sx(carry);
                const y = padTop + i * (ROW_H + ROW_GAP);
                return (
                    <g key={club.id}>
                        <text
                            x={padLeft - 8}
                            y={y + ROW_H / 2 + 4}
                            textAnchor="end"
                            fill="rgba(26,36,25,0.7)"
                            fontFamily="var(--font-sans)"
                            fontSize="11"
                            fontWeight="500"
                        >
                            {truncateName(club.name)}
                        </text>
                        <rect
                            x={x1}
                            y={y}
                            width={Math.max(2, x2 - x1)}
                            height={ROW_H}
                            rx={4}
                            fill="#62b375"
                            fillOpacity="0.22"
                            stroke="#2c8a5e"
                            strokeWidth="0.8"
                        />
                        <line
                            x1={xC}
                            y1={y + 2}
                            x2={xC}
                            y2={y + ROW_H - 2}
                            stroke="#1a2419"
                            strokeWidth="1"
                        />
                        <text
                            x={xC}
                            y={y + ROW_H / 2 + 4}
                            textAnchor="middle"
                            fill="#1a2419"
                            fontFamily="ui-monospace, monospace"
                            fontSize="9.5"
                            fontWeight="500"
                        >
                            {Math.round(carry)}
                        </text>
                    </g>
                );
            })}

            <g
                fill="rgba(26,36,25,0.55)"
                fontFamily="ui-monospace, monospace"
                fontSize="9.5"
            >
                {ticks.map((t) => (
                    <text
                        key={`tx${t}`}
                        x={sx(t)}
                        y={padTop + rowsHeight + 16}
                        textAnchor="middle"
                    >
                        {t}
                        {u}
                    </text>
                ))}
            </g>
        </svg>
    );
}

function chooseTick(span: number): number {
    if (span > 400) return 50;
    if (span > 200) return 25;
    if (span > 100) return 20;
    if (span > 60) return 10;
    return 5;
}

function truncateName(name: string): string {
    return name.length > 12 ? `${name.slice(0, 11)}…` : name;
}

function findGaps(
    clubs: Club[],
    convert: (yards: number) => number,
): Array<{ from: number; to: number }> {
    if (clubs.length < 2) return [];
    const ranges = clubs
        .map((c) => ({
            min: convert(c.carryYards - c.carrySd * 2),
            max: convert(c.carryYards + c.carrySd * 2),
        }))
        .sort((a, b) => a.min - b.min);
    const gaps: Array<{ from: number; to: number }> = [];
    let coverEnd = ranges[0]!.max;
    for (let i = 1; i < ranges.length; i++) {
        const r = ranges[i]!;
        if (r.min > coverEnd + 4) {
            gaps.push({ from: coverEnd, to: r.min });
        }
        if (r.max > coverEnd) coverEnd = r.max;
    }
    return gaps;
}
