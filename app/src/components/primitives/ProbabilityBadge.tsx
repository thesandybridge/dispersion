import { probLabel } from "../../lib/probLabel";

export function ProbabilityBadge({ probability }: { probability: number }) {
    const { label, color } = probLabel(probability);
    return (
        <span
            className="inline-flex items-center gap-1.5 text-[10px] tracking-[0.22em] uppercase"
            style={{ color }}
        >
            <span
                className="w-1 h-1 rounded-full"
                style={{ background: color }}
            />
            {label}
        </span>
    );
}
