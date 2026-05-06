import type { ShotRow } from "../types";
import { sampleSd } from "./sigma";

export type ClubSummary = {
    clubId: string;
    totalShots: number;
    sessionCount: number;
    sigmaSeries: number[];
    sessionPoints: Array<{ date: Date; carrySd: number; n: number }>;
    latestCarrySd: number | null;
    latestLateralSd: number | null;
    deltaCarrySd: number | null;
};

export function summarizeShots(shots: ShotRow[]): ClubSummary | null {
    if (shots.length === 0) return null;
    const clubId = shots[0]!.clubId;

    const bySession = new Map<string, ShotRow[]>();
    for (const s of shots) {
        const arr = bySession.get(s.sessionId);
        if (arr) arr.push(s);
        else bySession.set(s.sessionId, [s]);
    }

    const sessions = Array.from(bySession.entries())
        .map(([id, items]) => {
            items.sort((a, b) => a.timestamp.getTime() - b.timestamp.getTime());
            const longs = items.map((s) => s.longDelta);
            return {
                id,
                t: items[0]!.timestamp.getTime(),
                sd: sampleSd(longs),
                n: items.length,
            };
        })
        .filter((s) => Number.isFinite(s.sd) && s.n >= 2)
        .sort((a, b) => a.t - b.t);

    const sigmaSeries = sessions.map((s) => s.sd).slice(-8);
    const sessionPoints = sessions.map((s) => ({
        date: new Date(s.t),
        carrySd: s.sd,
        n: s.n,
    }));
    const latest = sessions[sessions.length - 1] ?? null;
    const previous = sessions[sessions.length - 2] ?? null;

    return {
        clubId,
        totalShots: shots.length,
        sessionCount: bySession.size,
        sigmaSeries,
        sessionPoints,
        latestCarrySd: latest ? latest.sd : null,
        latestLateralSd: latest
            ? sampleSd(
                  shots
                      .filter((s) => s.sessionId === latest.id)
                      .map((s) => s.latDelta),
              )
            : null,
        deltaCarrySd:
            latest && previous ? latest.sd - previous.sd : null,
    };
}
