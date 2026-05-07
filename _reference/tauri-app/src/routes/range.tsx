import { useEffect, useMemo, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { createFileRoute } from "@tanstack/react-router";
import { useQueryClient } from "@tanstack/react-query";
import {
    PencilIcon,
    SaveIcon,
    StopCircleIcon,
    SwitchCameraIcon,
    TargetIcon,
    Undo2Icon,
} from "lucide-react";
import {
    useClubs,
    useCreateSession,
    useCreateShot,
    useUpdateClub,
} from "@/lib/queries";
import { newId } from "@/lib/id";
import { dispersionFromShots, type ShotXY } from "@/lib/sigma";
import { RangeRadarField } from "@/components/range/RangeRadarField";
import {
    Sheet,
    SheetContent,
    SheetHeader,
    SheetTitle,
} from "@/components/ui/sheet";
import { Slider } from "@/components/ui/slider";
import { Button } from "@/components/ui/button";
import { ConfirmDialog } from "@/components/ConfirmDialog";
import { ShotLogContent } from "@/components/range/ShotLogContent";
import { AddShotDialog } from "@/components/range/AddShotDialog";
import { SessionDetail } from "@/components/range/SessionDetail";
import { useActiveSession } from "@/lib/sessionStore";
import { useDial, type DialAction } from "@/lib/dialStore";
import { describeDbError } from "@/lib/dbErrors";
import { notify } from "@/lib/haptics";
import { cn } from "@/lib/cn";
import type { Club, ShotOutcomeTag } from "@/types";

export const Route = createFileRoute("/range")({
    component: RangeRoot,
});

function RangeRoot() {
    const [tab, setTab] = useState<"live" | "log">("live");
    const [openSessionId, setOpenSessionId] = useState<string | null>(null);
    const showLog = tab === "log" && !openSessionId;
    const showDetail = tab === "log" && !!openSessionId;
    return (
        <div
            className="flex-1 min-h-0 overflow-hidden flex flex-col"
            style={{
                background: tab === "live" ? "#0a1410" : "#f4efe3",
                color: tab === "live" ? "#f6f1e1" : "#1a2419",
            }}
        >
            {!showDetail && (
                <RangeHeaderTabs
                    tab={tab}
                    setTab={(t) => {
                        setTab(t);
                        setOpenSessionId(null);
                    }}
                />
            )}
            <div className="flex-1 min-h-0 flex flex-col overflow-hidden">
                {tab === "live" && <LiveRange />}
                {showLog && (
                    <ShotLogContent
                        onOpenSession={(id) => setOpenSessionId(id)}
                    />
                )}
                {showDetail && openSessionId && (
                    <SessionDetail
                        sessionId={openSessionId}
                        onBack={() => setOpenSessionId(null)}
                    />
                )}
            </div>
        </div>
    );
}

function RangeHeaderTabs({
    tab,
    setTab,
}: {
    tab: "live" | "log";
    setTab: (t: "live" | "log") => void;
}) {
    const live = tab === "live";
    const bgBorder = live
        ? "1px solid rgba(246,241,225,0.06)"
        : "1px solid rgba(26,36,25,0.08)";
    const eyebrowColor = live ? "#a9d18e" : "rgba(26,36,25,0.5)";
    return (
        <div
            className="screen-header flex items-center justify-between px-[18px] pb-3 md:px-7 md:pb-3.5"
            style={{ borderBottom: bgBorder }}
        >
            <div>
                <div
                    className="flex items-center gap-1.5 text-[10px] tracking-[0.22em] uppercase"
                    style={{ color: eyebrowColor }}
                >
                    {live && (
                        <span
                            className="w-1.5 h-1.5 rounded-full"
                            style={{ background: "#a9d18e" }}
                        />
                    )}
                    {live ? "Range mode" : "Shot log"}
                </div>
                <div
                    className="font-display"
                    style={{
                        fontSize: "clamp(26px, 5vw, 36px)",
                        marginTop: 2,
                        letterSpacing: "-0.02em",
                    }}
                >
                    {live ? "Practice" : "History"}
                </div>
            </div>
            <div className="flex gap-1">
                <TabBtn active={tab === "live"} onClick={() => setTab("live")} variant={live ? "dark" : "light"}>
                    Live
                </TabBtn>
                <TabBtn active={tab === "log"} onClick={() => setTab("log")} variant={live ? "dark" : "light"}>
                    History
                </TabBtn>
            </div>
        </div>
    );
}

function TabBtn({
    active,
    onClick,
    variant,
    children,
}: {
    active: boolean;
    onClick: () => void;
    variant: "dark" | "light";
    children: React.ReactNode;
}) {
    const inactiveColor =
        variant === "dark" ? "rgba(246,241,225,0.55)" : "rgba(26,36,25,0.55)";
    const inactiveBg =
        variant === "dark" ? "rgba(246,241,225,0.04)" : "rgba(26,36,25,0.04)";
    return (
        <button
            onClick={onClick}
            className="relative px-4 py-2 rounded-full text-[13px] font-medium transition-colors"
            style={{
                background: active ? "transparent" : inactiveBg,
                color: active ? "#0a1410" : inactiveColor,
            }}
        >
            {active && (
                <motion.span
                    layoutId="rangeTabIndicator"
                    className="absolute inset-0 rounded-full bg-primary shadow-sm"
                    transition={{
                        type: "spring",
                        stiffness: 380,
                        damping: 32,
                    }}
                />
            )}
            <span className="relative z-10">{children}</span>
        </button>
    );
}

function LiveRange() {
    const clubs = useClubs();
    const createSession = useCreateSession();
    const createShot = useCreateShot();
    const updateClub = useUpdateClub();
    const qc = useQueryClient();
    const activeSession = useActiveSession((s) => s.active);
    const setActiveSession = useActiveSession((s) => s.setActive);
    const clearActiveSession = useActiveSession((s) => s.clearActive);

    const [selectedClubId, setSelectedClubId] = useState<string | null>(null);
    const [taps, setTaps] = useState<ShotXY[]>([]);
    const [showSwitch, setShowSwitch] = useState(false);
    const [showTarget, setShowTarget] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [targetYards, setTargetYards] = useState<number | null>(null);
    const [endConfirm, setEndConfirm] = useState(false);
    const [saveConfirm, setSaveConfirm] = useState(false);
    const [addOpen, setAddOpen] = useState(false);

    function undoLast() {
        setTaps((prev) => prev.slice(0, -1));
    }

    const sessionId =
        activeSession && activeSession.kind === "range"
            ? activeSession.id
            : null;

    const club = useMemo(
        () =>
            (clubs.data ?? []).find((c) => c.id === selectedClubId) ??
            (clubs.data?.[0] ?? null),
        [clubs.data, selectedClubId],
    );

    const stats = useMemo(() => dispersionFromShots(taps), [taps]);
    const effectiveTarget = targetYards ?? club?.carryYards ?? 150;

    async function ensureSession(): Promise<string> {
        if (sessionId) return sessionId;
        const id = newId();
        const label = "Range session";
        await createSession.mutateAsync({ id, kind: "range", label });
        setActiveSession({ id, kind: "range", label });
        return id;
    }

    function confirmEndSession() {
        clearActiveSession();
        setTaps([]);
        setEndConfirm(false);
    }

    async function handleTap(p: ShotXY & { outcomes?: ShotOutcomeTag[] }) {
        if (!club) return;
        setError(null);
        try {
            const sid = await ensureSession();
            setTaps((prev) => [...prev, { lat: p.lat, long: p.long }]);
            await createShot.mutateAsync({
                id: newId(),
                sessionId: sid,
                clubId: club.id,
                targetDistanceYards: effectiveTarget,
                longDelta: p.long,
                latDelta: p.lat,
                outcomes: p.outcomes,
            });
            void notify("success");
        } catch (e) {
            setTaps((prev) => prev.slice(0, -1));
            void notify("error");
            setError(describeDbError(e));
        }
    }

    async function confirmSaveToClub() {
        if (!club || taps.length < 2) return;
        await updateClub.mutateAsync({
            id: club.id,
            patch: {
                name: club.name,
                carryYards: club.carryYards + stats.longBias,
                carrySd: stats.carrySd,
                lateralSd: stats.lateralSd,
            },
        });
        await qc.invalidateQueries({ queryKey: ["clubs"] });
        setSaveConfirm(false);
    }

    if ((clubs.data ?? []).length === 0) {
        return (
            <div className="flex-1 flex items-center justify-center px-6 text-center"
                style={{ color: "rgba(246,241,225,0.6)" }}>
                <div>
                    <div className="font-display text-2xl mb-2" style={{ color: "#f6f1e1" }}>
                        Add a club first
                    </div>
                    <div className="text-[13px]">
                        Range mode logs shots against a club's expected carry.
                    </div>
                </div>
            </div>
        );
    }

    const setDialActions = useDial((s) => s.setActions);

    useEffect(() => {
        const actions: DialAction[] = [
            {
                id: "switch",
                label: "Club",
                icon: <SwitchCameraIcon className="size-5" />,
                onClick: () => setShowSwitch(true),
            },
            {
                id: "target",
                label: "Target",
                icon: <TargetIcon className="size-5" />,
                onClick: () => setShowTarget(true),
            },
            {
                id: "manual",
                label: "Manual",
                icon: <PencilIcon className="size-5" />,
                onClick: () => setAddOpen(true),
            },
            {
                id: "undo",
                label: "Undo",
                icon: <Undo2Icon className="size-5" />,
                onClick: undoLast,
                disabled: taps.length === 0,
            },
            {
                id: "save",
                label: "Calibrate",
                icon: <SaveIcon className="size-5" />,
                tone: "primary",
                onClick: () => setSaveConfirm(true),
                disabled: taps.length < 2 || !club,
            },
            {
                id: "end",
                label: "End",
                icon: <StopCircleIcon className="size-5" />,
                tone: "danger",
                onClick: () => setEndConfirm(true),
                disabled: !sessionId,
            },
        ];
        setDialActions(actions);
        return () => setDialActions([]);
    }, [setDialActions, taps.length, club, sessionId]);

    return (
        <>
            <div className="relative flex-1 min-h-0 overflow-hidden bg-[#070d0a]">
                {/* Floating session card — top left */}
                {club && (
                    <SessionCard
                        clubName={club.name}
                        targetYards={effectiveTarget}
                        sessionActive={!!sessionId}
                        shotCount={taps.length}
                    />
                )}

                {/* Floating live stats — top right */}
                {club && taps.length >= 2 && (
                    <LiveStatsCard
                        stats={stats}
                        club={club}
                        shots={taps.length}
                    />
                )}

                {/* Polar radar field */}
                {club && (
                    <div className="absolute inset-0">
                        <RangeRadarField
                            targetYards={effectiveTarget}
                            referenceCarrySd={club.carrySd}
                            referenceLateralSd={club.lateralSd}
                            carrySd={stats.carrySd}
                            lateralSd={stats.lateralSd}
                            longBias={stats.longBias}
                            latBias={stats.latBias}
                            shots={taps}
                            onTap={handleTap}
                            width={520}
                            height={760}
                        />
                    </div>
                )}

                <AnimatePresence>
                    {error && (
                        <motion.div
                            key="err"
                            initial={{ opacity: 0, y: -6 }}
                            animate={{ opacity: 1, y: 0 }}
                            exit={{ opacity: 0 }}
                            className="absolute left-3 right-3 top-3 z-10 rounded-xl border border-destructive/45 bg-destructive/15 px-3 py-2 text-[12px] text-foreground"
                        >
                            Failed to log shot: {error}
                        </motion.div>
                    )}
                </AnimatePresence>

                {/* Radial dial is mounted in __root so it persists across routes */}
            </div>

            <SwitchClubSheet
                open={showSwitch}
                onOpenChange={setShowSwitch}
                clubs={clubs.data ?? []}
                activeId={club?.id ?? null}
                onPick={(id) => {
                    setSelectedClubId(id);
                    setTaps([]);
                }}
            />

            {club && (
                <TargetSheet
                    open={showTarget}
                    onOpenChange={setShowTarget}
                    club={club}
                    value={effectiveTarget}
                    onChange={(yd) => {
                        setTargetYards(yd);
                        if (taps.length > 0) setTaps([]);
                    }}
                    onResetToCarry={() => {
                        setTargetYards(null);
                        if (taps.length > 0) setTaps([]);
                    }}
                />
            )}

            {club && (
                <AddShotDialog
                    open={addOpen}
                    onOpenChange={setAddOpen}
                    club={club}
                    targetYards={effectiveTarget}
                    onAdd={handleTap}
                />
            )}

            <ConfirmDialog
                open={endConfirm}
                onOpenChange={setEndConfirm}
                title="End range session?"
                description={
                    taps.length > 0
                        ? `${taps.length} shot${taps.length === 1 ? "" : "s"} stay saved in your shot log.`
                        : "No shots in this session — it will be discarded."
                }
                confirmLabel="End session"
                onConfirm={confirmEndSession}
            />
            <ConfirmDialog
                open={saveConfirm}
                onOpenChange={setSaveConfirm}
                title={
                    club
                        ? `Save measured σ to ${club.name}?`
                        : "Save to club?"
                }
                description={
                    club
                        ? `Replaces ${club.name}'s carry & σ values: carry ${(club.carryYards + stats.longBias).toFixed(1)}y, σ↕ ${stats.carrySd.toFixed(1)}, σ↔ ${stats.lateralSd.toFixed(1)}.`
                        : undefined
                }
                confirmLabel="Save"
                onConfirm={confirmSaveToClub}
            />
        </>
    );
}

function SessionCard({
    clubName,
    targetYards,
    sessionActive,
    shotCount,
}: {
    clubName: string;
    targetYards: number;
    sessionActive: boolean;
    shotCount: number;
}) {
    return (
        <div
            className="absolute left-3 top-3 z-20 max-w-[60%] rounded-2xl border border-border bg-card/85 px-3.5 py-2.5"
            style={{ paddingTop: "max(env(safe-area-inset-top), 10px)" }}
        >
            <div className="flex items-center gap-1.5 eyebrow">
                <span
                    className={cn(
                        "size-1.5 rounded-full",
                        sessionActive ? "bg-primary" : "bg-muted-foreground/40",
                    )}
                />
                {sessionActive
                    ? `Live · ${shotCount} shot${shotCount === 1 ? "" : "s"}`
                    : "Idle"}
            </div>
            <div
                className="font-display tabular leading-none mt-1"
                style={{ fontSize: 26, letterSpacing: "-0.025em" }}
            >
                {clubName}
            </div>
            <div className="mt-1 font-mono tabular text-[11px] text-muted-foreground">
                Target {Math.round(targetYards)}y
            </div>
        </div>
    );
}

function LiveStatsCard({
    stats,
    club,
    shots,
}: {
    stats: ReturnType<typeof dispersionFromShots>;
    club: Club;
    shots: number;
}) {
    const carryDelta = stats.carrySd - club.carrySd;
    const latDelta = stats.lateralSd - club.lateralSd;
    const measuredCarry = Math.round(club.carryYards + stats.longBias);
    return (
        <motion.div
            initial={{ opacity: 0, y: -6 }}
            animate={{ opacity: 1, y: 0 }}
            className="absolute right-3 top-3 z-20 rounded-2xl border border-border bg-card/85 px-3.5 py-2.5"
            style={{ paddingTop: "max(env(safe-area-inset-top), 10px)" }}
        >
            <div className="flex items-center gap-1.5 eyebrow">
                <span className="size-1 rounded-full bg-primary" />
                Measured · {shots}
            </div>
            <div
                className="font-display tabular leading-none mt-1 text-right"
                style={{ fontSize: 22, letterSpacing: "-0.02em" }}
            >
                {measuredCarry}
                <span className="ml-1 text-[0.5em] text-muted-foreground">y</span>
            </div>
            <div className="mt-1.5 grid grid-cols-2 gap-x-3 font-mono tabular text-[11px]">
                <DeltaCell label="σ↕" value={stats.carrySd} delta={carryDelta} />
                <DeltaCell label="σ↔" value={stats.lateralSd} delta={latDelta} />
            </div>
        </motion.div>
    );
}

function DeltaCell({
    label,
    value,
    delta,
}: {
    label: string;
    value: number;
    delta: number;
}) {
    const tighter = delta < 0;
    return (
        <div className="flex items-baseline gap-1.5">
            <span className="text-muted-foreground">{label}</span>
            <span className="text-foreground">{value.toFixed(1)}</span>
            <span
                className={cn(
                    "text-[10px]",
                    Math.abs(delta) < 0.05
                        ? "text-muted-foreground"
                        : tighter
                          ? "text-primary"
                          : "text-[#c87060]",
                )}
            >
                {delta > 0 ? "+" : ""}
                {delta.toFixed(1)}
            </span>
        </div>
    );
}

function SwitchClubSheet({
    open,
    onOpenChange,
    clubs,
    activeId,
    onPick,
}: {
    open: boolean;
    onOpenChange: (b: boolean) => void;
    clubs: Club[];
    activeId: string | null;
    onPick: (id: string) => void;
}) {
    const sorted = useMemo(
        () => [...clubs].sort((a, b) => b.carryYards - a.carryYards),
        [clubs],
    );
    return (
        <Sheet open={open} onOpenChange={onOpenChange}>
            <SheetContent side="bottom" className="max-h-[80vh] overflow-y-auto">
                <SheetHeader>
                    <div className="eyebrow">Switch</div>
                    <SheetTitle>Pick a club</SheetTitle>
                </SheetHeader>
                <div className="grid grid-cols-2 gap-2 pt-2">
                    {sorted.map((c) => {
                        const active = activeId === c.id;
                        return (
                            <button
                                key={c.id}
                                onClick={() => {
                                    onPick(c.id);
                                    onOpenChange(false);
                                }}
                                className={cn(
                                    "rounded-xl border px-3 py-2.5 text-left transition-colors",
                                    active
                                        ? "border-primary/40 bg-primary/15 text-foreground"
                                        : "border-border bg-card hover:bg-muted/40",
                                )}
                            >
                                <div className="text-[14px] font-medium">
                                    {c.name}
                                </div>
                                <div className="mt-0.5 font-mono tabular text-[11px] text-muted-foreground">
                                    {Math.round(c.carryYards)}y · σ
                                    {c.carrySd.toFixed(0)}×
                                    {c.lateralSd.toFixed(0)}
                                </div>
                            </button>
                        );
                    })}
                </div>
            </SheetContent>
        </Sheet>
    );
}

function TargetSheet({
    open,
    onOpenChange,
    club,
    value,
    onChange,
    onResetToCarry,
}: {
    open: boolean;
    onOpenChange: (b: boolean) => void;
    club: Club;
    value: number;
    onChange: (yd: number) => void;
    onResetToCarry: () => void;
}) {
    const min = Math.max(20, Math.round(club.carryYards - 80));
    const max = Math.round(club.carryYards + 80);
    const isDefault = Math.abs(value - club.carryYards) < 0.5;
    return (
        <Sheet open={open} onOpenChange={onOpenChange}>
            <SheetContent side="bottom">
                <SheetHeader>
                    <div className="eyebrow">Target</div>
                    <SheetTitle>How far is the flag?</SheetTitle>
                </SheetHeader>

                <div className="pt-2">
                    <div className="mb-3 flex items-baseline justify-between">
                        <span className="font-mono text-[10px] tracking-[0.2em] uppercase text-muted-foreground">
                            Distance
                        </span>
                        <motion.span
                            key={Math.round(value)}
                            initial={{ opacity: 0.5, scale: 0.97 }}
                            animate={{ opacity: 1, scale: 1 }}
                            className="font-display tabular leading-none"
                            style={{
                                fontSize: 44,
                                letterSpacing: "-0.025em",
                            }}
                        >
                            {Math.round(value)}
                            <span className="ml-1 text-[0.4em] text-muted-foreground">
                                yd
                            </span>
                        </motion.span>
                    </div>
                    <Slider
                        value={[Math.round(value)]}
                        min={min}
                        max={max}
                        step={1}
                        onValueChange={(v) => onChange(v[0] ?? value)}
                    />
                    <div className="mt-2 flex items-center justify-between font-mono text-[10px] text-muted-foreground">
                        <span>{min}y</span>
                        <span>{max}y</span>
                    </div>
                </div>

                <div className="flex items-center justify-between pt-3">
                    <Button
                        variant="ghost"
                        size="sm"
                        onClick={onResetToCarry}
                        disabled={isDefault}
                    >
                        Use stored carry ({Math.round(club.carryYards)}y)
                    </Button>
                    <Button
                        variant="solid"
                        onClick={() => onOpenChange(false)}
                    >
                        Done
                    </Button>
                </div>
            </SheetContent>
        </Sheet>
    );
}
