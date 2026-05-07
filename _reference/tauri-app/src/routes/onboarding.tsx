import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useState } from "react";
import { TopoBg } from "../components/primitives/TopoBg";
import { DispersionViz } from "../components/primitives/DispersionViz";
import { Icon } from "../components/primitives/Icon";
import { useSettings } from "../lib/settingsStore";
import { newId } from "../lib/id";
import { useCreateClub } from "../lib/queries";
import { useQueryClient } from "@tanstack/react-query";
import { fromYards, roundForUnit, toYards, unitLabel } from "../lib/units";

type Search = { step: number };

export const Route = createFileRoute("/onboarding")({
    validateSearch: (raw: Record<string, unknown>): Search => {
        const n = Number(raw.step);
        return { step: Number.isFinite(n) && n >= 1 && n <= 4 ? n : 1 };
    },
    component: OnboardingPage,
});

function OnboardingPage() {
    const { step } = Route.useSearch();
    const navigate = useNavigate({ from: "/onboarding" });
    const completeOnboarding = useSettings((s) => s.completeOnboarding);
    const unit = useSettings((s) => s.unit);
    const u = unitLabel(unit);
    const [carryDisplay, setCarryDisplay] = useState(
        roundForUnit(fromYards(168, unit), unit),
    );
    const create = useCreateClub();
    const qc = useQueryClient();
    const [error, setError] = useState<string | null>(null);
    const [busy, setBusy] = useState(false);

    function next() {
        if (step < 4) navigate({ search: { step: step + 1 }, replace: true });
        else finish();
    }
    function back() {
        if (step > 1) navigate({ search: { step: step - 1 }, replace: true });
    }
    function skip() {
        completeOnboarding();
        navigate({ to: "/clubs" });
    }
    async function finish() {
        if (busy) return;
        setBusy(true);
        setError(null);
        try {
            await create.mutateAsync({
                id: newId(),
                name: "7 Iron",
                carryYards: toYards(carryDisplay, unit),
                carrySd: 6,
                lateralSd: 8,
            });
            await qc.refetchQueries({ queryKey: ["clubs"] });
            completeOnboarding();
            navigate({ to: "/calculator", search: {} as never });
        } catch (e) {
            setError((e as Error).message ?? "Failed to save club");
            setBusy(false);
        }
    }

    return (
        <div
            className="flex-1 min-h-0 overflow-hidden flex flex-col relative"
            style={{ background: "#0e1a13", color: "#f6f1e1" }}
        >
            <div
                className="absolute inset-0 opacity-50 pointer-events-none"
                aria-hidden
            >
                <TopoBg
                    width={520}
                    height={760}
                    seed={step * 7}
                    color="rgba(98,179,117,0.12)"
                    accent="rgba(232,93,77,0.4)"
                />
            </div>

            {/* progress + skip */}
            <div className="flex items-center gap-3 px-[22px] pt-5 relative z-10">
                <div className="flex flex-1 gap-1.5">
                    {[1, 2, 3, 4].map((i) => (
                        <div
                            key={i}
                            className="flex-1 rounded-full"
                            style={{
                                height: 3,
                                background:
                                    i <= step
                                        ? "#62b375"
                                        : "rgba(246,241,225,0.12)",
                            }}
                        />
                    ))}
                </div>
                <button
                    onClick={skip}
                    className="px-4 py-3 -my-2 text-[12px] tracking-[0.18em] uppercase"
                    style={{ color: "rgba(246,241,225,0.5)" }}
                >
                    Skip
                </button>
            </div>

            <div className="flex-1 min-h-0 overflow-auto px-[22px] pt-10 pb-5 relative z-10">
                {step === 1 && <Hello />}
                {step === 2 && <MathPrimer />}
                {step === 3 && (
                    <FirstClub
                        unit={u}
                        value={carryDisplay}
                        onChange={setCarryDisplay}
                    />
                )}
                {step === 4 && <Ready />}
            </div>

            {error && (
                <div
                    className="mx-[22px] mb-2 rounded-lg px-3 py-2 text-[12px] relative z-10"
                    style={{
                        background: "rgba(162,57,57,0.18)",
                        border: "1px solid rgba(162,57,57,0.45)",
                        color: "#f6f1e1",
                    }}
                >
                    {error}
                </div>
            )}
            <div className="px-[22px] pb-6 flex gap-2.5 relative z-10">
                {step > 1 && (
                    <button
                        onClick={back}
                        disabled={busy}
                        className="px-4 py-3.5 rounded-[10px] disabled:opacity-50"
                        style={{
                            background: "transparent",
                            color: "rgba(246,241,225,0.7)",
                            border: "1px solid rgba(246,241,225,0.18)",
                            fontSize: 14,
                        }}
                    >
                        Back
                    </button>
                )}
                <button
                    onClick={next}
                    disabled={busy}
                    className="flex-1 py-3.5 rounded-[10px] flex items-center justify-center gap-1.5 disabled:opacity-60"
                    style={{
                        background: "#62b375",
                        color: "#0a1410",
                        fontSize: 14,
                        fontWeight: 600,
                    }}
                >
                    {busy
                        ? "Saving…"
                        : step === 4
                          ? "Open the bag"
                          : "Continue"}
                    {!busy && (
                        <Icon.ChevronRight size={14} color="#0a1410" />
                    )}
                </button>
            </div>
        </div>
    );
}

function Hello() {
    return (
        <div>
            <div
                className="text-[11px] tracking-[0.24em] uppercase mb-4"
                style={{ color: "#62b375" }}
            >
                ◆ Dispersion · v1
            </div>
            <div
                className="font-display"
                style={{
                    fontSize: 44,
                    lineHeight: 1.05,
                    letterSpacing: "-0.02em",
                    textWrap: "pretty",
                }}
            >
                Hit the club{" "}
                <em style={{ color: "#a9d18e", fontStyle: "italic" }}>
                    most likely
                </em>{" "}
                to land where you want it.
            </div>
            <div
                className="text-[14px] leading-relaxed mt-4 max-w-sm"
                style={{
                    color: "rgba(246,241,225,0.65)",
                    textWrap: "pretty",
                }}
            >
                A probability-first club selector for serious amateurs. You
                teach it your dispersion. It does the math.
            </div>
        </div>
    );
}

function MathPrimer() {
    return (
        <div>
            <div
                className="text-[11px] tracking-[0.24em] uppercase mb-4"
                style={{ color: "rgba(246,241,225,0.55)" }}
            >
                Step 1 of 3 · How it thinks
            </div>
            <div
                className="font-display"
                style={{
                    fontSize: 32,
                    lineHeight: 1.1,
                    letterSpacing: "-0.02em",
                    textWrap: "pretty",
                }}
            >
                Every shot is a distribution. Not a number.
            </div>
            <div className="flex justify-center my-7">
                <DispersionViz
                    width={260}
                    height={220}
                    carry={150}
                    carrySd={8}
                    lateralSd={6}
                    distanceToTarget={150}
                    showLabels={false}
                    showGrid
                />
            </div>
            <div
                className="text-[13px] leading-relaxed"
                style={{
                    color: "rgba(246,241,225,0.65)",
                    textWrap: "pretty",
                }}
            >
                We model carry and lateral as independent normals, then compute
                the probability your shot lands in your safe zone. Bigger zone,
                more clubs work. Tighter zone, fewer.
            </div>
        </div>
    );
}

function FirstClub({
    unit,
    value,
    onChange,
}: {
    unit: string;
    value: number;
    onChange: (n: number) => void;
}) {
    return (
        <div>
            <div
                className="text-[11px] tracking-[0.24em] uppercase mb-4"
                style={{ color: "rgba(246,241,225,0.55)" }}
            >
                Step 2 of 3 · Add your first club
            </div>
            <div
                className="font-display mb-5"
                style={{
                    fontSize: 32,
                    lineHeight: 1.1,
                    letterSpacing: "-0.02em",
                }}
            >
                Start with your 7 iron.
            </div>
            <div
                className="rounded-xl p-[18px]"
                style={{
                    background: "rgba(246,241,225,0.04)",
                    border: "1px solid rgba(246,241,225,0.08)",
                }}
            >
                <div
                    className="text-[11px] tracking-[0.16em] uppercase mb-2.5"
                    style={{ color: "rgba(246,241,225,0.5)" }}
                >
                    Average carry
                </div>
                <div className="flex items-baseline gap-2">
                    <span
                        className="font-display tabular"
                        style={{ fontSize: 56, lineHeight: 1, color: "#f6f1e1" }}
                    >
                        {Math.round(value)}
                    </span>
                    <span
                        className="text-[14px]"
                        style={{ color: "rgba(246,241,225,0.55)" }}
                    >
                        {unit}
                    </span>
                </div>
                <input
                    type="range"
                    value={value}
                    min={unit === "yd" ? 80 : 70}
                    max={unit === "yd" ? 280 : 260}
                    step={1}
                    onChange={(e) => onChange(Number(e.target.value))}
                    className="w-full mt-4"
                    style={{ accentColor: "#62b375" }}
                />
            </div>
            <div
                className="text-[12px] leading-relaxed mt-3.5"
                style={{
                    color: "rgba(246,241,225,0.5)",
                    textWrap: "pretty",
                }}
            >
                Don't overthink it. We'll dial in your dispersion using shot
                tracker data, or you can edit by feel later.
            </div>
        </div>
    );
}

function Ready() {
    return (
        <div className="flex flex-col justify-center h-full">
            <div
                className="text-[11px] tracking-[0.24em] uppercase mb-4"
                style={{ color: "#62b375" }}
            >
                ◆ Ready
            </div>
            <div
                className="font-display"
                style={{
                    fontSize: 40,
                    lineHeight: 1.05,
                    letterSpacing: "-0.02em",
                    textWrap: "pretty",
                }}
            >
                Your bag is local. Your data is yours.
            </div>
            <div
                className="text-[14px] leading-relaxed mt-4"
                style={{
                    color: "rgba(246,241,225,0.65)",
                    textWrap: "pretty",
                }}
            >
                Everything stays on this device. Export to JSON anytime. No
                accounts, no cloud, no telemetry.
            </div>
            <div className="mt-7 grid gap-2">
                {[
                    "Local-first storage",
                    "Export / import as JSON",
                    "Theme: light · dark · course",
                ].map((t) => (
                    <div
                        key={t}
                        className="flex items-center gap-2.5 text-[13px]"
                        style={{ color: "rgba(246,241,225,0.75)" }}
                    >
                        <span
                            className="w-1.5 h-1.5 rounded-full"
                            style={{ background: "#62b375" }}
                        />
                        {t}
                    </div>
                ))}
            </div>
        </div>
    );
}
