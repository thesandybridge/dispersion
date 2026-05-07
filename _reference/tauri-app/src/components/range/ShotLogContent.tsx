import { useQueries } from "@tanstack/react-query";
import { useClubs, useSessions, useShotCounts } from "../../lib/queries";
import { listShotsByClub } from "../../db/shots";
import { summarizeShots, type ClubSummary } from "../../lib/shotStats";
import { SigmaSparkline } from "../primitives/SigmaSparkline";
import { Icon } from "../primitives/Icon";
import type { Club } from "../../types";

export function ShotLogContent({
    onOpenSession,
}: {
    onOpenSession?: (id: string) => void;
}) {
    const counts = useShotCounts();
    const sessions = useSessions();
    const clubs = useClubs();

    const summaries = useQueries({
        queries: (clubs.data ?? []).map((c) => ({
            queryKey: ["shots", "club", c.id],
            queryFn: () => listShotsByClub(c.id, 200),
            staleTime: 30_000,
        })),
    });

    const clubSummaries: Array<{ club: Club; summary: ClubSummary | null }> =
        (clubs.data ?? []).map((club, i) => ({
            club,
            summary: summarizeShots(summaries[i]?.data ?? []),
        }));

    const clubsWithData = clubSummaries.filter(
        (c) => c.summary && c.summary.sigmaSeries.length >= 1,
    );

    return (
        <div className="flex-1 min-h-0 overflow-auto">
            <div
                className="px-[18px] pt-3.5 pb-3 md:px-7 md:pt-4"
                style={{ borderBottom: "1px solid rgba(26,36,25,0.08)" }}
            >
                <div className="flex items-baseline justify-between">
                    <div
                        className="font-display"
                        style={{ fontSize: 28, letterSpacing: "-0.02em" }}
                    >
                        {counts.data?.total ?? 0} shot
                        {counts.data?.total === 1 ? "" : "s"}
                    </div>
                    <div
                        className="font-mono text-[12px]"
                        style={{ color: "rgba(26,36,25,0.55)" }}
                    >
                        {counts.data?.last30Days ?? 0} last 30d
                    </div>
                </div>
            </div>

            {clubsWithData.length > 0 && (
                <>
                    <div
                        className="px-[18px] pt-4 pb-1.5 text-[10px] tracking-[0.2em] uppercase md:px-7"
                        style={{ color: "rgba(26,36,25,0.45)" }}
                    >
                        Per club · σ over sessions
                    </div>
                    <div className="px-[18px] pb-1 flex gap-2 overflow-x-auto md:px-7">
                        {clubsWithData.map(({ club, summary }) => (
                            <ClubCard
                                key={club.id}
                                club={club}
                                summary={summary!}
                            />
                        ))}
                    </div>
                </>
            )}

            <div
                className="px-[18px] pt-5 pb-2 text-[10px] tracking-[0.2em] uppercase md:px-7"
                style={{ color: "rgba(26,36,25,0.45)" }}
            >
                Sessions
            </div>
            {(sessions.data ?? []).length === 0 ? (
                <div
                    className="px-[18px] py-10 text-center text-[13px]"
                    style={{ color: "rgba(26,36,25,0.55)" }}
                >
                    No sessions yet. Start a Range session or log a shot from
                    the Calculator to begin.
                </div>
            ) : (
                (sessions.data ?? []).map((s) => {
                    const accent = s.kind === "range" ? "#a9d18e" : "#e6c068";
                    return (
                        <button
                            key={s.id}
                            onClick={() => onOpenSession?.(s.id)}
                            className="w-full grid items-center gap-3.5 px-[18px] py-3.5 md:px-7 text-left"
                            style={{
                                gridTemplateColumns: "4px 1fr auto",
                                borderTop: "1px solid rgba(26,36,25,0.06)",
                            }}
                        >
                            <div
                                className="rounded-sm"
                                style={{
                                    width: 4,
                                    height: 36,
                                    background: accent,
                                }}
                            />
                            <div>
                                <div className="text-[13px] font-medium">
                                    {s.label}
                                </div>
                                <div
                                    className="font-mono text-[11px] mt-0.5"
                                    style={{ color: "rgba(26,36,25,0.55)" }}
                                >
                                    {formatSessionDate(s.startedAt)} · {s.kind}
                                </div>
                            </div>
                            <Icon.ChevronRight
                                size={14}
                                color="rgba(26,36,25,0.4)"
                            />
                        </button>
                    );
                })
            )}
        </div>
    );
}

function ClubCard({ club, summary }: { club: Club; summary: ClubSummary }) {
    const delta = summary.deltaCarrySd;
    const deltaColor = delta == null ? null : delta < 0 ? "#2c8a5e" : "#c87060";
    const deltaText =
        delta == null
            ? null
            : `${delta < 0 ? "↓" : "↑"}${Math.abs(delta).toFixed(1)}`;
    return (
        <div
            className="shrink-0 bg-white rounded-[10px] p-3"
            style={{
                minWidth: 130,
                border: "1px solid rgba(26,36,25,0.08)",
            }}
        >
            <div className="flex items-center justify-between">
                <span className="text-[13px] font-medium">{club.name}</span>
                <span
                    className="font-mono text-[10px]"
                    style={{ color: "rgba(26,36,25,0.45)" }}
                >
                    {summary.totalShots}
                </span>
            </div>
            {summary.sigmaSeries.length >= 2 ? (
                <SigmaSparkline points={summary.sigmaSeries} />
            ) : (
                <div
                    className="h-[22px] mt-1.5 flex items-center font-mono text-[10px]"
                    style={{ color: "rgba(26,36,25,0.4)" }}
                >
                    1 session — need ≥2 to trend
                </div>
            )}
            <div
                className="flex justify-between mt-1 font-mono text-[10px]"
                style={{ color: "rgba(26,36,25,0.55)" }}
            >
                <span>
                    σ{" "}
                    {summary.latestCarrySd != null
                        ? summary.latestCarrySd.toFixed(1)
                        : "—"}
                </span>
                {deltaText && (
                    <span style={{ color: deltaColor ?? undefined }}>
                        {deltaText}
                    </span>
                )}
            </div>
        </div>
    );
}

function formatSessionDate(d: Date): string {
    const now = new Date();
    const sameDay =
        d.getFullYear() === now.getFullYear() &&
        d.getMonth() === now.getMonth() &&
        d.getDate() === now.getDate();
    if (sameDay) {
        return `Today · ${d.toLocaleTimeString([], {
            hour: "numeric",
            minute: "2-digit",
        })}`;
    }
    return d.toLocaleDateString([], {
        month: "short",
        day: "numeric",
    });
}
