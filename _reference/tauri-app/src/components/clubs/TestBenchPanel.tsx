import { useState } from "react";
import {
    useClubs,
    useCreateTestClub,
    useDeleteTestClub,
    useTestClubs,
    useUpdateTestClub,
} from "../../lib/queries";
import { newId } from "../../lib/id";
import { useSettings } from "../../lib/settingsStore";
import { fromYards, roundForUnit, toYards, unitLabel } from "../../lib/units";
import { ConfirmDialog } from "../ConfirmDialog";
import { CompareDispersionViz } from "../primitives/CompareDispersionViz";
import { BenchGappingChart } from "../primitives/BenchGappingChart";
import type { Club, TestClub } from "../../types";

type Mode =
    | { kind: "list" }
    | { kind: "new" }
    | { kind: "edit"; club: TestClub };

export function TestBenchPanel() {
    const tests = useTestClubs();
    const clubs = useClubs();
    const create = useCreateTestClub();
    const update = useUpdateTestClub();
    const remove = useDeleteTestClub();
    const [mode, setMode] = useState<Mode>({ kind: "list" });
    const [pendingDelete, setPendingDelete] = useState<TestClub | null>(null);
    const [compareWith, setCompareWith] = useState<{
        test: TestClub;
        bagClub: Club | null;
    } | null>(null);

    const unit = useSettings((s) => s.unit);
    const u = unitLabel(unit);

    if (mode.kind !== "list") {
        return (
            <div className="px-5 py-5 md:px-7 md:py-6 max-w-2xl mx-auto">
                <button
                    onClick={() => setMode({ kind: "list" })}
                    className="text-[12px] tracking-[0.16em] uppercase mb-3"
                    style={{ color: "rgba(26,36,25,0.6)" }}
                >
                    ← Back
                </button>
                <TestClubForm
                    initial={mode.kind === "edit" ? mode.club : undefined}
                    onSave={(values) => {
                        if (mode.kind === "edit") {
                            update.mutate(
                                { id: mode.club.id, patch: values },
                                {
                                    onSuccess: () =>
                                        setMode({ kind: "list" }),
                                },
                            );
                        } else {
                            create.mutate(
                                { id: newId(), ...values },
                                {
                                    onSuccess: () =>
                                        setMode({ kind: "list" }),
                                },
                            );
                        }
                    }}
                />
            </div>
        );
    }

    const list = tests.data ?? [];
    const bagClubs = clubs.data ?? [];

    return (
        <div className="px-[18px] py-4 md:px-7 max-w-3xl mx-auto">
            <div
                className="rounded-2xl p-4 mb-4"
                style={{
                    background: "rgba(26,36,25,0.04)",
                    border: "1px dashed rgba(26,36,25,0.18)",
                }}
            >
                <div
                    className="text-[10px] tracking-[0.2em] uppercase"
                    style={{ color: "#e85d4d" }}
                >
                    Test bench
                </div>
                <div
                    className="text-[13px] mt-1 leading-snug"
                    style={{ color: "rgba(26,36,25,0.75)" }}
                >
                    Drop in clubs you're considering — a new driver, a
                    different wedge set — and see how they'd fit your bag
                    without polluting your real σ data.
                </div>
            </div>

            {bagClubs.length > 0 && list.length > 0 && (
                <div className="mb-5">
                    <div
                        className="text-[10px] tracking-[0.2em] uppercase mb-2"
                        style={{ color: "rgba(26,36,25,0.55)" }}
                    >
                        Bench in your bag
                    </div>
                    <div
                        className="rounded-2xl bg-white p-2"
                        style={{ border: "1px solid rgba(26,36,25,0.08)" }}
                    >
                        <BenchGappingChart
                            bag={bagClubs}
                            bench={list}
                            unit={unit}
                        />
                    </div>
                </div>
            )}

            <div className="flex items-center justify-between mb-3">
                <div
                    className="text-[10px] tracking-[0.2em] uppercase"
                    style={{ color: "rgba(26,36,25,0.55)" }}
                >
                    {list.length} prospect
                    {list.length === 1 ? "" : "s"}
                </div>
                <button
                    onClick={() => setMode({ kind: "new" })}
                    className="px-3.5 py-2 rounded-full text-[13px] font-medium"
                    style={{ background: "#e85d4d", color: "#0a1410" }}
                >
                    + Add prospect
                </button>
            </div>

            {list.length === 0 ? (
                <div
                    className="rounded-2xl px-5 py-10 text-center text-[13px]"
                    style={{
                        background: "rgba(26,36,25,0.04)",
                        color: "rgba(26,36,25,0.55)",
                    }}
                >
                    No prospects yet. Add a club you're considering to see
                    how it'd fit.
                </div>
            ) : (
                <div className="space-y-2">
                    {list.map((t) => (
                        <BenchRow
                            key={t.id}
                            test={t}
                            unit={unit}
                            onEdit={() =>
                                setMode({ kind: "edit", club: t })
                            }
                            onDelete={() => setPendingDelete(t)}
                            onCompare={(bagClub) =>
                                setCompareWith({ test: t, bagClub })
                            }
                            bagClubs={bagClubs}
                        />
                    ))}
                </div>
            )}

            <ConfirmDialog
                open={!!pendingDelete}
                onOpenChange={(o) => {
                    if (!o) setPendingDelete(null);
                }}
                title={`Delete ${pendingDelete?.name ?? "prospect"}?`}
                description="The bench entry is removed. Doesn't affect your bag."
                confirmLabel="Delete"
                danger
                onConfirm={() => {
                    if (pendingDelete) remove.mutate(pendingDelete.id);
                    setPendingDelete(null);
                }}
            />

            {compareWith && compareWith.bagClub && (
                <CompareSheetMini
                    test={compareWith.test}
                    bagClub={compareWith.bagClub}
                    onClose={() => setCompareWith(null)}
                    unit={u}
                />
            )}
        </div>
    );
}

function BenchRow({
    test,
    unit,
    onEdit,
    onDelete,
    onCompare,
    bagClubs,
}: {
    test: TestClub;
    unit: "yards" | "meters";
    onEdit: () => void;
    onDelete: () => void;
    onCompare: (c: Club | null) => void;
    bagClubs: Club[];
}) {
    const u = unitLabel(unit);
    const closest = bagClubs
        .slice()
        .sort(
            (a, b) =>
                Math.abs(a.carryYards - test.carryYards) -
                Math.abs(b.carryYards - test.carryYards),
        )[0] ?? null;
    return (
        <div
            className="rounded-2xl bg-white p-3.5"
            style={{ border: "1px solid rgba(232,93,77,0.35)" }}
        >
            <div className="flex items-start justify-between gap-3">
                <div className="min-w-0">
                    <div className="text-[14px] font-medium">
                        {test.name}
                    </div>
                    {test.source && (
                        <div
                            className="text-[11px] mt-0.5"
                            style={{ color: "rgba(26,36,25,0.5)" }}
                        >
                            {test.source}
                        </div>
                    )}
                    <div
                        className="font-mono text-[11px] mt-1"
                        style={{ color: "rgba(26,36,25,0.6)" }}
                    >
                        {Math.round(fromYards(test.carryYards, unit))}
                        {u} carry · σ↕{" "}
                        {fromYards(test.carrySd, unit).toFixed(1)} · σ↔{" "}
                        {fromYards(test.lateralSd, unit).toFixed(1)}
                    </div>
                </div>
                <div className="flex flex-col items-end gap-1.5 shrink-0">
                    <button
                        onClick={onEdit}
                        className="px-3 py-1.5 rounded-full text-[11px]"
                        style={{
                            background: "rgba(26,36,25,0.05)",
                            color: "#1a2419",
                        }}
                    >
                        Edit
                    </button>
                    <button
                        onClick={onDelete}
                        className="px-3 py-1.5 rounded-full text-[11px]"
                        style={{ color: "#a23939" }}
                    >
                        Delete
                    </button>
                </div>
            </div>

            {closest && (
                <div className="mt-3 pt-3 border-t flex items-center justify-between gap-3" style={{ borderColor: "rgba(26,36,25,0.08)" }}>
                    <div
                        className="text-[11px]"
                        style={{ color: "rgba(26,36,25,0.65)" }}
                    >
                        Closest in bag:{" "}
                        <span className="font-medium text-[#1a2419]">
                            {closest.name}
                        </span>{" "}
                        ({Math.round(fromYards(closest.carryYards, unit))}
                        {u})
                    </div>
                    <button
                        onClick={() => onCompare(closest)}
                        className="px-3 py-1.5 rounded-full text-[12px] font-medium"
                        style={{
                            background: "#1a2419",
                            color: "#f4efe3",
                        }}
                    >
                        Compare
                    </button>
                </div>
            )}
        </div>
    );
}

function CompareSheetMini({
    test,
    bagClub,
    onClose,
    unit,
}: {
    test: TestClub;
    bagClub: Club;
    onClose: () => void;
    unit: string;
}) {
    return (
        <div
            className="fixed inset-0 z-50 flex items-end justify-center bg-black/40"
            onClick={onClose}
        >
            <div
                className="w-full rounded-t-3xl p-6 shadow-xl animate-sheet-up"
                style={{
                    background: "#f4efe3",
                    color: "#1a2419",
                    maxHeight: "min(86vh, 720px)",
                    paddingBottom:
                        "max(env(safe-area-inset-bottom), 18px)",
                    overflow: "auto",
                }}
                onClick={(e) => e.stopPropagation()}
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
                    Compare
                </div>
                <div
                    className="font-display text-2xl mt-1 mb-3"
                    style={{ letterSpacing: "-0.02em" }}
                >
                    {test.name} vs {bagClub.name}
                </div>

                <div
                    className="rounded-2xl overflow-hidden mb-4"
                    style={{
                        aspectRatio: "1.4",
                        background: "#0e1a13",
                    }}
                >
                    <CompareDispersionViz
                        a={bagClub}
                        b={{
                            id: test.id,
                            name: test.name,
                            carryYards: test.carryYards,
                            carrySd: test.carrySd,
                            lateralSd: test.lateralSd,
                            createdAt: test.createdAt,
                        }}
                    />
                </div>

                <div
                    className="grid gap-1 text-[12px]"
                    style={{ gridTemplateColumns: "1fr auto auto" }}
                >
                    <div />
                    <div
                        className="text-[10px] tracking-[0.16em] uppercase text-right"
                        style={{ color: "#2c8a5e" }}
                    >
                        {bagClub.name}
                    </div>
                    <div
                        className="text-[10px] tracking-[0.16em] uppercase text-right"
                        style={{ color: "#a23939" }}
                    >
                        {test.name}
                    </div>
                    <Cell label="Carry" />
                    <Mono v={`${Math.round(bagClub.carryYards)}y`} />
                    <Mono v={`${Math.round(test.carryYards)}y`} />
                    <Cell label="σ↕" />
                    <Mono
                        v={`${bagClub.carrySd.toFixed(1)}`}
                        bold={bagClub.carrySd <= test.carrySd}
                    />
                    <Mono
                        v={`${test.carrySd.toFixed(1)}`}
                        bold={test.carrySd < bagClub.carrySd}
                    />
                    <Cell label="σ↔" />
                    <Mono
                        v={`${bagClub.lateralSd.toFixed(1)}`}
                        bold={bagClub.lateralSd <= test.lateralSd}
                    />
                    <Mono
                        v={`${test.lateralSd.toFixed(1)}`}
                        bold={test.lateralSd < bagClub.lateralSd}
                    />
                </div>

                <div className="mt-4 text-[11px]" style={{ color: "rgba(26,36,25,0.55)" }}>
                    Unit: {unit}. Tighter σ wins (bold).
                </div>
            </div>
        </div>
    );
}

function Cell({ label }: { label: string }) {
    return (
        <div
            className="text-[12px] py-1.5"
            style={{ color: "rgba(26,36,25,0.55)" }}
        >
            {label}
        </div>
    );
}

function Mono({ v, bold }: { v: string; bold?: boolean }) {
    return (
        <div
            className="font-mono text-[14px] text-right py-1.5 tabular"
            style={{
                color: bold ? "#2c8a5e" : "#1a2419",
                fontWeight: bold ? 600 : 400,
            }}
        >
            {v}
        </div>
    );
}

function TestClubForm({
    initial,
    onSave,
}: {
    initial?: TestClub;
    onSave: (values: {
        name: string;
        carryYards: number;
        carrySd: number;
        lateralSd: number;
        source: string;
    }) => void;
}) {
    const unit = useSettings((s) => s.unit);
    const u = unitLabel(unit);
    const [name, setName] = useState(initial?.name ?? "");
    const [source, setSource] = useState(initial?.source ?? "");
    const [carry, setCarry] = useState(
        initial
            ? roundForUnit(fromYards(initial.carryYards, unit), unit)
            : 165,
    );
    const [carrySd, setCarrySd] = useState(
        initial ? roundForUnit(fromYards(initial.carrySd, unit), unit) : 6,
    );
    const [lateralSd, setLateralSd] = useState(
        initial
            ? roundForUnit(fromYards(initial.lateralSd, unit), unit)
            : 8,
    );
    const [error, setError] = useState<string | null>(null);

    function submit() {
        const trimmedName = name.trim();
        if (!trimmedName) return setError("Name required");
        if (carry <= 0) return setError("Carry must be > 0");
        if (carrySd <= 0 || lateralSd <= 0)
            return setError("σ must be > 0");
        setError(null);
        onSave({
            name: trimmedName,
            carryYards: toYards(carry, unit),
            carrySd: toYards(carrySd, unit),
            lateralSd: toYards(lateralSd, unit),
            source: source.trim(),
        });
    }

    return (
        <>
            <div
                className="text-[10px] tracking-[0.2em] uppercase"
                style={{ color: "#e85d4d" }}
            >
                {initial ? "Editing prospect" : "New prospect"}
            </div>
            <div
                className="font-display mt-1 mb-4"
                style={{
                    fontSize: 28,
                    letterSpacing: "-0.02em",
                }}
            >
                {initial?.name || name || "Prospect club"}
            </div>

            <FormField label="Name">
                <Input value={name} onChange={setName} placeholder="e.g. TaylorMade Qi10" />
            </FormField>
            <FormField label="Source / notes">
                <Input
                    value={source}
                    onChange={setSource}
                    placeholder="Demo at Golf Galaxy · Trackman"
                />
            </FormField>
            <FormField label={`Carry (${u})`}>
                <NumberInput value={carry} onChange={setCarry} step={1} />
            </FormField>
            <FormField label={`σ↕ Distance (${u})`}>
                <NumberInput
                    value={carrySd}
                    onChange={setCarrySd}
                    step={0.5}
                />
            </FormField>
            <FormField label={`σ↔ Lateral (${u})`}>
                <NumberInput
                    value={lateralSd}
                    onChange={setLateralSd}
                    step={0.5}
                />
            </FormField>

            {error && (
                <div className="mt-2 text-[12px]" style={{ color: "#a23939" }}>
                    {error}
                </div>
            )}

            <button
                onClick={submit}
                className="w-full mt-5 py-3 rounded-full text-[14px] font-semibold"
                style={{ background: "#e85d4d", color: "#0a1410" }}
            >
                {initial ? "Save changes" : "Add to bench"}
            </button>
        </>
    );
}

function FormField({
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

function Input({
    value,
    onChange,
    placeholder,
}: {
    value: string;
    onChange: (v: string) => void;
    placeholder?: string;
}) {
    return (
        <input
            type="text"
            value={value}
            onChange={(e) => onChange(e.target.value)}
            placeholder={placeholder}
            className="w-full px-3 py-2 rounded-lg bg-white outline-none"
            style={{
                border: "1px solid rgba(26,36,25,0.15)",
                color: "#1a2419",
                fontSize: 16,
            }}
        />
    );
}

function NumberInput({
    value,
    onChange,
    step = 1,
}: {
    value: number;
    onChange: (v: number) => void;
    step?: number;
}) {
    return (
        <input
            type="number"
            inputMode="decimal"
            step={step}
            value={value}
            onChange={(e) => {
                const n = Number(e.target.value);
                if (Number.isFinite(n)) onChange(n);
            }}
            className="w-full px-3 py-2 rounded-lg bg-white outline-none"
            style={{
                border: "1px solid rgba(26,36,25,0.15)",
                color: "#1a2419",
                fontFamily: "var(--font-display)",
                fontFeatureSettings: '"tnum"',
                fontSize: 18,
            }}
        />
    );
}
