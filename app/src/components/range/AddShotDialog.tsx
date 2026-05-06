import * as Dialog from "@radix-ui/react-dialog";
import { useEffect, useState } from "react";
import type { Club, ShotOutcomeTag } from "../../types";
import { useSettings } from "../../lib/settingsStore";
import { fromYards, roundForUnit, toYards, unitLabel } from "../../lib/units";
import { toggleTag } from "../../lib/outcomes";

type Props = {
    open: boolean;
    onOpenChange: (open: boolean) => void;
    club: Club;
    targetYards: number;
    onAdd: (input: {
        lat: number;
        long: number;
        outcomes: ShotOutcomeTag[];
    }) => void;
};

export function AddShotDialog({
    open,
    onOpenChange,
    club,
    targetYards,
    onAdd,
}: Props) {
    const unit = useSettings((s) => s.unit);
    const u = unitLabel(unit);

    const targetDisplay = roundForUnit(fromYards(targetYards, unit), unit);
    const [carry, setCarry] = useState(targetDisplay);
    const [lateral, setLateral] = useState(0);
    const [side, setSide] = useState<"L" | "R">("R");
    const [tags, setTags] = useState<ShotOutcomeTag[]>([]);

    useEffect(() => {
        if (open) {
            setCarry(targetDisplay);
            setLateral(0);
            setSide("R");
            setTags([]);
        }
    }, [open, targetDisplay]);

    function save() {
        const longDelta = toYards(carry - targetDisplay, unit);
        const lat = toYards(side === "L" ? -lateral : lateral, unit);
        onAdd({ lat, long: longDelta, outcomes: tags });
        onOpenChange(false);
    }

    function tap(t: ShotOutcomeTag) {
        setTags((prev) => toggleTag(prev, t));
    }

    return (
        <Dialog.Root open={open} onOpenChange={onOpenChange}>
            <Dialog.Portal>
                <Dialog.Overlay
                    className="fixed inset-0 z-50"
                    style={{
                        background: "rgba(10,20,16,0.55)",
                        backdropFilter: "blur(2px)",
                        WebkitBackdropFilter: "blur(2px)",
                    }}
                />
                <Dialog.Content
                    className="fixed bottom-0 left-0 right-0 z-50 w-full rounded-t-3xl px-6 pt-6 shadow-xl outline-none animate-sheet-up"
                    style={{
                        background: "#f4efe3",
                        color: "#1a2419",
                        border: "1px solid rgba(26,36,25,0.08)",
                        maxHeight: "min(86vh, 720px)",
                        paddingBottom:
                            "max(env(safe-area-inset-bottom), 18px)",
                        overflow: "auto",
                    }}
                >
                    <div className="flex justify-center -mt-3 mb-2">
                        <div
                            className="rounded-full"
                            style={{
                                width: 36,
                                height: 4,
                                background: "rgba(26,36,25,0.18)",
                            }}
                        />
                    </div>
                    <div
                        className="text-[10px] tracking-[0.2em] uppercase"
                        style={{ color: "rgba(26,36,25,0.5)" }}
                    >
                        Log a shot
                    </div>
                    <Dialog.Title
                        className="font-display text-2xl mt-1 mb-1"
                        style={{ letterSpacing: "-0.02em" }}
                    >
                        {club.name}
                    </Dialog.Title>
                    <Dialog.Description
                        className="text-[12px] mb-5"
                        style={{ color: "rgba(26,36,25,0.55)" }}
                    >
                        Target {targetDisplay} {u}. Enter where the ball
                        actually finished.
                    </Dialog.Description>

                    <Field label={`Carry (${u})`}>
                        <NumberInput
                            value={carry}
                            step={1}
                            onChange={setCarry}
                        />
                    </Field>

                    <Field label={`Lateral miss (${u})`}>
                        <div className="flex items-center gap-2">
                            <NumberInput
                                value={lateral}
                                step={1}
                                min={0}
                                onChange={(n) =>
                                    setLateral(Math.max(0, n))
                                }
                            />
                            <div className="flex">
                                {(["L", "R"] as const).map((s) => (
                                    <button
                                        key={s}
                                        onClick={() => setSide(s)}
                                        className="w-10 py-2 text-[13px] font-medium first:rounded-l-md last:rounded-r-md"
                                        style={{
                                            background:
                                                side === s
                                                    ? "#1a2419"
                                                    : "rgba(26,36,25,0.05)",
                                            color:
                                                side === s
                                                    ? "#f4efe3"
                                                    : "#1a2419",
                                        }}
                                    >
                                        {s}
                                    </button>
                                ))}
                            </div>
                        </div>
                    </Field>

                    <div
                        className="rounded-lg px-3 py-2 mt-3 mb-4 font-mono text-[12px]"
                        style={{
                            background: "rgba(26,36,25,0.05)",
                            color: "rgba(26,36,25,0.7)",
                        }}
                    >
                        Δ {(carry - targetDisplay >= 0 ? "+" : "")}
                        {(carry - targetDisplay).toFixed(0)} {u} long ·{" "}
                        {side === "L" ? "−" : "+"}
                        {lateral.toFixed(0)} {u} lat
                    </div>

                    <div
                        className="text-[10px] tracking-[0.18em] uppercase mb-1.5"
                        style={{ color: "rgba(26,36,25,0.55)" }}
                    >
                        Tags (optional)
                    </div>
                    <div className="grid grid-cols-3 gap-1.5 mb-5">
                        {(
                            [
                                { id: "in", label: "In zone" },
                                { id: "short", label: "Short" },
                                { id: "long", label: "Long" },
                                { id: "left", label: "Left" },
                                { id: "right", label: "Right" },
                                { id: "penalty", label: "Penalty" },
                            ] as Array<{
                                id: ShotOutcomeTag;
                                label: string;
                            }>
                        ).map((t) => {
                            const on = tags.includes(t.id);
                            return (
                                <button
                                    key={t.id}
                                    onClick={() => tap(t.id)}
                                    className="px-3 py-3 rounded-lg text-[13px]"
                                    style={{
                                        background: on
                                            ? "#1a2419"
                                            : "rgba(26,36,25,0.04)",
                                        color: on
                                            ? "#f4efe3"
                                            : "rgba(26,36,25,0.7)",
                                        fontWeight: on ? 600 : 400,
                                    }}
                                >
                                    {t.label}
                                </button>
                            );
                        })}
                    </div>

                    <div className="flex justify-end gap-2">
                        <Dialog.Close asChild>
                            <button
                                className="px-4 py-2 rounded-full text-[13px]"
                                style={{
                                    color: "rgba(26,36,25,0.7)",
                                    background: "rgba(26,36,25,0.05)",
                                }}
                            >
                                Cancel
                            </button>
                        </Dialog.Close>
                        <button
                            onClick={save}
                            className="px-4 py-2 rounded-full text-[13px] font-medium"
                            style={{
                                background: "#1a2419",
                                color: "#f4efe3",
                            }}
                        >
                            Log shot
                        </button>
                    </div>
                </Dialog.Content>
            </Dialog.Portal>
        </Dialog.Root>
    );
}

function Field({
    label,
    children,
}: {
    label: string;
    children: React.ReactNode;
}) {
    return (
        <label className="block mb-3">
            <div
                className="text-[10px] tracking-[0.18em] uppercase mb-1.5"
                style={{ color: "rgba(26,36,25,0.55)" }}
            >
                {label}
            </div>
            {children}
        </label>
    );
}

function NumberInput({
    value,
    onChange,
    step = 1,
    min,
}: {
    value: number;
    onChange: (n: number) => void;
    step?: number;
    min?: number;
}) {
    return (
        <input
            type="number"
            inputMode="decimal"
            step={step}
            min={min}
            value={value}
            onChange={(e) => {
                const n = Number(e.target.value);
                if (Number.isFinite(n)) onChange(n);
            }}
            className="w-full px-3 py-2 rounded-lg bg-white outline-none"
            style={{
                border: "1px solid rgba(26,36,25,0.15)",
                fontFamily: "var(--font-display)",
                fontFeatureSettings: '"tnum"',
                fontSize: 18,
                color: "#1a2419",
            }}
        />
    );
}
