import { memo, useCallback, useEffect, useMemo, useRef, useState } from "react";
import { motion } from "framer-motion";
import { PlusIcon, BeakerIcon, TagIcon } from "lucide-react";
import { useDial } from "@/lib/dialStore";
import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useQueryClient } from "@tanstack/react-query";
import {
    useAllShots,
    useClubs,
    useCreateClub,
    useCreateFaceStrike,
    useDeleteClub,
    useDeleteFaceStrike,
    useFaceStrikes,
    useShotsByClub,
    useUpdateClub,
} from "../lib/queries";
import { BagTagPanel } from "../components/clubs/BagTagPanel";
import { decodeOutcome } from "../lib/outcomes";
import { useUiStore } from "../lib/uiStore";
import { newId } from "../lib/id";
import { fromYards, roundForUnit, toYards, unitLabel } from "../lib/units";
import { useSettings } from "../lib/settingsStore";
import { SAMPLE_BAG } from "../lib/sampleBag";
import { createClub } from "../db/clubs";
import { DispersionGlyph } from "../components/primitives/DispersionGlyph";
import { DispersionViz } from "../components/primitives/DispersionViz";
import { ResponsiveDispersionViz } from "../components/primitives/ResponsiveDispersionViz";
import { ClubFaceViz } from "../components/primitives/ClubFaceViz";
import { Icon } from "../components/primitives/Icon";
import { ConfirmDialog } from "../components/ConfirmDialog";
import { TopoBg } from "../components/primitives/TopoBg";
import {
    AddStrikeDialog,
    describeFace,
} from "../components/clubs/AddStrikeDialog";
import { dispersionFromShots, sampleSdCi } from "../lib/sigma";
import { summarizeShots } from "../lib/shotStats";
import { TrendChart } from "../components/primitives/TrendChart";
import { BagGappingChart } from "../components/primitives/BagGappingChart";
import { computeInsights } from "../lib/insights";
import { categorize, styleOf } from "../lib/clubCategory";
import { CompareSheet } from "../components/clubs/CompareSheet";
import { TestBenchPanel } from "../components/clubs/TestBenchPanel";
import type { Club } from "../types";

export const Route = createFileRoute("/clubs")({
    component: ClubsPage,
});

type Mode =
    | { kind: "list" }
    | { kind: "new" }
    | { kind: "detail"; club: Club }
    | { kind: "edit"; club: Club };

type SubTab = "bag" | "bench" | "tag";

function ClubsPage() {
    const [subTab, setSubTab] = useState<SubTab>("bag");
    const [mode, setMode] = useState<Mode>({ kind: "list" });
    const clubs = useClubs();
    const newClubRequestId = useUiStore((s) => s.newClubRequestId);
    const lastSeenRequest = useRef(newClubRequestId);

    useEffect(() => {
        if (newClubRequestId !== lastSeenRequest.current) {
            lastSeenRequest.current = newClubRequestId;
            setSubTab("bag");
            setMode({ kind: "new" });
        }
    }, [newClubRequestId]);

    const showHeader =
        subTab !== "bag" || mode.kind !== "detail";

    const openDetail = useCallback(
        (c: Club) => setMode({ kind: "detail", club: c }),
        [],
    );
    const openEdit = useCallback(
        (c: Club) => setMode({ kind: "edit", club: c }),
        [],
    );
    const openNew = useCallback(() => setMode({ kind: "new" }), []);

    const setDialActions = useDial((s) => s.setActions);
    useEffect(() => {
        setDialActions([
            {
                id: "add-club",
                label: "Add club",
                icon: <PlusIcon className="size-5" />,
                tone: "primary",
                onClick: () => {
                    // Add-club only renders in the bag sub-tab; switch over
                    // before opening the new-club form.
                    setSubTab("bag");
                    openNew();
                },
            },
            {
                id: "test-bench",
                label: "Test bench",
                icon: <BeakerIcon className="size-5" />,
                onClick: () => {
                    setMode({ kind: "list" });
                    setSubTab("bench");
                },
            },
            {
                id: "bag-tag",
                label: "Bag tag",
                icon: <TagIcon className="size-5" />,
                onClick: () => {
                    setMode({ kind: "list" });
                    setSubTab("tag");
                },
            },
        ]);
        return () => setDialActions([]);
    }, [setDialActions, openNew]);

    return (
        <div
            className="flex-1 min-h-0 overflow-hidden flex flex-col"
            style={{ background: "#f4efe3", color: "#1a2419" }}
        >
            {showHeader && (
                <ClubsHeader
                    subTab={subTab}
                    onSubTab={(t) => {
                        setSubTab(t);
                        setMode({ kind: "list" });
                    }}
                    mode={mode}
                    onAdd={() => setMode({ kind: "new" })}
                    onBack={() => setMode({ kind: "list" })}
                />
            )}
            <div className="flex-1 min-h-0 overflow-auto">
                {subTab === "bag" && mode.kind === "list" && (
                    <ClubsList
                        clubs={clubs.data ?? []}
                        onOpen={openDetail}
                        onEdit={openEdit}
                        onAddManual={openNew}
                    />
                )}
                {subTab === "bag" && mode.kind === "detail" && (
                    <ClubDetail
                        club={mode.club}
                        onEdit={() =>
                            setMode({ kind: "edit", club: mode.club })
                        }
                        onBack={() => setMode({ kind: "list" })}
                    />
                )}
                {subTab === "bag" &&
                    (mode.kind === "new" || mode.kind === "edit") && (
                        <ClubEditForm
                            initial={
                                mode.kind === "edit" ? mode.club : undefined
                            }
                            onDone={() => setMode({ kind: "list" })}
                        />
                    )}
                {subTab === "bench" && <TestBenchPanel />}
                {subTab === "tag" && <BagTagPanel />}
            </div>
        </div>
    );
}

function ClubsHeader({
    subTab,
    onSubTab,
    mode,
    onAdd,
    onBack,
}: {
    subTab: SubTab;
    onSubTab: (t: SubTab) => void;
    mode: Mode;
    onAdd: () => void;
    onBack: () => void;
}) {
    let title =
        subTab === "tag"
            ? "Bag tag"
            : subTab === "bench"
              ? "Test bench"
              : "My Bag";
    let eyebrow =
        subTab === "tag"
            ? "Profile"
            : subTab === "bench"
              ? "Prospect clubs"
              : "Your clubs";
    if (subTab === "bag" && mode.kind === "new") {
        title = "New club";
        eyebrow = "Adding";
    } else if (subTab === "bag" && mode.kind === "edit") {
        title = mode.club.name;
        eyebrow = "Editing";
    } else if (subTab === "bag" && mode.kind === "detail") {
        title = mode.club.name;
        eyebrow = "Detail";
    }
    return (
        <div
            className="screen-header px-[18px] pb-3 md:px-7 md:pb-3"
            style={{ borderBottom: "1px solid rgba(26,36,25,0.08)" }}
        >
            <div className="flex items-center justify-between mb-3">
                <SubTabSwitch subTab={subTab} onSubTab={onSubTab} />
            </div>
            <div className="flex items-center justify-between">
            <div>
                <div
                    className="text-[10px] tracking-[0.2em] uppercase"
                    style={{ color: "rgba(26,36,25,0.5)" }}
                >
                    {eyebrow}
                </div>
                <div
                    className="font-display"
                    style={{
                        fontSize: "clamp(28px, 5vw, 36px)",
                        marginTop: 2,
                        letterSpacing: "-0.02em",
                    }}
                >
                    {title}
                </div>
            </div>
            {subTab === "bag" && mode.kind === "list" && (
                <button
                    onClick={onAdd}
                    className="flex items-center gap-1.5 px-3.5 py-2.5 rounded-full text-[13px] font-medium shadow-sm transition-transform active:scale-[0.97]"
                    style={{ background: "#1a2419", color: "#f4efe3" }}
                >
                    <PlusIcon className="size-3.5" /> Add club
                </button>
            )}
            {subTab === "bag" && mode.kind !== "list" && (
                <button
                    onClick={onBack}
                    className="text-[13px] px-3.5 py-2 rounded-full transition-colors hover:bg-[rgba(26,36,25,0.06)]"
                    style={{ color: "rgba(26,36,25,0.7)" }}
                >
                    Cancel
                </button>
            )}
            </div>
        </div>
    );
}

function SubTabSwitch({
    subTab,
    onSubTab,
}: {
    subTab: SubTab;
    onSubTab: (t: SubTab) => void;
}) {
    const tabs: Array<{ id: SubTab; label: string }> = [
        { id: "bag", label: "Bag" },
        { id: "bench", label: "Bench" },
        { id: "tag", label: "Tag" },
    ];
    return (
        <div
            className="inline-flex p-1 rounded-full relative"
            style={{ background: "rgba(26,36,25,0.06)" }}
        >
            {tabs.map((t) => {
                const active = t.id === subTab;
                return (
                    <button
                        key={t.id}
                        onClick={() => onSubTab(t.id)}
                        className="relative z-10 px-5 py-2 rounded-full text-[13px] font-medium tracking-[0.04em] transition-colors"
                        style={{
                            color: active ? "#f4efe3" : "rgba(26,36,25,0.55)",
                        }}
                    >
                        {active && (
                            <motion.span
                                layoutId="bagSubTab"
                                className="absolute inset-0 rounded-full"
                                style={{ background: "#1a2419" }}
                                transition={{
                                    type: "spring",
                                    stiffness: 380,
                                    damping: 32,
                                }}
                            />
                        )}
                        <span className="relative">{t.label}</span>
                    </button>
                );
            })}
        </div>
    );
}

function ClubsList({
    clubs,
    onOpen,
    onEdit,
    onAddManual,
}: {
    clubs: Club[];
    onOpen: (c: Club) => void;
    onEdit: (c: Club) => void;
    onAddManual: () => void;
}) {
    const unit = useSettings((s) => s.unit);
    const u = unitLabel(unit);
    const sorted = [...clubs].sort((a, b) => b.carryYards - a.carryYards);
    if (sorted.length === 0) {
        return <ClubsEmptyState onAddManual={onAddManual} />;
    }
    return (
        <div>
            <BagHero clubs={clubs} unit={unit} unitLabel={u} />
            <BagAnalysis clubs={clubs} onOpen={onOpen} />
            <div
                className="px-[18px] pt-5 pb-2 text-[10px] tracking-[0.22em] uppercase flex items-baseline justify-between md:px-7"
                style={{ color: "rgba(26,36,25,0.45)" }}
            >
                <span>
                    {sorted.length} club{sorted.length === 1 ? "" : "s"}
                </span>
                <span className="font-mono normal-case tracking-normal text-[11px]">
                    Sorted by carry
                </span>
            </div>
            <div className="px-[18px] pb-3 md:px-7 space-y-2">
                {sorted.map((c, i) => (
                    <ClubCardRow
                        key={c.id}
                        club={c}
                        unit={unit}
                        unitLabel={u}
                        onOpen={onOpen}
                        onEdit={onEdit}
                        index={i}
                    />
                ))}
            </div>
        </div>
    );
}

function ClubDetail({
    club,
    onEdit,
    onBack,
}: {
    club: Club;
    onEdit: () => void;
    onBack: () => void;
}) {
    const unit = useSettings((s) => s.unit);
    const u = unitLabel(unit);
    const shotsQuery = useShotsByClub(club.id);
    const strikesQuery = useFaceStrikes(club.id);
    const createStrike = useCreateFaceStrike();
    const deleteStrike = useDeleteFaceStrike(club.id);
    const update = useUpdateClub();
    const qc = useQueryClient();
    const allClubs = useClubs();
    const [saveOpen, setSaveOpen] = useState(false);
    const [addStrikeOpen, setAddStrikeOpen] = useState(false);
    const [compareOpen, setCompareOpen] = useState(false);
    const [pendingDeleteStrike, setPendingDeleteStrike] = useState<
        string | null
    >(null);

    const taps = useMemo(() => {
        const data = shotsQuery.data ?? [];
        return data
            .filter(
                (s) =>
                    !(s.longDelta === 0 && s.latDelta === 0),
            )
            .map((s) => ({ lat: s.latDelta, long: s.longDelta }));
    }, [shotsQuery.data]);

    const total = shotsQuery.data?.length ?? 0;
    const stats = useMemo(() => dispersionFromShots(taps), [taps]);
    const longCi = useMemo(
        () => sampleSdCi(taps.map((t) => t.long)),
        [taps],
    );
    const latCi = useMemo(
        () => sampleSdCi(taps.map((t) => t.lat)),
        [taps],
    );
    const haveStats = taps.length >= 2;

    async function applyMeasured() {
        await update.mutateAsync({
            id: club.id,
            patch: {
                name: club.name,
                carryYards: club.carryYards + stats.longBias,
                carrySd: stats.carrySd,
                lateralSd: stats.lateralSd,
            },
        });
        await qc.invalidateQueries({ queryKey: ["clubs"] });
        setSaveOpen(false);
    }

    return (
        <div className="px-5 py-5 md:px-7 md:py-6 max-w-3xl mx-auto">
            <div className="flex items-center justify-between mb-4">
                <button
                    onClick={onBack}
                    className="text-[12px] tracking-[0.16em] uppercase"
                    style={{ color: "rgba(26,36,25,0.6)" }}
                >
                    ← Back
                </button>
                <div className="flex items-center gap-1.5">
                    <button
                        onClick={() => setCompareOpen(true)}
                        className="px-3.5 py-2 rounded-full text-[13px]"
                        style={{
                            background: "rgba(26,36,25,0.06)",
                            color: "#1a2419",
                        }}
                    >
                        Compare
                    </button>
                    <button
                        onClick={onEdit}
                        className="px-3.5 py-2 rounded-full text-[13px]"
                        style={{
                            background: "#1a2419",
                            color: "#f4efe3",
                        }}
                    >
                        Edit
                    </button>
                </div>
            </div>

            <div
                className="rounded-2xl p-4 md:p-5 mb-5"
                style={{ background: "#0e1a13" }}
            >
                <div
                    className="text-[10px] tracking-[0.2em] uppercase"
                    style={{ color: "rgba(246,241,225,0.5)" }}
                >
                    Stored
                </div>
                <div className="grid grid-cols-3 gap-4 mt-2">
                    <DetailStat
                        label="Carry"
                        value={`${Math.round(fromYards(club.carryYards, unit))}${u}`}
                    />
                    <DetailStat
                        label="σ↕ long"
                        value={`${fromYards(club.carrySd, unit).toFixed(1)}${u}`}
                    />
                    <DetailStat
                        label="σ↔ lat"
                        value={`${fromYards(club.lateralSd, unit).toFixed(1)}${u}`}
                    />
                </div>
            </div>

            <div className="mb-3 flex items-center justify-between">
                <div>
                    <div
                        className="text-[10px] tracking-[0.2em] uppercase"
                        style={{ color: "rgba(26,36,25,0.5)" }}
                    >
                        Logged shots
                    </div>
                    <div
                        className="font-mono text-[12px] mt-0.5"
                        style={{ color: "rgba(26,36,25,0.6)" }}
                    >
                        {total} total · {taps.length} with landing data
                    </div>
                </div>
                {haveStats && (
                    <button
                        onClick={() => setSaveOpen(true)}
                        className="text-[11px] tracking-[0.16em] uppercase"
                        style={{ color: "#2c8a5e" }}
                    >
                        Use measured σ ◆
                    </button>
                )}
            </div>

            {haveStats ? (
                <div
                    className="rounded-2xl overflow-hidden"
                    style={{
                        aspectRatio: "1.5",
                        background: "#0e1a13",
                    }}
                >
                    <ResponsiveDispersionViz
                        carry={club.carryYards}
                        carrySd={stats.carrySd}
                        lateralSd={stats.lateralSd}
                        distanceToTarget={club.carryYards}
                        contours={6}
                        facets={28}
                        showGrid={false}
                        showLabels
                        targetDot={false}
                        bg="#0e1a13"
                        fit
                    />
                </div>
            ) : (
                <div
                    className="rounded-2xl px-5 py-10 text-center text-[13px]"
                    style={{
                        background: "rgba(26,36,25,0.04)",
                        color: "rgba(26,36,25,0.55)",
                    }}
                >
                    Log shots in Range mode to see real dispersion here.
                </div>
            )}

            {haveStats && (
                <div
                    className="grid grid-cols-3 gap-3 mt-4 rounded-xl px-4 py-3"
                    style={{ background: "rgba(26,36,25,0.04)" }}
                >
                    <DetailDelta
                        label="Carry"
                        unit={u}
                        stored={fromYards(club.carryYards, unit)}
                        measured={fromYards(
                            club.carryYards + stats.longBias,
                            unit,
                        )}
                    />
                    <DetailDelta
                        label="σ↕"
                        unit={u}
                        stored={fromYards(club.carrySd, unit)}
                        measured={fromYards(stats.carrySd, unit)}
                        ciHalfWidth={fromYards(longCi.halfWidth, unit)}
                        n={longCi.n}
                    />
                    <DetailDelta
                        label="σ↔"
                        unit={u}
                        stored={fromYards(club.lateralSd, unit)}
                        measured={fromYards(stats.lateralSd, unit)}
                        ciHalfWidth={fromYards(latCi.halfWidth, unit)}
                        n={latCi.n}
                    />
                </div>
            )}

            <ClubTrend
                club={club}
                shots={shotsQuery.data ?? []}
                unit={unit}
            />

            <OutcomeBreakdown shots={shotsQuery.data ?? []} />

            <FaceSection
                strikes={(strikesQuery.data ?? []).map((s) => ({
                    id: s.id,
                    x: s.x,
                    y: s.y,
                    note: s.note,
                    timestamp: s.timestamp,
                }))}
                onAdd={() => setAddStrikeOpen(true)}
                onDelete={(id) => setPendingDeleteStrike(id)}
            />

            <ConfirmDialog
                open={saveOpen}
                onOpenChange={setSaveOpen}
                title={`Replace ${club.name}'s σ with measured?`}
                description={`Updates carry to ${(club.carryYards + stats.longBias).toFixed(1)}y, σ↕ ${stats.carrySd.toFixed(1)}, σ↔ ${stats.lateralSd.toFixed(1)} from ${taps.length} tracked shots.`}
                confirmLabel="Update club"
                onConfirm={applyMeasured}
            />

            <AddStrikeDialog
                open={addStrikeOpen}
                onOpenChange={setAddStrikeOpen}
                onAdd={({ x, y, note }) =>
                    createStrike.mutate({
                        id: newId(),
                        clubId: club.id,
                        x,
                        y,
                        note,
                    })
                }
            />

            <ConfirmDialog
                open={!!pendingDeleteStrike}
                onOpenChange={(o) => {
                    if (!o) setPendingDeleteStrike(null);
                }}
                title="Delete this strike?"
                description="The mark and its note will be removed."
                confirmLabel="Delete"
                danger
                onConfirm={() => {
                    if (pendingDeleteStrike) {
                        deleteStrike.mutate(pendingDeleteStrike);
                        setPendingDeleteStrike(null);
                    }
                }}
            />

            {compareOpen && (
                <CompareSheet
                    base={club}
                    candidates={allClubs.data ?? []}
                    onClose={() => setCompareOpen(false)}
                />
            )}
        </div>
    );
}

function DetailStat({ label, value }: { label: string; value: string }) {
    return (
        <div>
            <div
                className="text-[10px] tracking-[0.18em] uppercase mb-1"
                style={{ color: "rgba(246,241,225,0.5)" }}
            >
                {label}
            </div>
            <div
                className="font-display tabular"
                style={{ fontSize: 28, color: "#f6f1e1" }}
            >
                {value}
            </div>
        </div>
    );
}

function DetailDelta({
    label,
    unit,
    stored,
    measured,
    ciHalfWidth,
    n,
}: {
    label: string;
    unit: string;
    stored: number;
    measured: number;
    ciHalfWidth?: number;
    n?: number;
}) {
    const delta = measured - stored;
    const sign = delta > 0 ? "+" : "";
    const color =
        Math.abs(delta) < 0.5
            ? "rgba(26,36,25,0.5)"
            : delta < 0
              ? "#2c8a5e"
              : "#c87060";
    return (
        <div>
            <div
                className="text-[10px] tracking-[0.16em] uppercase mb-1"
                style={{ color: "rgba(26,36,25,0.5)" }}
            >
                {label}
            </div>
            <div className="font-mono text-[13px]">
                {measured.toFixed(1)}
                {unit}
                {ciHalfWidth != null && ciHalfWidth > 0.05 && (
                    <span
                        className="ml-1 text-[10px]"
                        style={{ color: "rgba(26,36,25,0.5)" }}
                    >
                        ±{ciHalfWidth.toFixed(1)}
                    </span>
                )}
            </div>
            <div className="font-mono text-[10px]" style={{ color }}>
                {sign}
                {delta.toFixed(1)} vs stored
                {n != null && n > 0 && (
                    <span
                        className="ml-1"
                        style={{ color: "rgba(26,36,25,0.4)" }}
                    >
                        · n={n}
                    </span>
                )}
            </div>
        </div>
    );
}

function PencilIcon({ size = 14 }: { size?: number }) {
    return (
        <svg
            width={size}
            height={size}
            viewBox="0 0 16 16"
            fill="none"
            stroke="currentColor"
            strokeWidth="1.4"
            strokeLinecap="round"
            strokeLinejoin="round"
        >
            <path d="M11.5 2.5l2 2-8 8H3.5v-2z" />
            <path d="M9.5 4.5l2 2" />
        </svg>
    );
}

function ClubEditForm({
    initial,
    onDone,
}: {
    initial?: Club;
    onDone: () => void;
}) {
    const unit = useSettings((s) => s.unit);
    const u = unitLabel(unit);
    const create = useCreateClub();
    const update = useUpdateClub();
    const remove = useDeleteClub();

    const [name, setName] = useState(initial?.name ?? "");
    const [carry, setCarry] = useState(
        initial ? roundForUnit(fromYards(initial.carryYards, unit), unit) : 165,
    );
    const [carrySd, setCarrySd] = useState(
        initial ? roundForUnit(fromYards(initial.carrySd, unit), unit) : 6,
    );
    const [lateralSd, setLateralSd] = useState(
        initial ? roundForUnit(fromYards(initial.lateralSd, unit), unit) : 8,
    );
    const [error, setError] = useState<string | null>(null);
    const [deleteConfirm, setDeleteConfirm] = useState(false);

    function handleSave() {
        const trimmed = name.trim();
        if (!trimmed) return setError("Name is required");
        if (carry <= 0) return setError("Carry must be > 0");
        if (carrySd <= 0 || lateralSd <= 0)
            return setError("σ values must be > 0");
        setError(null);

        const patch = {
            name: trimmed,
            carryYards: toYards(carry, unit),
            carrySd: toYards(carrySd, unit),
            lateralSd: toYards(lateralSd, unit),
        };
        if (initial) {
            update.mutate(
                { id: initial.id, patch },
                { onSuccess: onDone },
            );
        } else {
            create.mutate(
                { id: newId(), ...patch },
                { onSuccess: onDone },
            );
        }
    }

    function doDelete() {
        if (!initial) return;
        setDeleteConfirm(false);
        remove.mutate(initial.id, { onSuccess: onDone });
    }

    const carryYards = toYards(carry, unit);
    const carrySdYards = toYards(carrySd, unit);
    const lateralSdYards = toYards(lateralSd, unit);
    const submitting = create.isPending || update.isPending;

    return (
        <div className="px-5 py-6 md:px-7 md:py-7 max-w-2xl mx-auto">
            <div
                className="rounded-2xl p-4 md:p-5 flex items-center gap-4 mb-5"
                style={{ background: "#0e1a13" }}
            >
                <DispersionViz
                    width={140}
                    height={170}
                    carry={carryYards}
                    carrySd={carrySdYards}
                    lateralSd={lateralSdYards}
                    distanceToTarget={carryYards}
                    showLabels={false}
                    showGrid={false}
                />
                <div className="flex-1" style={{ color: "#f6f1e1" }}>
                    <div
                        className="text-[10px] tracking-[0.2em] uppercase"
                        style={{ color: "rgba(246,241,225,0.5)" }}
                    >
                        Live preview
                    </div>
                    <div
                        className="font-display"
                        style={{ fontSize: 36, marginTop: 4 }}
                    >
                        {Math.round(carry)}
                        <span
                            style={{
                                fontSize: "0.5em",
                                color: "rgba(246,241,225,0.5)",
                            }}
                        >
                            {u}
                        </span>
                    </div>
                    <div
                        className="font-mono text-[11px] mt-2 leading-relaxed"
                        style={{ color: "rgba(246,241,225,0.6)" }}
                    >
                        ~68% within
                        <br />±{carrySd.toFixed(1)}{u} long, ±{lateralSd.toFixed(1)}{u} lateral
                    </div>
                </div>
            </div>

            <Field label="Name">
                <input
                    type="text"
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                    placeholder="7 Iron"
                    className="w-full bg-transparent outline-none"
                    style={{
                        fontFamily: "var(--font-display)",
                        fontFeatureSettings: '"tnum"',
                        fontSize: 16,
                        color: "#1a2419",
                    }}
                />
            </Field>

            <Field label="Carry distance" suffix={u}>
                <NumberInput value={carry} onChange={setCarry} />
            </Field>

            <Field
                label="Distance σ (carry)"
                suffix={u}
                hint="Standard deviation. ~68% of shots land within ±σ of expected carry."
            >
                <NumberInput value={carrySd} onChange={setCarrySd} step={0.5} />
            </Field>

            <Field
                label="Lateral σ"
                suffix={u}
                hint="Standard deviation perpendicular to target line."
            >
                <NumberInput
                    value={lateralSd}
                    onChange={setLateralSd}
                    step={0.5}
                />
            </Field>

            {error && (
                <div className="mt-3 text-[12px]" style={{ color: "#a23939" }}>
                    {error}
                </div>
            )}

            <div className="flex gap-2.5 mt-7">
                <button
                    onClick={handleSave}
                    disabled={submitting}
                    className="flex-1 py-3.5 rounded-[10px] text-[14px] font-semibold disabled:opacity-50"
                    style={{ background: "#1a2419", color: "#f4efe3" }}
                >
                    {initial ? "Save changes" : "Add to bag"}
                </button>
                {initial && (
                    <button
                        onClick={() => setDeleteConfirm(true)}
                        className="px-4 py-3.5 rounded-[10px] text-[14px]"
                        style={{
                            background: "transparent",
                            border: "1px solid rgba(162,57,57,0.3)",
                            color: "#a23939",
                        }}
                    >
                        Delete
                    </button>
                )}
            </div>

            {initial && (
                <ConfirmDialog
                    open={deleteConfirm}
                    onOpenChange={setDeleteConfirm}
                    title={`Delete ${initial.name}?`}
                    description="Removes this club from your bag. Logged shots remain in the shot history."
                    confirmLabel="Delete"
                    danger
                    onConfirm={doDelete}
                />
            )}
        </div>
    );
}

function Field({
    label,
    suffix,
    hint,
    children,
}: {
    label: string;
    suffix?: string;
    hint?: string;
    children: React.ReactNode;
}) {
    return (
        <div className="mb-4">
            <label
                className="block text-[11px] tracking-[0.16em] uppercase mb-1.5"
                style={{ color: "rgba(26,36,25,0.55)" }}
            >
                {label}
            </label>
            <div
                className="flex items-center bg-white rounded-[10px] px-3.5 py-3"
                style={{ border: "1px solid rgba(26,36,25,0.12)" }}
            >
                <div className="flex-1">{children}</div>
                {suffix && (
                    <span
                        className="font-mono text-[12px]"
                        style={{ color: "rgba(26,36,25,0.5)" }}
                    >
                        {suffix}
                    </span>
                )}
            </div>
            {hint && (
                <div
                    className="text-[11px] mt-1.5 leading-snug"
                    style={{ color: "rgba(26,36,25,0.5)" }}
                >
                    {hint}
                </div>
            )}
        </div>
    );
}

function NumberInput({
    value,
    onChange,
    step = 1,
}: {
    value: number;
    onChange: (n: number) => void;
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
            className="w-full bg-transparent outline-none"
            style={{
                fontFamily: "var(--font-display)",
                fontFeatureSettings: '"tnum"',
                fontSize: 16,
                color: "#1a2419",
            }}
        />
    );
}

function ClubsEmptyState({ onAddManual }: { onAddManual: () => void }) {
    const navigate = useNavigate();
    const qc = useQueryClient();
    const [seedConfirm, setSeedConfirm] = useState(false);
    const [busy, setBusy] = useState(false);

    async function doSeed() {
        setSeedConfirm(false);
        setBusy(true);
        try {
            for (const c of SAMPLE_BAG) {
                await createClub({ id: newId(), ...c });
            }
            await qc.invalidateQueries({ queryKey: ["clubs"] });
        } finally {
            setBusy(false);
        }
    }

    return (
        <div
            className="relative flex flex-col items-center justify-center min-h-full px-6 py-12 text-center overflow-hidden"
            style={{ color: "#1a2419" }}
        >
            <div
                className="absolute inset-0 opacity-30 pointer-events-none"
                aria-hidden
            >
                <TopoBg
                    width={520}
                    height={520}
                    seed={3}
                    color="rgba(26,36,25,0.18)"
                    accent="rgba(232,93,77,0.25)"
                />
            </div>
            <div className="relative z-10 max-w-md w-full">
                <div
                    className="text-[10px] tracking-[0.24em] uppercase mb-3"
                    style={{ color: "#2c8a5e" }}
                >
                    ◆ Empty bag
                </div>
                <h2
                    className="font-display"
                    style={{
                        fontSize: "clamp(36px, 7vw, 48px)",
                        lineHeight: 1.05,
                        letterSpacing: "-0.02em",
                    }}
                >
                    Tell us what's in your bag.
                </h2>
                <p
                    className="text-[14px] mt-3 leading-relaxed"
                    style={{ color: "rgba(26,36,25,0.65)" }}
                >
                    The math needs at least one club. Walk through a quick
                    setup, drop in a sample bag, or build it yourself.
                </p>

                <div className="mt-7 grid gap-2.5">
                    <button
                        onClick={() =>
                            navigate({
                                to: "/onboarding",
                                search: { step: 1 } as never,
                            })
                        }
                        className="w-full px-5 py-3.5 rounded-[12px] flex items-center justify-between text-left"
                        style={{
                            background: "#1a2419",
                            color: "#f4efe3",
                        }}
                    >
                        <span>
                            <div
                                className="text-[10px] tracking-[0.18em] uppercase"
                                style={{ color: "rgba(244,239,227,0.55)" }}
                            >
                                Recommended
                            </div>
                            <div className="text-[15px] font-medium mt-0.5">
                                Take the tour
                            </div>
                        </span>
                        <Icon.ChevronRight
                            size={14}
                            color="rgba(244,239,227,0.55)"
                        />
                    </button>
                    <button
                        onClick={() => setSeedConfirm(true)}
                        disabled={busy}
                        className="w-full px-5 py-3.5 rounded-[12px] flex items-center justify-between text-left disabled:opacity-50"
                        style={{
                            background: "#fff",
                            border: "1px solid rgba(26,36,25,0.12)",
                            color: "#1a2419",
                        }}
                    >
                        <span>
                            <div
                                className="text-[10px] tracking-[0.18em] uppercase"
                                style={{ color: "rgba(26,36,25,0.5)" }}
                            >
                                Quick start
                            </div>
                            <div className="text-[15px] font-medium mt-0.5">
                                Use sample bag
                            </div>
                            <div
                                className="text-[11px] font-mono mt-0.5"
                                style={{ color: "rgba(26,36,25,0.5)" }}
                            >
                                13 clubs · single-digit dispersion
                            </div>
                        </span>
                        <Icon.ChevronRight
                            size={14}
                            color="rgba(26,36,25,0.4)"
                        />
                    </button>
                    <button
                        onClick={onAddManual}
                        className="w-full px-5 py-3.5 rounded-[12px] flex items-center justify-between text-left"
                        style={{
                            background: "transparent",
                            border: "1px solid rgba(26,36,25,0.12)",
                            color: "#1a2419",
                        }}
                    >
                        <span>
                            <div
                                className="text-[10px] tracking-[0.18em] uppercase"
                                style={{ color: "rgba(26,36,25,0.5)" }}
                            >
                                Manual
                            </div>
                            <div className="text-[15px] font-medium mt-0.5">
                                Add a club yourself
                            </div>
                        </span>
                        <Icon.ChevronRight
                            size={14}
                            color="rgba(26,36,25,0.4)"
                        />
                    </button>
                </div>
            </div>

            <ConfirmDialog
                open={seedConfirm}
                onOpenChange={setSeedConfirm}
                title="Seed your bag with 13 sample clubs?"
                description="A standard set from Driver to Lob Wedge with realistic single-digit-handicap dispersion. You can edit each one afterward."
                confirmLabel="Seed bag"
                onConfirm={doSeed}
            />
        </div>
    );
}

function BagHero({
    clubs,
    unit,
    unitLabel: u,
}: {
    clubs: Club[];
    unit: "yards" | "meters";
    unitLabel: string;
}) {
    if (clubs.length === 0) return null;
    const carries = clubs.map((c) => fromYards(c.carryYards, unit));
    const sds = clubs.map((c) => fromYards(c.carrySd, unit));
    const minCarry = Math.min(...carries);
    const maxCarry = Math.max(...carries);
    const avgSd =
        sds.reduce((s, v) => s + v, 0) / Math.max(sds.length, 1);
    const tightest = Math.min(...sds);

    // gap-rendered axis: each tick a club position
    const sortedCarries = [...carries].sort((a, b) => a - b);
    const range = Math.max(maxCarry - minCarry, 1);

    return (
        <div className="px-[18px] pt-3 md:px-7">
            <motion.div
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{
                    type: "spring",
                    stiffness: 220,
                    damping: 28,
                }}
                className="relative overflow-hidden rounded-3xl p-5 md:p-6"
                style={{
                    background:
                        "radial-gradient(140% 100% at 100% 0%, rgba(98,179,117,0.32) 0%, rgba(98,179,117,0) 55%), linear-gradient(160deg, #0b3d2e 0%, #070d0a 100%)",
                    color: "#f6f1e1",
                    boxShadow:
                        "0 18px 38px rgba(7,13,10,0.45), 0 4px 12px rgba(0,0,0,0.20)",
                }}
            >
                {/* Editorial top row: eyebrow + count */}
                <div className="relative flex items-start justify-between gap-3">
                    <div>
                        <div
                            className="font-mono"
                            style={{
                                fontSize: 10,
                                letterSpacing: "0.24em",
                                textTransform: "uppercase",
                                color: "#a9d18e",
                            }}
                        >
                            Bag overview
                        </div>
                        <div
                            className="font-display tabular leading-none mt-1.5"
                            style={{
                                fontSize: "clamp(56px, 13vw, 84px)",
                                letterSpacing: "-0.035em",
                            }}
                        >
                            {clubs.length}
                            <span
                                className="ml-2"
                                style={{
                                    fontSize: "0.26em",
                                    color: "rgba(246,241,225,0.55)",
                                    letterSpacing: "0",
                                }}
                            >
                                clubs
                            </span>
                        </div>
                    </div>
                    <div className="text-right pt-1">
                        <div
                            className="font-mono"
                            style={{
                                fontSize: 9,
                                letterSpacing: "0.22em",
                                textTransform: "uppercase",
                                color: "rgba(246,241,225,0.5)",
                            }}
                        >
                            Carry range
                        </div>
                        <div className="font-mono tabular mt-1 text-[13px]">
                            {Math.round(minCarry)}–{Math.round(maxCarry)}
                            <span className="ml-1 opacity-50">{u}</span>
                        </div>
                    </div>
                </div>

                {/* Tick rule — visualizes spacing of carries */}
                <div className="relative mt-5">
                    <div
                        className="relative h-[34px] rounded-full overflow-hidden"
                        style={{ background: "rgba(246,241,225,0.06)" }}
                    >
                        <div
                            className="absolute inset-y-0 left-0"
                            style={{
                                width: "100%",
                                background:
                                    "linear-gradient(90deg, rgba(98,179,117,0) 0%, rgba(98,179,117,0.16) 50%, rgba(98,179,117,0) 100%)",
                            }}
                        />
                        {sortedCarries.map((c, i) => {
                            const pct = ((c - minCarry) / range) * 100;
                            return (
                                <div
                                    key={i}
                                    className="absolute top-1/2 -translate-y-1/2"
                                    style={{
                                        left: `calc(${pct}% - 0.5px)`,
                                        width: 1,
                                        height: 16,
                                        background:
                                            "rgba(246,241,225,0.55)",
                                    }}
                                />
                            );
                        })}
                        <div
                            className="absolute left-2 inset-y-0 flex items-center font-mono tabular text-[10px]"
                            style={{ color: "rgba(246,241,225,0.55)" }}
                        >
                            {Math.round(minCarry)}
                        </div>
                        <div
                            className="absolute right-2 inset-y-0 flex items-center font-mono tabular text-[10px]"
                            style={{ color: "rgba(246,241,225,0.55)" }}
                        >
                            {Math.round(maxCarry)}
                        </div>
                    </div>
                </div>

                {/* Stats row */}
                <div
                    className="relative mt-5 grid grid-cols-2 gap-x-5 pt-4"
                    style={{
                        borderTop: "1px solid rgba(246,241,225,0.12)",
                    }}
                >
                    <HeroStat
                        label="Avg σ↕"
                        value={avgSd.toFixed(1)}
                        suffix={u}
                    />
                    <HeroStat
                        label="Tightest"
                        value={tightest.toFixed(1)}
                        suffix={u}
                    />
                </div>
            </motion.div>
        </div>
    );
}

function HeroStat({
    label,
    value,
    suffix,
}: {
    label: string;
    value: string;
    suffix?: string;
}) {
    return (
        <div>
            <div
                className="font-mono"
                style={{
                    fontSize: 9,
                    letterSpacing: "0.22em",
                    textTransform: "uppercase",
                    color: "rgba(246,241,225,0.5)",
                }}
            >
                {label}
            </div>
            <div
                className="font-display tabular mt-1"
                style={{
                    fontSize: 24,
                    color: "#f6f1e1",
                    letterSpacing: "-0.015em",
                }}
            >
                {value}
                {suffix && (
                    <span
                        className="ml-1 text-[10px]"
                        style={{ color: "rgba(246,241,225,0.55)" }}
                    >
                        {suffix}
                    </span>
                )}
            </div>
        </div>
    );
}

const ClubCardRow = memo(function ClubCardRow({
    club,
    unit,
    unitLabel: u,
    onOpen,
    onEdit,
    index,
}: {
    club: Club;
    unit: "yards" | "meters";
    unitLabel: string;
    onOpen: (c: Club) => void;
    onEdit: (c: Club) => void;
    index: number;
}) {
    const cat = categorize(club.name, club.carryYards);
    const style = styleOf(cat);
    const carry = Math.round(fromYards(club.carryYards, unit));
    return (
        <div
            className="card-stagger-in group relative overflow-hidden rounded-2xl bg-white transition-shadow hover:shadow-md"
            style={{
                border: "1px solid rgba(26,36,25,0.07)",
                boxShadow: "0 1px 2px rgba(0,0,0,0.04)",
                animationDelay: `${Math.min(index * 28, 280)}ms`,
            }}
        >
            <div
                className="absolute left-0 top-0 bottom-0"
                style={{
                    width: 4,
                    background: style.gradient,
                }}
                aria-hidden
            />
            <div
                className="grid items-center gap-3 pl-5 pr-2 py-3.5"
                style={{ gridTemplateColumns: "1fr auto auto auto" }}
            >
                <button onClick={() => onOpen(club)} className="text-left">
                    <div className="flex items-center gap-2">
                        <span className="text-[16px] font-medium leading-tight">
                            {club.name}
                        </span>
                        <span
                            className="font-mono text-[9px] tracking-[0.18em] uppercase px-1.5 py-0.5 rounded-full"
                            style={{
                                background: `${style.accent}22`,
                                color: style.accentDeep,
                            }}
                        >
                            {style.label}
                        </span>
                    </div>
                    <div
                        className="font-mono text-[11px] mt-1 tabular"
                        style={{ color: "rgba(26,36,25,0.55)" }}
                    >
                        σ↕ {fromYards(club.carrySd, unit).toFixed(1)} · σ↔{" "}
                        {fromYards(club.lateralSd, unit).toFixed(1)} {u}
                    </div>
                </button>
                <DispersionGlyph
                    carrySd={club.carrySd}
                    lateralSd={club.lateralSd}
                    fill={style.accent}
                    stroke={style.accentDeep}
                />
                <button
                    onClick={() => onOpen(club)}
                    className="font-display tabular text-right pr-1"
                    style={{
                        fontSize: 30,
                        letterSpacing: "-0.025em",
                        minWidth: 76,
                    }}
                >
                    {carry}
                    <span
                        className="ml-0.5"
                        style={{
                            fontSize: "0.4em",
                            color: "rgba(26,36,25,0.5)",
                        }}
                    >
                        {u}
                    </span>
                </button>
                <button
                    onClick={() => onEdit(club)}
                    aria-label={`Edit ${club.name}`}
                    className="p-3 rounded-full transition-colors hover:bg-[rgba(26,36,25,0.06)] opacity-50 group-hover:opacity-100 focus-visible:opacity-100"
                    style={{ color: "rgba(26,36,25,0.55)" }}
                >
                    <PencilIcon size={16} />
                </button>
            </div>
        </div>
    );
});

function BagAnalysis({
    clubs,
    onOpen,
}: {
    clubs: Club[];
    onOpen: (c: Club) => void;
}) {
    const unit = useSettings((s) => s.unit);
    const allShots = useAllShots();
    const insights = useMemo(
        () => computeInsights(clubs, allShots.data ?? []),
        [clubs, allShots.data],
    );
    const [collapsed, setCollapsed] = useState(false);

    if (clubs.length < 2) return null;

    return (
        <div className="px-[18px] pt-3 pb-1 md:px-7">
            {insights.length > 0 && (
                <div className="space-y-2 mb-3">
                    {insights.map((ins) => (
                        <InsightCard
                            key={ins.id}
                            insight={ins}
                            onOpen={() => {
                                const c = clubs.find(
                                    (x) => x.id === ins.action?.clubId,
                                );
                                if (c) onOpen(c);
                            }}
                        />
                    ))}
                </div>
            )}

            <button
                onClick={() => setCollapsed((v) => !v)}
                className="w-full flex items-center justify-between text-[10px] tracking-[0.2em] uppercase mb-2"
                style={{ color: "rgba(26,36,25,0.55)" }}
            >
                <span>Bag gapping</span>
                <span className="font-mono normal-case tracking-normal text-[11px]">
                    {collapsed ? "show" : "hide"}
                </span>
            </button>
            {!collapsed && (
                <div
                    className="rounded-2xl bg-white p-2"
                    style={{ border: "1px solid rgba(26,36,25,0.08)" }}
                >
                    <BagGappingChart clubs={clubs} unit={unit} />
                </div>
            )}
        </div>
    );
}

function InsightCard({
    insight,
    onOpen,
}: {
    insight: ReturnType<typeof computeInsights>[number];
    onOpen: () => void;
}) {
    const tone =
        insight.severity === "good"
            ? {
                  bg: "rgba(98,179,117,0.12)",
                  border: "rgba(98,179,117,0.45)",
                  pin: "#2c8a5e",
              }
            : insight.severity === "warn"
              ? {
                    bg: "rgba(232,93,77,0.10)",
                    border: "rgba(232,93,77,0.45)",
                    pin: "#e85d4d",
                }
              : {
                    bg: "rgba(26,36,25,0.04)",
                    border: "rgba(26,36,25,0.12)",
                    pin: "rgba(26,36,25,0.6)",
                };
    return (
        <button
            onClick={onOpen}
            className="w-full flex items-start gap-3 px-4 py-3 rounded-2xl text-left"
            style={{
                background: tone.bg,
                border: `1px solid ${tone.border}`,
                color: "#1a2419",
            }}
        >
            <span
                className="rounded-full mt-1 shrink-0"
                style={{
                    width: 8,
                    height: 8,
                    background: tone.pin,
                }}
            />
            <span className="flex-1 min-w-0">
                <div className="text-[13px] font-medium">
                    {insight.title}
                </div>
                <div
                    className="text-[12px] mt-0.5 leading-snug"
                    style={{ color: "rgba(26,36,25,0.65)" }}
                >
                    {insight.body}
                </div>
            </span>
        </button>
    );
}

function ClubTrend({
    club,
    shots,
    unit,
}: {
    club: Club;
    shots: ReadonlyArray<{
        sessionId: string;
        clubId: string;
        longDelta: number;
        latDelta: number;
        timestamp: Date;
        outcome: string | null;
        targetDistanceYards: number;
        id: string;
    }>;
    unit: "yards" | "meters";
}) {
    const summary = summarizeShots(shots as never);
    if (!summary || summary.sessionPoints.length < 2) return null;
    const points = summary.sessionPoints.map((p) => ({
        date: p.date,
        value: fromYards(p.carrySd, unit),
    }));
    const u = unitLabel(unit);
    const stored = fromYards(club.carrySd, unit);
    const latest = points[points.length - 1]!.value;
    const first = points[0]!.value;
    const delta = latest - first;
    const trend =
        Math.abs(delta) < 0.3
            ? "Steady"
            : delta < 0
              ? `↓ ${Math.abs(delta).toFixed(1)}${u} tighter`
              : `↑ ${delta.toFixed(1)}${u} looser`;
    const trendColor =
        Math.abs(delta) < 0.3
            ? "rgba(26,36,25,0.55)"
            : delta < 0
              ? "#2c8a5e"
              : "#c87060";
    return (
        <div className="mt-5">
            <div className="flex items-baseline justify-between mb-2">
                <div
                    className="text-[10px] tracking-[0.2em] uppercase"
                    style={{ color: "rgba(26,36,25,0.5)" }}
                >
                    σ↕ trend · {summary.sessionPoints.length} sessions
                </div>
                <div
                    className="font-mono text-[11px]"
                    style={{ color: trendColor }}
                >
                    {trend}
                </div>
            </div>
            <div
                className="rounded-2xl bg-white p-3 pr-4"
                style={{ border: "1px solid rgba(26,36,25,0.08)" }}
            >
                <TrendChart
                    points={points}
                    suffix={u}
                    referenceValue={stored}
                    referenceLabel={`stored ${stored.toFixed(1)}${u}`}
                />
            </div>
        </div>
    );
}

function OutcomeBreakdown({
    shots,
}: {
    shots: ReadonlyArray<{ outcome: string | null }>;
}) {
    if (shots.length === 0) return null;
    const counts: Record<string, number> = {
        in: 0,
        short: 0,
        long: 0,
        left: 0,
        right: 0,
        penalty: 0,
    };
    let tagged = 0;
    for (const s of shots) {
        const tags = decodeOutcome(s.outcome);
        if (tags.length > 0) tagged++;
        for (const t of tags) {
            if (counts[t] !== undefined) counts[t] += 1;
        }
    }
    if (tagged === 0) return null;

    const order: Array<{
        id: keyof typeof counts;
        label: string;
        color: string;
    }> = [
        { id: "in", label: "In zone", color: "#62b375" },
        { id: "short", label: "Short", color: "#e6c068" },
        { id: "long", label: "Long", color: "#e6c068" },
        { id: "left", label: "Left", color: "#c87060" },
        { id: "right", label: "Right", color: "#c87060" },
        { id: "penalty", label: "Penalty", color: "#a23939" },
    ];

    return (
        <div className="mt-5">
            <div
                className="text-[10px] tracking-[0.2em] uppercase mb-2"
                style={{ color: "rgba(26,36,25,0.5)" }}
            >
                Outcome mix · {tagged} tagged
            </div>
            <div className="grid grid-cols-3 gap-2">
                {order.map((o) => {
                    const n = counts[o.id] ?? 0;
                    const pct =
                        tagged > 0 ? Math.round((n / tagged) * 100) : 0;
                    return (
                        <div
                            key={o.id}
                            className="rounded-lg px-3 py-2"
                            style={{
                                background: "rgba(26,36,25,0.04)",
                            }}
                        >
                            <div
                                className="text-[10px] tracking-[0.16em] uppercase mb-1"
                                style={{ color: "rgba(26,36,25,0.55)" }}
                            >
                                {o.label}
                            </div>
                            <div className="flex items-baseline gap-1.5">
                                <span
                                    className="font-display tabular"
                                    style={{ fontSize: 22, color: o.color }}
                                >
                                    {pct}
                                </span>
                                <span
                                    className="font-mono text-[10px]"
                                    style={{ color: "rgba(26,36,25,0.5)" }}
                                >
                                    % · {n}
                                </span>
                            </div>
                        </div>
                    );
                })}
            </div>
        </div>
    );
}

type StrikeView = {
    id: string;
    x: number;
    y: number;
    note: string;
    timestamp: Date;
};

function FaceSection({
    strikes,
    onAdd,
    onDelete,
}: {
    strikes: StrikeView[];
    onAdd: () => void;
    onDelete: (id: string) => void;
}) {
    const [selected, setSelected] = useState<string | null>(null);
    const selectedStrike = strikes.find((s) => s.id === selected) ?? null;
    return (
        <div className="mt-6">
            <div className="flex items-center justify-between mb-2">
                <div>
                    <div
                        className="text-[10px] tracking-[0.2em] uppercase"
                        style={{ color: "rgba(26,36,25,0.5)" }}
                    >
                        Face strikes
                    </div>
                    <div
                        className="font-mono text-[12px] mt-0.5"
                        style={{ color: "rgba(26,36,25,0.6)" }}
                    >
                        {strikes.length} marked
                    </div>
                </div>
                <button
                    onClick={onAdd}
                    className="px-3 py-1.5 rounded-full text-[12px]"
                    style={{
                        background: "#1a2419",
                        color: "#f4efe3",
                    }}
                >
                    + Add strike
                </button>
            </div>

            <div
                className="rounded-2xl overflow-hidden"
                style={{
                    aspectRatio: "1.5",
                    background: "#0e1a13",
                }}
            >
                <ClubFaceViz
                    strikes={strikes.map((s) => ({
                        id: s.id,
                        x: s.x,
                        y: s.y,
                    }))}
                    selectedId={selected}
                    onSelect={(id) =>
                        setSelected((prev) => (prev === id ? null : id))
                    }
                />
            </div>

            {selectedStrike && (
                <div
                    className="rounded-xl p-3.5 mt-3 flex items-start justify-between gap-3"
                    style={{
                        background: "rgba(26,36,25,0.04)",
                    }}
                >
                    <div className="min-w-0">
                        <div
                            className="text-[10px] tracking-[0.18em] uppercase mb-1"
                            style={{ color: "rgba(26,36,25,0.55)" }}
                        >
                            {describeFace(selectedStrike)}
                        </div>
                        <div className="text-[13px]">
                            {selectedStrike.note || "(no note)"}
                        </div>
                        <div
                            className="font-mono text-[10px] mt-1"
                            style={{ color: "rgba(26,36,25,0.5)" }}
                        >
                            {selectedStrike.timestamp.toLocaleString([], {
                                month: "short",
                                day: "numeric",
                                hour: "numeric",
                                minute: "2-digit",
                            })}
                        </div>
                    </div>
                    <button
                        onClick={() => {
                            onDelete(selectedStrike.id);
                            setSelected(null);
                        }}
                        className="text-[12px] shrink-0"
                        style={{ color: "#a23939" }}
                    >
                        Delete
                    </button>
                </div>
            )}

            {strikes.length === 0 && (
                <div
                    className="text-[12px] mt-3 text-center"
                    style={{ color: "rgba(26,36,25,0.55)" }}
                >
                    No strikes yet. Tap “+ Add strike” after a session to
                    capture impact location and any swing thoughts.
                </div>
            )}
        </div>
    );
}
