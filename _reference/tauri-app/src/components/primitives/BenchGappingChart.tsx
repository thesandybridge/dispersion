import type { Club, TestClub } from "../../types";
import { fromYards, unitLabel } from "../../lib/units";

type Props = {
    bag: Club[];
    bench: TestClub[];
    unit: "yards" | "meters";
    height?: number;
};

const ROW_H = 20;
const ROW_GAP = 3;

type Row = {
    name: string;
    carry: number;
    sd: number;
    isBench: boolean;
};

export function BenchGappingChart({ bag, bench, unit, height }: Props) {
    if (bag.length === 0 && bench.length === 0) return null;
    const u = unitLabel(unit);
    const rows: Row[] = [
        ...bag.map((c) => ({
            name: c.name,
            carry: fromYards(c.carryYards, unit),
            sd: fromYards(c.carrySd, unit),
            isBench: false,
        })),
        ...bench.map((c) => ({
            name: c.name,
            carry: fromYards(c.carryYards, unit),
            sd: fromYards(c.carrySd, unit),
            isBench: true,
        })),
    ].sort((a, b) => b.carry - a.carry);

    const minBound = Math.max(
        0,
        Math.min(...rows.map((r) => r.carry - r.sd * 2.5)) - 5,
    );
    const maxBound =
        Math.max(...rows.map((r) => r.carry + r.sd * 2.5)) + 5;
    const span = Math.max(maxBound - minBound, 50);

    const padLeft = 60;
    const padRight = 16;
    const padTop = 14;
    const rowsHeight = rows.length * (ROW_H + ROW_GAP);
    const padBottom = 24;
    const totalH = height ?? padTop + rowsHeight + padBottom;
    const width = 800;
    const innerW = width - padLeft - padRight;

    const sx = (val: number) =>
        padLeft + ((val - minBound) / span) * innerW;

    const tickStep = chooseTick(span);
    const ticks: number[] = [];
    const start = Math.ceil(minBound / tickStep) * tickStep;
    for (let v = start; v <= maxBound; v += tickStep) ticks.push(v);

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
                        y1={padTop - 4}
                        x2={sx(t)}
                        y2={padTop + rowsHeight + 2}
                    />
                ))}
            </g>

            {rows.map((r, i) => {
                const fill = r.isBench ? "#e85d4d" : "#62b375";
                const stroke = r.isBench ? "#a23939" : "#2c8a5e";
                const x1 = sx(r.carry - r.sd * 2);
                const x2 = sx(r.carry + r.sd * 2);
                const xC = sx(r.carry);
                const y = padTop + i * (ROW_H + ROW_GAP);
                return (
                    <g key={`${r.name}-${i}`}>
                        <text
                            x={padLeft - 8}
                            y={y + ROW_H / 2 + 4}
                            textAnchor="end"
                            fill={r.isBench ? "#a23939" : "rgba(26,36,25,0.7)"}
                            fontFamily="var(--font-sans)"
                            fontSize="11"
                            fontWeight={r.isBench ? 600 : 500}
                        >
                            {truncateName(r.name)}
                        </text>
                        <rect
                            x={x1}
                            y={y}
                            width={Math.max(2, x2 - x1)}
                            height={ROW_H}
                            rx={4}
                            fill={fill}
                            fillOpacity={r.isBench ? 0.28 : 0.22}
                            stroke={stroke}
                            strokeWidth={r.isBench ? 1 : 0.8}
                            strokeDasharray={r.isBench ? "3 2" : undefined}
                        />
                        <line
                            x1={xC}
                            y1={y + 2}
                            x2={xC}
                            y2={y + ROW_H - 2}
                            stroke="#1a2419"
                            strokeWidth="1"
                        />
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
                        y={padTop + rowsHeight + 14}
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
    return name.length > 14 ? `${name.slice(0, 13)}…` : name;
}
