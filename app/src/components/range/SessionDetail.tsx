import { useMemo, useState } from "react";
import {
    useClubs,
    useDeleteSession,
    useDeleteShot,
    useSessions,
    useShotsBySession,
} from "../../lib/queries";
import { decodeOutcome } from "../../lib/outcomes";
import { fromYards, unitLabel } from "../../lib/units";
import { useSettings } from "../../lib/settingsStore";
import { ConfirmDialog } from "../ConfirmDialog";
import type { ShotRow, Club } from "../../types";

export function SessionDetail({
    sessionId,
    onBack,
}: {
    sessionId: string;
    onBack: () => void;
}) {
    const sessions = useSessions();
    const shots = useShotsBySession(sessionId);
    const clubs = useClubs();
    const deleteSession = useDeleteSession();
    const deleteShot = useDeleteShot();
    const unit = useSettings((s) => s.unit);
    const u = unitLabel(unit);

    const [endConfirm, setEndConfirm] = useState(false);
    const [pendingShotDelete, setPendingShotDelete] = useState<string | null>(
        null,
    );

    const session = useMemo(
        () => (sessions.data ?? []).find((s) => s.id === sessionId),
        [sessions.data, sessionId],
    );

    const clubMap = useMemo(() => {
        const m = new Map<string, Club>();
        for (const c of clubs.data ?? []) m.set(c.id, c);
        return m;
    }, [clubs.data]);

    async function confirmDeleteSession() {
        await deleteSession.mutateAsync(sessionId);
        setEndConfirm(false);
        onBack();
    }

    async function confirmDeleteShot() {
        if (!pendingShotDelete) return;
        await deleteShot.mutateAsync(pendingShotDelete);
        setPendingShotDelete(null);
    }

    const ordered = (shots.data ?? []).slice().reverse();
    const accent = session?.kind === "round" ? "#e6c068" : "#a9d18e";

    return (
        <div
            className="flex-1 min-h-0 overflow-auto"
            style={{ background: "#f4efe3", color: "#1a2419" }}
        >
            <div
                className="screen-header px-[18px] pb-3 md:px-7"
                style={{ borderBottom: "1px solid rgba(26,36,25,0.08)" }}
            >
                <div className="flex items-center justify-between mb-2">
                    <button
                        onClick={onBack}
                        className="text-[12px] tracking-[0.16em] uppercase"
                        style={{ color: "rgba(26,36,25,0.6)" }}
                    >
                        ← Back to log
                    </button>
                    <button
                        onClick={() => setEndConfirm(true)}
                        className="text-[11px] tracking-[0.16em] uppercase"
                        style={{ color: "#a23939" }}
                    >
                        Delete session
                    </button>
                </div>
                <div className="flex items-center gap-2">
                    <div
                        className="rounded-sm"
                        style={{
                            width: 4,
                            height: 28,
                            background: accent,
                        }}
                    />
                    <div>
                        <div
                            className="text-[10px] tracking-[0.2em] uppercase"
                            style={{ color: "rgba(26,36,25,0.5)" }}
                        >
                            {session?.kind ?? "session"}
                        </div>
                        <div
                            className="font-display"
                            style={{
                                fontSize: 26,
                                lineHeight: 1.1,
                                letterSpacing: "-0.02em",
                            }}
                        >
                            {session?.label ?? "Session"}
                        </div>
                    </div>
                </div>
                <div
                    className="font-mono text-[11px] mt-1"
                    style={{ color: "rgba(26,36,25,0.55)" }}
                >
                    {session && formatStarted(session.startedAt)} ·{" "}
                    {ordered.length} shot
                    {ordered.length === 1 ? "" : "s"}
                </div>
            </div>

            {ordered.length === 0 ? (
                <div
                    className="px-[18px] py-12 text-center text-[13px]"
                    style={{ color: "rgba(26,36,25,0.55)" }}
                >
                    No shots in this session.
                </div>
            ) : (
                <div>
                    {ordered.map((shot) => (
                        <ShotRowItem
                            key={shot.id}
                            shot={shot}
                            club={clubMap.get(shot.clubId)}
                            unit={unit}
                            unitLabel={u}
                            onDelete={() => setPendingShotDelete(shot.id)}
                        />
                    ))}
                </div>
            )}

            <ConfirmDialog
                open={endConfirm}
                onOpenChange={setEndConfirm}
                title={`Delete ${session?.label ?? "this session"}?`}
                description={`Removes the session and all ${ordered.length} of its shots.`}
                confirmLabel="Delete session"
                danger
                onConfirm={confirmDeleteSession}
            />
            <ConfirmDialog
                open={!!pendingShotDelete}
                onOpenChange={(open) => {
                    if (!open) setPendingShotDelete(null);
                }}
                title="Delete this shot?"
                description="The σ values for this club will recalculate without it."
                confirmLabel="Delete"
                danger
                onConfirm={confirmDeleteShot}
            />
        </div>
    );
}

function ShotRowItem({
    shot,
    club,
    unit,
    unitLabel: u,
    onDelete,
}: {
    shot: ShotRow;
    club: Club | undefined;
    unit: "yards" | "meters";
    unitLabel: string;
    onDelete: () => void;
}) {
    const tags = decodeOutcome(shot.outcome);
    const hasLanding = !(shot.longDelta === 0 && shot.latDelta === 0);
    const long = fromYards(shot.longDelta, unit);
    const lat = fromYards(shot.latDelta, unit);
    return (
        <div
            className="grid items-center gap-3 px-[18px] py-3.5 md:px-7"
            style={{
                gridTemplateColumns: "1fr auto auto",
                borderTop: "1px solid rgba(26,36,25,0.06)",
            }}
        >
            <div className="min-w-0">
                <div className="flex items-center gap-2">
                    <span className="text-[13px] font-medium truncate">
                        {club?.name ?? "(deleted)"}
                    </span>
                    <span
                        className="font-mono text-[10px]"
                        style={{ color: "rgba(26,36,25,0.55)" }}
                    >
                        {Math.round(fromYards(shot.targetDistanceYards, unit))}
                        {u}
                    </span>
                </div>
                <div
                    className="font-mono text-[11px] mt-0.5"
                    style={{ color: "rgba(26,36,25,0.55)" }}
                >
                    {formatTime(shot.timestamp)}
                    {hasLanding && (
                        <>
                            {" · "}
                            {long >= 0 ? "+" : ""}
                            {long.toFixed(0)} long ·{" "}
                            {lat >= 0 ? "R" : "L"}
                            {Math.abs(lat).toFixed(0)}
                        </>
                    )}
                </div>
                {tags.length > 0 && (
                    <div className="flex flex-wrap gap-1 mt-1.5">
                        {tags.map((t) => (
                            <span
                                key={t}
                                className="text-[10px] tracking-[0.1em] uppercase px-1.5 py-0.5 rounded-full"
                                style={{
                                    background: tagBg(t),
                                    color: tagFg(t),
                                }}
                            >
                                {t}
                            </span>
                        ))}
                    </div>
                )}
            </div>
            <button
                onClick={onDelete}
                className="text-[16px] w-11 h-11 -m-1 rounded-md flex items-center justify-center"
                style={{ color: "rgba(162,57,57,0.7)" }}
                aria-label="Delete shot"
            >
                ✕
            </button>
        </div>
    );
}

function tagBg(t: string): string {
    if (t === "in") return "rgba(98,179,117,0.18)";
    if (t === "penalty") return "rgba(162,57,57,0.18)";
    if (t === "left" || t === "right") return "rgba(200,112,96,0.18)";
    return "rgba(230,192,104,0.22)";
}

function tagFg(t: string): string {
    if (t === "in") return "#2c8a5e";
    if (t === "penalty") return "#a23939";
    if (t === "left" || t === "right") return "#a23939";
    return "#8a6d22";
}

function formatStarted(d: Date): string {
    return d.toLocaleString([], {
        month: "short",
        day: "numeric",
        hour: "numeric",
        minute: "2-digit",
    });
}

function formatTime(d: Date): string {
    return d.toLocaleTimeString([], {
        hour: "numeric",
        minute: "2-digit",
    });
}
