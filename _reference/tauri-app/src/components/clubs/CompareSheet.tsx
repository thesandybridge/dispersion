import { useState } from "react";
import type { Club } from "../../types";
import { Modal } from "../Modal";
import { CompareDispersionViz } from "../primitives/CompareDispersionViz";
import { useSettings } from "../../lib/settingsStore";
import { fromYards, unitLabel } from "../../lib/units";

type Props = {
    base: Club;
    candidates: Club[];
    onClose: () => void;
};

export function CompareSheet({ base, candidates, onClose }: Props) {
    const others = candidates.filter((c) => c.id !== base.id);
    const [selectedId, setSelectedId] = useState<string | null>(
        others[0]?.id ?? null,
    );
    const other = others.find((c) => c.id === selectedId) ?? null;
    const unit = useSettings((s) => s.unit);
    const u = unitLabel(unit);

    return (
        <Modal onClose={onClose} labelledBy="compare-title">
            <div className="mb-4">
                <div
                    className="text-[10px] tracking-[0.2em] uppercase"
                    style={{ color: "rgba(26,36,25,0.5)" }}
                >
                    Compare
                </div>
                <h2
                    id="compare-title"
                    className="font-display text-2xl mt-1"
                    style={{ letterSpacing: "-0.02em" }}
                >
                    {base.name} vs…
                </h2>
            </div>

            <div className="flex flex-wrap gap-1.5 mb-4">
                {others.map((c) => {
                    const active = c.id === selectedId;
                    return (
                        <button
                            key={c.id}
                            onClick={() => setSelectedId(c.id)}
                            className="px-3 py-2 rounded-full text-[12px]"
                            style={{
                                background: active
                                    ? "#1a2419"
                                    : "rgba(26,36,25,0.05)",
                                color: active
                                    ? "#f4efe3"
                                    : "rgba(26,36,25,0.75)",
                            }}
                        >
                            {c.name}
                        </button>
                    );
                })}
            </div>

            {other && (
                <>
                    <div
                        className="rounded-2xl overflow-hidden mb-4"
                        style={{
                            aspectRatio: "1.4",
                            background: "#0e1a13",
                        }}
                    >
                        <CompareDispersionViz a={base} b={other} />
                    </div>

                    <div
                        className="grid gap-2 mb-2"
                        style={{
                            gridTemplateColumns: "1fr auto auto",
                        }}
                    >
                        <div />
                        <div
                            className="text-[10px] tracking-[0.18em] uppercase text-right"
                            style={{ color: "#2c8a5e" }}
                        >
                            {base.name}
                        </div>
                        <div
                            className="text-[10px] tracking-[0.18em] uppercase text-right"
                            style={{ color: "#a23939" }}
                        >
                            {other.name}
                        </div>

                        <Row
                            label="Carry"
                            a={`${Math.round(fromYards(base.carryYards, unit))}${u}`}
                            b={`${Math.round(fromYards(other.carryYards, unit))}${u}`}
                        />
                        <Row
                            label="σ↕"
                            a={`${fromYards(base.carrySd, unit).toFixed(1)}${u}`}
                            b={`${fromYards(other.carrySd, unit).toFixed(1)}${u}`}
                            tighter={base.carrySd < other.carrySd ? "a" : "b"}
                        />
                        <Row
                            label="σ↔"
                            a={`${fromYards(base.lateralSd, unit).toFixed(1)}${u}`}
                            b={`${fromYards(other.lateralSd, unit).toFixed(1)}${u}`}
                            tighter={
                                base.lateralSd < other.lateralSd ? "a" : "b"
                            }
                        />
                    </div>
                </>
            )}

            {!other && (
                <div
                    className="text-center py-10 text-[13px]"
                    style={{ color: "rgba(26,36,25,0.55)" }}
                >
                    No other clubs to compare with.
                </div>
            )}
        </Modal>
    );
}

function Row({
    label,
    a,
    b,
    tighter,
}: {
    label: string;
    a: string;
    b: string;
    tighter?: "a" | "b";
}) {
    return (
        <>
            <div
                className="text-[12px] py-1.5"
                style={{ color: "rgba(26,36,25,0.55)" }}
            >
                {label}
            </div>
            <div
                className="font-mono text-[14px] text-right py-1.5 tabular"
                style={{
                    color: tighter === "a" ? "#2c8a5e" : "#1a2419",
                    fontWeight: tighter === "a" ? 600 : 400,
                }}
            >
                {a}
            </div>
            <div
                className="font-mono text-[14px] text-right py-1.5 tabular"
                style={{
                    color: tighter === "b" ? "#2c8a5e" : "#1a2419",
                    fontWeight: tighter === "b" ? 600 : 400,
                }}
            >
                {b}
            </div>
        </>
    );
}
