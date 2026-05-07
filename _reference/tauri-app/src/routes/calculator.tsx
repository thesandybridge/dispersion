import { createFileRoute } from "@tanstack/react-router";
import { useEffect, useMemo, useState } from "react";
import { motion } from "framer-motion";
import {
    ArrowDownIcon,
    ArrowLeftIcon,
    ArrowRightIcon,
    ArrowUpIcon,
    CheckCircle2Icon,
    MountainIcon,
    PlusIcon,
    RotateCcwIcon,
    SlidersHorizontalIcon,
    TargetIcon,
    WindIcon,
    XIcon,
} from "lucide-react";
import {
    effectiveDistance,
    LIE_TYPES,
    lieMultiplier,
    useScenario,
    type LieId,
} from "@/lib/scenarioStore";
import {
    useClubs,
    useCreateSession,
    useCreateShot,
    useShotCounts,
} from "@/lib/queries";
import { useActiveSession } from "@/lib/sessionStore";
import { newId } from "@/lib/id";
import { rankClubs } from "@/lib/probability";
import { ZONE_PRESETS, getPreset } from "@/lib/presets";
import { useSettings } from "@/lib/settingsStore";
import { fromYards, roundForUnit, toYards, unitLabel } from "@/lib/units";
import { probLabel } from "@/lib/probLabel";
import { ResponsiveDispersionViz } from "@/components/primitives/ResponsiveDispersionViz";
import { CursorReadout } from "@/components/primitives/CursorReadout";
import { describeDbError } from "@/lib/dbErrors";
import { notify, tap as hapticTap } from "@/lib/haptics";
import { useDial } from "@/lib/dialStore";
import { toggleTag } from "@/lib/outcomes";
import { cn } from "@/lib/cn";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Slider } from "@/components/ui/slider";
import {
    Sheet,
    SheetContent,
    SheetHeader,
    SheetTitle,
} from "@/components/ui/sheet";
import { ToggleGroup, ToggleGroupItem } from "@/components/ui/toggle-group";
import type {
    Club,
    ClubResult,
    ShotOutcomeTag,
    ShotScenario,
} from "@/types";

export const Route = createFileRoute("/calculator")({
    component: CalculatorPage,
});

function CalculatorPage() {
    const search = useScenario();
    const setScenario = useScenario((s) => s.set);
    const clubs = useClubs();
    const unit = useSettings((s) => s.unit);
    const u = unitLabel(unit);
    const [zoneOpen, setZoneOpen] = useState(false);
    const [logOpen, setLogOpen] = useState(false);
    const [logFlash, setLogFlash] = useState<string | null>(null);
    const createSession = useCreateSession();
    const createShot = useCreateShot();
    const shotCounts = useShotCounts();
    const activeSession = useActiveSession((s) => s.active);
    const setActiveSession = useActiveSession((s) => s.setActive);

    async function ensureRoundSession(): Promise<string> {
        if (activeSession && activeSession.kind === "round") return activeSession.id;
        const id = newId();
        await createSession.mutateAsync({
            id,
            kind: "round",
            label: "Course session",
        });
        setActiveSession({ id, kind: "round", label: "Course session" });
        return id;
    }

    async function handleLog(
        club: Club,
        outcomes: ShotOutcomeTag[],
        landing: { lat: number; long: number } | null,
    ) {
        hapticTap("medium");
        try {
            const sid = await ensureRoundSession();
            await createShot.mutateAsync({
                id: newId(),
                sessionId: sid,
                clubId: club.id,
                targetDistanceYards: search.distance,
                longDelta: landing?.long ?? 0,
                latDelta: landing?.lat ?? 0,
                outcomes,
            });
            setLogOpen(false);
            const label =
                outcomes.length === 0 ? "logged" : outcomes.join(" · ");
            const landingNote = landing
                ? ` · ${landing.long >= 0 ? "+" : ""}${landing.long.toFixed(0)}, ${landing.lat >= 0 ? "+" : ""}${landing.lat.toFixed(0)}`
                : "";
            setLogFlash(`${club.name} · ${label}${landingNote}`);
            void notify("success");
            setTimeout(() => setLogFlash(null), 2200);
        } catch (e) {
            setLogOpen(false);
            setLogFlash(`Error · ${describeDbError(e)}`);
            void notify("error");
            setTimeout(() => setLogFlash(null), 6000);
        }
    }

    const update = setScenario;

    function applyPreset(id: string) {
        const p = getPreset(id);
        if (!p) return;
        update({
            preset: id,
            width: p.zone.widthYards,
            depth: p.zone.depthYards,
        });
    }

    const playingDistance = useMemo(
        () =>
            effectiveDistance(
                search.distance,
                search.windMph,
                search.elevationFt,
            ),
        [search.distance, search.windMph, search.elevationFt],
    );

    const lieMul = lieMultiplier(search.lie);

    const scenario: ShotScenario = useMemo(
        () => ({
            distanceToTargetYards: playingDistance,
            safeZone: {
                widthYards: search.width,
                depthYards: search.depth,
            },
            penaltyZones: [],
        }),
        [playingDistance, search.width, search.depth],
    );

    const adjustedClubs = useMemo(() => {
        if (!clubs.data) return [];
        if (lieMul === 1) return clubs.data;
        return clubs.data.map((c) => ({
            ...c,
            carrySd: c.carrySd * lieMul,
            lateralSd: c.lateralSd * lieMul,
        }));
    }, [clubs.data, lieMul]);

    const ranked = useMemo(() => {
        if (adjustedClubs.length === 0) return [];
        return rankClubs(adjustedClubs, scenario);
    }, [adjustedClubs, scenario]);

    const qualifying = useMemo(() => {
        if (search.minProbability <= 0) return ranked;
        return ranked.filter((r) => r.probabilityInZone >= search.minProbability);
    }, [ranked, search.minProbability]);

    const clubMap = useMemo(() => {
        const m = new Map<string, Club>();
        for (const c of adjustedClubs) m.set(c.id, c);
        return m;
    }, [adjustedClubs]);

    const usingThreshold = search.minProbability > 0 && qualifying.length > 0;
    const noneQualify = search.minProbability > 0 && qualifying.length === 0;
    const list = usingThreshold ? qualifying : ranked;
    const recommended = list[0];
    const recommendedClub = recommended ? clubMap.get(recommended.clubId) : undefined;
    const alts = list.slice(1, 6);

    const [viewClubId, setViewClubId] = useState<string | null>(null);
    const viewedResult: ClubResult | undefined =
        ranked.find((r) => r.clubId === viewClubId) ?? recommended;
    const viewedClub: Club | undefined = viewedResult
        ? clubMap.get(viewedResult.clubId)
        : undefined;
    const isViewingRecommended =
        !!viewedResult &&
        !!recommended &&
        viewedResult.clubId === recommended.clubId;

    const presetName =
        ZONE_PRESETS.find((p) => p.id === search.preset)?.label ?? "Custom";
    const distanceDisplay = roundForUnit(fromYards(search.distance, unit), unit);
    const widthDisplay = roundForUnit(fromYards(search.width, unit), unit);
    const depthDisplay = roundForUnit(fromYards(search.depth, unit), unit);

    // Register actions for the persistent radial dial.
    const setDialActions = useDial((s) => s.setActions);
    useEffect(() => {
        setDialActions([
            {
                id: "zone",
                label: "Zone",
                icon: <SlidersHorizontalIcon className="size-5" />,
                onClick: () => setZoneOpen(true),
            },
            {
                id: "log",
                label: "Log shot",
                icon: <PlusIcon className="size-5" />,
                tone: "primary",
                onClick: () => recommendedClub && setLogOpen(true),
                disabled: !recommendedClub,
            },
            {
                id: "clear",
                label: "Reset conditions",
                icon: <RotateCcwIcon className="size-5" />,
                onClick: () =>
                    update({
                        windMph: 0,
                        elevationFt: 0,
                        lie: "fairway",
                        minProbability: 0,
                    }),
            },
        ]);
        return () => setDialActions([]);
    }, [setDialActions, recommendedClub, update]);

    return (
        <div className="relative flex-1 min-h-0 overflow-hidden bg-[#070d0a] text-foreground">
            {/* Full-bleed dispersion */}
            <div className="absolute inset-0">
                {viewedClub ? (
                    <>
                        <ResponsiveDispersionViz
                            carry={viewedClub.carryYards}
                            carrySd={viewedClub.carrySd}
                            lateralSd={viewedClub.lateralSd}
                            distanceToTarget={search.distance}
                            zoneWidth={search.width}
                            zoneDepth={search.depth}
                            showZone
                            contours={7}
                            facets={28}
                            showLabels={false}
                            bg="#070d0a"
                        />
                        <CursorReadout
                            carry={viewedClub.carryYards}
                            carrySd={viewedClub.carrySd}
                            lateralSd={viewedClub.lateralSd}
                            distanceToTarget={search.distance}
                        />
                    </>
                ) : (
                    <div className="absolute inset-0 bg-[#070d0a]" />
                )}
            </div>

            {/* scrims */}
            <div
                className="pointer-events-none absolute inset-x-0 top-0 h-[260px]"
                style={{
                    background:
                        "linear-gradient(to bottom, rgba(7,13,10,0.92) 0%, rgba(7,13,10,0.55) 55%, rgba(7,13,10,0) 100%)",
                }}
            />
            <div
                className="pointer-events-none absolute inset-x-0 bottom-0 h-[58%]"
                style={{
                    background:
                        "linear-gradient(to top, rgba(7,13,10,0.95) 35%, rgba(7,13,10,0) 100%)",
                }}
            />

            {/* Top header */}
            <div className="absolute inset-x-0 top-0 z-10 px-5 pt-safe md:px-7">
                <div className="screen-header" />
                <div className="flex items-center justify-between">
                    <span className="flex items-center gap-1.5 eyebrow">
                        {activeSession ? (
                            <>
                                <span
                                    className={cn(
                                        "size-1.5 rounded-full",
                                        activeSession.kind === "range"
                                            ? "bg-primary"
                                            : "bg-[#e6c068]",
                                    )}
                                />
                                Active · {activeSession.kind}
                            </>
                        ) : (
                            <>
                                <TargetIcon className="size-3 opacity-70" />
                                Calculator
                            </>
                        )}
                    </span>
                    <span className="font-mono tabular text-[10px] text-muted-foreground">
                        {shotCounts.data?.last30Days ?? 0} shots · 30d
                    </span>
                </div>

                <div className="mt-3 grid grid-cols-[1fr_auto] items-end gap-4">
                    <button
                        onClick={() => setZoneOpen(true)}
                        className="text-left group"
                    >
                        <div className="eyebrow mb-1 group-hover:text-foreground/80 transition-colors">
                            Distance to target
                        </div>
                        <motion.div
                            key={distanceDisplay}
                            initial={{ opacity: 0.6, scale: 0.97 }}
                            animate={{ opacity: 1, scale: 1 }}
                            transition={{
                                type: "spring",
                                stiffness: 320,
                                damping: 28,
                            }}
                            className="font-display tabular leading-none"
                            style={{
                                fontSize: "clamp(64px, 16vw, 112px)",
                                fontWeight: 400,
                                letterSpacing: "-0.035em",
                            }}
                        >
                            {distanceDisplay}
                            <span
                                className="ml-1 text-foreground/45"
                                style={{ fontSize: "0.28em" }}
                            >
                                {u.toUpperCase()}
                            </span>
                        </motion.div>
                        <div className="mt-2 flex items-center gap-2 font-mono text-[10px] tabular text-muted-foreground">
                            <span className="h-px w-6 bg-border" />
                            playing {Math.round(playingDistance)}
                            {u}
                        </div>
                    </button>

                    <ZoneSummary
                        presetName={presetName}
                        widthDisplay={widthDisplay}
                        depthDisplay={depthDisplay}
                        onClick={() => setZoneOpen(true)}
                    />
                </div>
            </div>

            {/* Bottom stack */}
            <div className="absolute inset-x-0 bottom-0 z-10 flex flex-col gap-2.5 px-4 pb-4 md:px-6 md:pb-5">
                <ConditionsRow
                    windMph={search.windMph}
                    elevationFt={search.elevationFt}
                    lie={search.lie}
                    minProbability={search.minProbability}
                    noneQualify={noneQualify}
                    onOpen={() => setZoneOpen(true)}
                />

                {!isViewingRecommended && viewedClub && viewedResult && (
                    <ViewingBanner
                        clubName={viewedClub.name}
                        prob={viewedResult.probabilityInZone}
                        onReturn={() => setViewClubId(null)}
                    />
                )}

                {recommended && recommendedClub ? (
                    <RecommendedCard
                        club={recommendedClub}
                        result={recommended}
                        active={isViewingRecommended}
                        onClick={() => setViewClubId(null)}
                    />
                ) : (
                    <EmptyRecommendation />
                )}

                {alts.length > 0 && (
                    <AltsRail
                        alts={alts}
                        clubMap={clubMap}
                        viewClubId={viewClubId ?? recommended?.clubId ?? null}
                        onSelect={(id) =>
                            setViewClubId(
                                id === recommended?.clubId ? null : id,
                            )
                        }
                    />
                )}

                <div className="flex gap-2">
                    <Button
                        variant="outline"
                        size="lg"
                        onClick={() => setZoneOpen(true)}
                        className="flex-none bg-card/70 border-border"
                    >
                        <SlidersHorizontalIcon /> Zone
                    </Button>
                    <Button
                        size="lg"
                        onClick={() => recommendedClub && setLogOpen(true)}
                        disabled={!recommendedClub}
                        className="flex-1"
                    >
                        <PlusIcon className="size-4" />
                        Log shot
                        {recommendedClub ? ` · ${recommendedClub.name}` : ""}
                    </Button>
                </div>
            </div>

            <ZoneSheet
                open={zoneOpen}
                onOpenChange={setZoneOpen}
                search={search}
                update={update}
                applyPreset={applyPreset}
            />

            {recommendedClub && (
                <QuickLogSheet
                    open={logOpen}
                    onOpenChange={setLogOpen}
                    club={recommendedClub}
                    distance={search.distance}
                    onLog={(outcomes, landing) =>
                        handleLog(recommendedClub, outcomes, landing)
                    }
                />
            )}

            {logFlash && (
                <motion.div
                    initial={{ opacity: 0, y: -8 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0 }}
                    className="absolute left-1/2 top-24 z-30 -translate-x-1/2 rounded-full bg-primary px-4 py-2 text-[12px] font-semibold text-primary-foreground shadow-lg"
                >
                    Logged · {logFlash}
                </motion.div>
            )}
        </div>
    );
}

function ZoneSummary({
    presetName,
    widthDisplay,
    depthDisplay,
    onClick,
}: {
    presetName: string;
    widthDisplay: number;
    depthDisplay: number;
    onClick: () => void;
}) {
    return (
        <button
            onClick={onClick}
            className="rounded-2xl border border-border bg-card/70 px-3.5 py-2.5 text-right transition-colors hover:bg-card"
        >
            <div className="eyebrow">Zone</div>
            <div className="text-[13px] font-medium leading-tight mt-0.5">
                {presetName}
            </div>
            <div className="mt-1 font-mono tabular text-[11px] text-muted-foreground">
                {widthDisplay}w × {depthDisplay}d
            </div>
        </button>
    );
}

function EmptyRecommendation() {
    return (
        <div className="rounded-2xl border border-border bg-card/70 p-5 text-center">
            <div className="eyebrow mb-2">No clubs</div>
            <div className="text-sm text-muted-foreground">
                Add a club to get a recommendation.
            </div>
        </div>
    );
}

function RecommendedCard({
    club,
    result,
    active,
    onClick,
}: {
    club: Club;
    result: ClubResult;
    active: boolean;
    onClick: () => void;
}) {
    const lbl = probLabel(result.probabilityInZone);
    const pct = Math.round(result.probabilityInZone * 100);
    return (
        <button
            onClick={onClick}
            className={cn(
                "group relative overflow-hidden rounded-2xl border bg-card/85 px-4 py-4 text-left transition-all md:px-5 md:py-5",
                active
                    ? "border-primary/55 shadow-[0_0_0_3px_rgba(169,209,142,0.12)]"
                    : "border-border hover:border-border/80",
            )}
        >
            {/* corner bracket */}
            <div className="pointer-events-none absolute right-3 top-3">
                <div
                    className="h-2 w-6 border-t border-r"
                    style={{ borderColor: lbl.color, opacity: 0.55 }}
                />
            </div>

            <div className="grid grid-cols-[1fr_auto] items-center gap-4">
                <div className="min-w-0">
                    <div
                        className="flex items-center gap-1.5 eyebrow"
                        style={{ color: lbl.color }}
                    >
                        <span
                            className="size-1.5 rounded-full"
                            style={{ background: lbl.color }}
                        />
                        Recommended · {lbl.label.toLowerCase()}
                    </div>
                    <div
                        className="mt-1 font-display leading-none truncate"
                        style={{
                            fontSize: "clamp(34px, 8vw, 48px)",
                            letterSpacing: "-0.02em",
                        }}
                    >
                        {club.name}
                    </div>
                    <div className="mt-3 flex flex-wrap gap-3 font-mono tabular text-[11px] text-muted-foreground">
                        <span>EXP {Math.round(club.carryYards)}y</span>
                        <span>σ↕ {club.carrySd.toFixed(1)}</span>
                        <span>σ↔ {club.lateralSd.toFixed(1)}</span>
                    </div>
                </div>

                <ProbabilityDial value={pct} color={lbl.color} />
            </div>
        </button>
    );
}

function ProbabilityDial({ value, color }: { value: number; color: string }) {
    const r = 30;
    const c = 2 * Math.PI * r;
    const dash = (value / 100) * c;
    return (
        <div className="relative" style={{ width: 86, height: 86 }}>
            <svg width="86" height="86" viewBox="0 0 86 86">
                <circle
                    cx="43"
                    cy="43"
                    r={r}
                    fill="none"
                    stroke="rgba(246,241,225,0.08)"
                    strokeWidth="6"
                />
                <motion.circle
                    cx="43"
                    cy="43"
                    r={r}
                    fill="none"
                    stroke={color}
                    strokeWidth="6"
                    strokeLinecap="round"
                    transform="rotate(-90 43 43)"
                    initial={{ strokeDashoffset: c }}
                    animate={{ strokeDashoffset: c - dash }}
                    transition={{ type: "spring", stiffness: 120, damping: 22 }}
                    style={{ strokeDasharray: c }}
                />
            </svg>
            <div className="absolute inset-0 flex items-center justify-center">
                <motion.span
                    key={value}
                    initial={{ opacity: 0.4, scale: 0.92 }}
                    animate={{ opacity: 1, scale: 1 }}
                    transition={{ type: "spring", stiffness: 240, damping: 22 }}
                    className="font-display tabular leading-none"
                    style={{ fontSize: 28, color }}
                >
                    {value}
                    <span style={{ fontSize: "0.4em", opacity: 0.65 }}>%</span>
                </motion.span>
            </div>
        </div>
    );
}

function ConditionsRow({
    windMph,
    elevationFt,
    lie,
    minProbability,
    noneQualify,
    onOpen,
}: {
    windMph: number;
    elevationFt: number;
    lie: LieId;
    minProbability: number;
    noneQualify: boolean;
    onOpen: () => void;
}) {
    const items: Array<{
        key: string;
        icon: React.ReactNode;
        label: string;
        warn?: boolean;
    }> = [];
    if (windMph !== 0)
        items.push({
            key: "wind",
            icon: <WindIcon className="size-3" />,
            label:
                windMph > 0
                    ? `+${windMph} tail`
                    : `${Math.abs(windMph)} head`,
        });
    if (elevationFt !== 0)
        items.push({
            key: "elev",
            icon: <MountainIcon className="size-3" />,
            label:
                elevationFt > 0
                    ? `+${elevationFt}ft`
                    : `${Math.abs(elevationFt)}ft ↓`,
        });
    if (lie !== "fairway" && lie !== "tee")
        items.push({
            key: "lie",
            icon: null,
            label: lie.replace("-", " "),
        });
    if (minProbability > 0)
        items.push({
            key: "thresh",
            icon: null,
            label: noneQualify
                ? `≥${Math.round(minProbability * 100)}% · none qualify`
                : `≥${Math.round(minProbability * 100)}%`,
            warn: noneQualify,
        });

    if (items.length === 0) return null;
    return (
        <button
            onClick={onOpen}
            className="flex flex-wrap gap-1.5 rounded-2xl border border-border bg-card/60 px-2.5 py-2 text-left"
        >
            {items.map((it) => (
                <Badge
                    key={it.key}
                    variant={it.warn ? "destructive" : "outline"}
                    className="bg-card/70"
                >
                    {it.icon}
                    {it.label}
                </Badge>
            ))}
        </button>
    );
}

function ViewingBanner({
    clubName,
    prob,
    onReturn,
}: {
    clubName: string;
    prob: number;
    onReturn: () => void;
}) {
    return (
        <div className="flex items-center justify-between gap-3 rounded-xl border border-destructive/40 bg-destructive/10 px-3.5 py-2 text-foreground">
            <div className="text-[12px]">
                <span className="mr-2 eyebrow text-destructive">Viewing</span>
                <span className="font-medium">{clubName}</span>
                <span className="ml-2 font-mono tabular text-[11px] text-muted-foreground">
                    {Math.round(prob * 100)}%
                </span>
            </div>
            <button
                onClick={onReturn}
                className="text-[11px] tracking-[0.16em] uppercase text-primary"
            >
                Show recommended
            </button>
        </div>
    );
}

function AltsRail({
    alts,
    clubMap,
    viewClubId,
    onSelect,
}: {
    alts: ClubResult[];
    clubMap: Map<string, Club>;
    viewClubId: string | null;
    onSelect: (id: string) => void;
}) {
    return (
        <div className="overflow-hidden rounded-2xl border border-border bg-card/60">
            <div className="flex items-center gap-2 px-3 py-1.5 border-b border-border/60">
                <div className="eyebrow">Alternatives</div>
                <div className="ml-auto font-mono tabular text-[10px] text-muted-foreground">
                    {alts.length}
                </div>
            </div>
            <div className="max-h-[180px] overflow-y-auto">
                {alts.map((r, i) => {
                    const club = clubMap.get(r.clubId);
                    if (!club) return null;
                    const lbl = probLabel(r.probabilityInZone);
                    const active = viewClubId === r.clubId;
                    return (
                        <button
                            key={r.clubId}
                            onClick={() => onSelect(r.clubId)}
                            className={cn(
                                "grid w-full items-center gap-3 px-3.5 py-2.5 text-left transition-colors",
                                i > 0 && "border-t border-border/40",
                                active && "bg-primary/8",
                            )}
                            style={{
                                gridTemplateColumns: "20px 1fr 56px 44px",
                            }}
                        >
                            <span
                                className="font-mono text-[10px]"
                                style={{
                                    color: active
                                        ? lbl.color
                                        : "var(--muted)",
                                }}
                            >
                                {String(i + 2).padStart(2, "0")}
                            </span>
                            <div className="min-w-0">
                                <div className="text-[14px] font-medium truncate">
                                    {club.name}
                                </div>
                                <div className="font-mono tabular text-[10px] text-muted-foreground">
                                    {Math.round(club.carryYards)}y · σ
                                    {club.carrySd.toFixed(0)}×
                                    {club.lateralSd.toFixed(0)}
                                </div>
                            </div>
                            <div className="h-1 w-full overflow-hidden rounded-full bg-muted/60">
                                <div
                                    style={{
                                        width: `${r.probabilityInZone * 100}%`,
                                        height: "100%",
                                        background: lbl.color,
                                    }}
                                />
                            </div>
                            <div
                                className="text-right font-display tabular leading-none"
                                style={{ fontSize: 18 }}
                            >
                                {Math.round(r.probabilityInZone * 100)}
                                <span
                                    className="text-muted-foreground"
                                    style={{ fontSize: "0.55em" }}
                                >
                                    %
                                </span>
                            </div>
                        </button>
                    );
                })}
            </div>
        </div>
    );
}

type ZoneState = {
    distance: number;
    width: number;
    depth: number;
    preset?: string;
    windMph: number;
    elevationFt: number;
    lie: LieId;
    minProbability: number;
};

function ZoneSheet({
    open,
    onOpenChange,
    search,
    update,
    applyPreset,
}: {
    open: boolean;
    onOpenChange: (b: boolean) => void;
    search: ZoneState;
    update: (patch: Partial<ZoneState>) => void;
    applyPreset: (id: string) => void;
}) {
    const u = unitLabel(useSettings((s) => s.unit));
    return (
        <Sheet open={open} onOpenChange={onOpenChange}>
            <SheetContent side="bottom" className="max-h-[92vh] overflow-y-auto">
                <SheetHeader>
                    <div className="eyebrow">Adjust</div>
                    <SheetTitle>Target & zone</SheetTitle>
                </SheetHeader>
                <div className="space-y-5 pt-2">
                    <UnitNumberField
                        label={`Distance to target (${u})`}
                        valueYards={search.distance}
                        onCommit={(yd) => update({ distance: yd })}
                    />

                    <FieldGroup label="Preset">
                        <ToggleGroup
                            type="single"
                            value={search.preset}
                            onValueChange={(v) => v && applyPreset(v)}
                        >
                            {ZONE_PRESETS.map((p) => (
                                <ToggleGroupItem key={p.id} value={p.id}>
                                    {p.label}
                                </ToggleGroupItem>
                            ))}
                        </ToggleGroup>
                    </FieldGroup>

                    <div className="grid grid-cols-2 gap-3">
                        <UnitNumberField
                            label={`Width (${u})`}
                            valueYards={search.width}
                            onCommit={(yd) =>
                                update({ width: yd, preset: undefined })
                            }
                        />
                        <UnitNumberField
                            label={`Depth (${u})`}
                            valueYards={search.depth}
                            onCommit={(yd) =>
                                update({ depth: yd, preset: undefined })
                            }
                        />
                    </div>

                    <FieldGroup label="Lie">
                        <ToggleGroup
                            type="single"
                            value={search.lie}
                            onValueChange={(v) =>
                                v && update({ lie: v as LieId })
                            }
                        >
                            {LIE_TYPES.map((l) => (
                                <ToggleGroupItem key={l.id} value={l.id}>
                                    {l.label}
                                    {l.multiplier !== 1 && (
                                        <span className="ml-1 font-mono text-[10px] opacity-70">
                                            ×{l.multiplier.toFixed(2)}
                                        </span>
                                    )}
                                </ToggleGroupItem>
                            ))}
                        </ToggleGroup>
                    </FieldGroup>

                    <FieldGroup label="Conditions">
                        <SliderRow
                            label="Wind"
                            value={search.windMph}
                            min={-25}
                            max={25}
                            step={1}
                            unit="mph"
                            describe={describeWind}
                            onChange={(v) => update({ windMph: v })}
                        />
                        <SliderRow
                            label="Elevation"
                            value={search.elevationFt}
                            min={-50}
                            max={50}
                            step={1}
                            unit="ft"
                            describe={describeElevation}
                            onChange={(v) => update({ elevationFt: v })}
                        />
                    </FieldGroup>

                    <FieldGroup label="Confidence threshold">
                        <SliderRow
                            label="Min P(in zone)"
                            value={Math.round(search.minProbability * 100)}
                            min={0}
                            max={95}
                            step={5}
                            unit="%"
                            describe={(v) =>
                                v === 0
                                    ? "Show all clubs"
                                    : `Only ≥${v}% in zone`
                            }
                            onChange={(v) =>
                                update({ minProbability: v / 100 })
                            }
                        />
                    </FieldGroup>
                </div>

                <div className="flex justify-end pt-2">
                    <Button onClick={() => onOpenChange(false)} variant="solid">
                        Done
                    </Button>
                </div>
            </SheetContent>
        </Sheet>
    );
}

function FieldGroup({
    label,
    children,
}: {
    label: string;
    children: React.ReactNode;
}) {
    return (
        <div className="space-y-2">
            <div className="eyebrow">{label}</div>
            {children}
        </div>
    );
}

function describeWind(v: number): string {
    if (v === 0) return "Calm";
    if (v > 0) return `Tailwind ${v}mph (+${v}y)`;
    return `Headwind ${Math.abs(v)}mph (−${Math.abs(v)}y)`;
}

function describeElevation(v: number): string {
    if (v === 0) return "Level";
    if (v > 0) return `Uphill ${v}ft (+${v}y)`;
    return `Downhill ${Math.abs(v)}ft (−${Math.abs(v)}y)`;
}

function SliderRow({
    label,
    value,
    min,
    max,
    step,
    unit,
    describe,
    onChange,
}: {
    label: string;
    value: number;
    min: number;
    max: number;
    step: number;
    unit: string;
    describe: (v: number) => string;
    onChange: (v: number) => void;
}) {
    return (
        <div>
            <div className="mb-1.5 flex items-baseline justify-between">
                <span className="font-mono text-[10px] tracking-[0.16em] uppercase text-muted-foreground">
                    {label}
                </span>
                <span className="font-mono tabular text-[11px] text-foreground/80">
                    {describe(value)}
                </span>
            </div>
            <div className="flex items-center gap-3">
                <span className="w-9 text-right font-mono text-[10px] text-muted-foreground">
                    {min}
                    {unit}
                </span>
                <Slider
                    value={[value]}
                    min={min}
                    max={max}
                    step={step}
                    onValueChange={(v) => onChange(v[0] ?? value)}
                    className="flex-1"
                />
                <span className="w-9 font-mono text-[10px] text-muted-foreground">
                    +{max}
                    {unit}
                </span>
            </div>
            {value !== 0 && value > min && value < max && (
                <button
                    onClick={() => onChange(0)}
                    className="mt-1.5 inline-flex items-center gap-1 text-[10px] tracking-[0.16em] uppercase text-muted-foreground hover:text-foreground"
                >
                    <RotateCcwIcon className="size-3" /> Reset
                </button>
            )}
        </div>
    );
}

function UnitNumberField({
    label,
    valueYards,
    onCommit,
}: {
    label: string;
    valueYards: number;
    onCommit: (yd: number) => void;
}) {
    const unit = useSettings((s) => s.unit);
    const display = roundForUnit(fromYards(valueYards, unit), unit);
    return (
        <label className="block">
            <div className="eyebrow mb-1.5">{label}</div>
            <input
                type="number"
                inputMode="decimal"
                step={unit === "yards" ? 1 : 0.5}
                value={display}
                onChange={(e) => {
                    const n = Number(e.target.value);
                    if (!Number.isFinite(n)) return;
                    onCommit(toYards(n, unit));
                }}
                className="w-full rounded-xl border border-border bg-input/40 px-3.5 py-2.5 font-display text-[18px] tabular outline-none transition-colors focus-visible:border-ring/70"
            />
        </label>
    );
}

/* ---------------- QuickLogSheet ---------------- */

function QuickLogSheet({
    open,
    onOpenChange,
    club,
    distance,
    onLog,
}: {
    open: boolean;
    onOpenChange: (b: boolean) => void;
    club: Club;
    distance: number;
    onLog: (
        outcomes: ShotOutcomeTag[],
        landing: { lat: number; long: number } | null,
    ) => void;
}) {
    const [tags, setTags] = useState<ShotOutcomeTag[]>([]);
    const [landing, setLanding] = useState<{ lat: number; long: number } | null>(
        null,
    );
    const [showLanding, setShowLanding] = useState(false);
    const inZone = tags.length === 1 && tags[0] === "in";

    function tap(t: ShotOutcomeTag) {
        setTags((prev) => toggleTag(prev, t));
    }

    function logInZone() {
        onLog(["in"], landing);
    }

    function save() {
        onLog(tags, landing);
    }

    return (
        <Sheet open={open} onOpenChange={onOpenChange}>
            <SheetContent
                side="bottom"
                className="max-h-[92vh] overflow-y-auto"
            >
                <SheetHeader>
                    <div className="eyebrow text-primary">Log shot</div>
                    <SheetTitle className="text-foreground">
                        {club.name} · {Math.round(distance)}y target
                    </SheetTitle>
                </SheetHeader>

                <div className="space-y-3 pt-2">
                    <Button
                        size="lg"
                        onClick={logInZone}
                        variant={inZone ? "default" : "outline"}
                        className={cn(
                            "w-full",
                            !inZone && "border-primary/40 text-primary",
                        )}
                    >
                        <CheckCircle2Icon className="size-4" />
                        Landed in zone
                    </Button>

                    <OutcomeRow
                        label="Distance"
                        items={[
                            {
                                id: "short",
                                label: "Short",
                                glyph: <ArrowDownIcon className="size-4" />,
                            },
                            {
                                id: "long",
                                label: "Long",
                                glyph: <ArrowUpIcon className="size-4" />,
                            },
                        ]}
                        active={tags}
                        onPick={tap}
                    />
                    <OutcomeRow
                        label="Lateral"
                        items={[
                            {
                                id: "left",
                                label: "Left",
                                glyph: <ArrowLeftIcon className="size-4" />,
                            },
                            {
                                id: "right",
                                label: "Right",
                                glyph: <ArrowRightIcon className="size-4" />,
                            },
                        ]}
                        active={tags}
                        onPick={tap}
                    />

                    <button
                        onClick={() => tap("penalty")}
                        className={cn(
                            "flex w-full items-center justify-between rounded-xl border px-4 py-3 transition-colors",
                            tags.includes("penalty")
                                ? "border-destructive/55 bg-destructive/15 text-destructive"
                                : "border-border bg-card/40 text-foreground",
                        )}
                    >
                        <span className="flex items-center gap-2 text-[13px]">
                            <XIcon className="size-4" /> Penalty
                        </span>
                        <span
                            className={cn(
                                "relative h-4 w-7 rounded-full transition-colors",
                                tags.includes("penalty")
                                    ? "bg-destructive"
                                    : "bg-muted",
                            )}
                        >
                            <span
                                className="absolute top-0.5 size-3 rounded-full bg-background transition-transform"
                                style={{
                                    left: 2,
                                    transform: tags.includes("penalty")
                                        ? "translateX(12px)"
                                        : "translateX(0)",
                                }}
                            />
                        </span>
                    </button>

                    <LandingNumericEntry
                        targetYards={distance}
                        landing={landing}
                        onChange={setLanding}
                        expanded={showLanding}
                        setExpanded={setShowLanding}
                    />

                    <Button
                        size="lg"
                        onClick={save}
                        disabled={tags.length === 0}
                        variant="outline"
                        className="w-full"
                    >
                        {tags.length === 0
                            ? "Pick an outcome"
                            : `Save · ${tags.join(" · ")}${landing ? " · with landing" : ""}`}
                    </Button>

                    <p className="pt-1 text-center text-[11px] text-muted-foreground">
                        Combine tags. Penalty stacks with any miss.
                    </p>
                </div>
            </SheetContent>
        </Sheet>
    );
}

function OutcomeRow({
    label,
    items,
    active,
    onPick,
}: {
    label: string;
    items: Array<{ id: ShotOutcomeTag; label: string; glyph: React.ReactNode }>;
    active: ShotOutcomeTag[];
    onPick: (t: ShotOutcomeTag) => void;
}) {
    return (
        <div>
            <div className="eyebrow mb-1.5">{label}</div>
            <div className="grid grid-cols-2 gap-2">
                {items.map((item) => {
                    const on = active.includes(item.id);
                    return (
                        <button
                            key={item.id}
                            onClick={() => onPick(item.id)}
                            className={cn(
                                "flex items-center justify-center gap-2 rounded-xl border py-3 text-[13px] transition-colors",
                                on
                                    ? "border-destructive/55 bg-destructive/15 text-destructive font-semibold"
                                    : "border-border bg-card/40 text-foreground",
                            )}
                        >
                            {item.glyph}
                            {item.label}
                        </button>
                    );
                })}
            </div>
        </div>
    );
}

function LandingNumericEntry({
    targetYards,
    landing,
    onChange,
    expanded,
    setExpanded,
}: {
    targetYards: number;
    landing: { lat: number; long: number } | null;
    onChange: (l: { lat: number; long: number } | null) => void;
    expanded: boolean;
    setExpanded: (b: boolean) => void;
}) {
    const unit = useSettings((s) => s.unit);
    const u = unitLabel(unit);
    const targetDisplay = roundForUnit(fromYards(targetYards, unit), unit);

    const [carryStr, setCarryStr] = useState<string>(String(targetDisplay));
    const [lateralStr, setLateralStr] = useState<string>("0");
    const [side, setSide] = useState<"L" | "R">("R");

    function commit() {
        const carry = Number(carryStr);
        const lat = Number(lateralStr);
        if (!Number.isFinite(carry) || !Number.isFinite(lat)) return;
        const longDelta = toYards(carry - targetDisplay, unit);
        const latYards = toYards(side === "L" ? -lat : lat, unit);
        onChange({ lat: latYards, long: longDelta });
    }

    return (
        <div>
            <button
                onClick={() => setExpanded(!expanded)}
                className="flex w-full items-center justify-between py-2 eyebrow"
            >
                <span>
                    Exact landing
                    {landing && (
                        <span className="ml-2 font-mono normal-case tracking-normal text-primary">
                            {fromYards(landing.long, unit) >= 0 ? "+" : ""}
                            {fromYards(landing.long, unit).toFixed(0)}
                            {u} long ·{" "}
                            {landing.lat >= 0 ? "R" : "L"}
                            {Math.abs(fromYards(landing.lat, unit)).toFixed(0)}
                            {u}
                        </span>
                    )}
                </span>
                <span className="font-mono normal-case tracking-normal text-muted-foreground">
                    {expanded ? "hide" : landing ? "edit" : "add"}
                </span>
            </button>

            {expanded && (
                <div className="mt-2 grid grid-cols-2 gap-2">
                    <label className="block">
                        <div className="eyebrow mb-1">Carry ({u})</div>
                        <input
                            type="number"
                            inputMode="decimal"
                            step={1}
                            value={carryStr}
                            onChange={(e) => setCarryStr(e.target.value)}
                            onBlur={commit}
                            className="w-full rounded-xl border border-border bg-input/40 px-3 py-2 font-display tabular text-[16px] outline-none focus-visible:border-ring/70"
                        />
                    </label>
                    <label className="block">
                        <div className="eyebrow mb-1">Lateral ({u})</div>
                        <div className="flex items-center gap-1.5">
                            <input
                                type="number"
                                inputMode="decimal"
                                step={1}
                                min={0}
                                value={lateralStr}
                                onChange={(e) => setLateralStr(e.target.value)}
                                onBlur={commit}
                                className="flex-1 rounded-xl border border-border bg-input/40 px-3 py-2 font-display tabular text-[16px] outline-none focus-visible:border-ring/70"
                            />
                            <ToggleGroup
                                type="single"
                                value={side}
                                onValueChange={(v) => {
                                    if (!v) return;
                                    setSide(v as "L" | "R");
                                    const lat = Number(lateralStr);
                                    const carry = Number(carryStr);
                                    if (
                                        !Number.isFinite(lat) ||
                                        !Number.isFinite(carry)
                                    )
                                        return;
                                    const longDelta = toYards(
                                        carry - targetDisplay,
                                        unit,
                                    );
                                    const latYards = toYards(
                                        v === "L" ? -lat : lat,
                                        unit,
                                    );
                                    onChange({
                                        lat: latYards,
                                        long: longDelta,
                                    });
                                }}
                            >
                                <ToggleGroupItem value="L" className="px-3 py-2">
                                    L
                                </ToggleGroupItem>
                                <ToggleGroupItem value="R" className="px-3 py-2">
                                    R
                                </ToggleGroupItem>
                            </ToggleGroup>
                        </div>
                    </label>
                </div>
            )}

            {landing && (
                <button
                    onClick={() => onChange(null)}
                    className="mt-2 inline-flex items-center gap-1 eyebrow"
                >
                    <RotateCcwIcon className="size-3" /> Clear landing
                </button>
            )}
        </div>
    );
}
