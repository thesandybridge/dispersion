import type { Club, ShotRow } from "../types";
import { dispersionFromShots } from "./sigma";

export type Insight = {
    id: string;
    severity: "info" | "warn" | "good";
    title: string;
    body: string;
    action?: { label: string; clubId?: string; kind: "open-club" | "noop" };
};

const STALE_DAYS = 21;
const BIAS_THRESHOLD_YARDS = 3;
const BIAS_MIN_SHOTS = 6;
const TIGHTENING_MIN_SHOTS = 6;
const TIGHTENING_DELTA = 0.6;

export function computeInsights(
    clubs: Club[],
    shots: ShotRow[],
    now: Date = new Date(),
): Insight[] {
    const out: Insight[] = [];

    const byClub = new Map<string, ShotRow[]>();
    for (const s of shots) {
        const arr = byClub.get(s.clubId);
        if (arr) arr.push(s);
        else byClub.set(s.clubId, [s]);
    }

    out.push(...widerThanShorter(clubs));
    out.push(...staleData(clubs, byClub, now));
    out.push(...longBias(clubs, byClub));
    out.push(...sigmaTightening(clubs, byClub));

    return out;
}

function widerThanShorter(clubs: Club[]): Insight[] {
    if (clubs.length < 2) return [];
    const sorted = [...clubs].sort((a, b) => b.carryYards - a.carryYards);
    const out: Insight[] = [];
    for (let i = 0; i < sorted.length - 1; i++) {
        const longer = sorted[i]!;
        const shorter = sorted[i + 1]!;
        if (longer.carrySd > shorter.carrySd * 1.18) {
            const pct = Math.round(
                ((longer.carrySd - shorter.carrySd) / shorter.carrySd) * 100,
            );
            out.push({
                id: `wider-${longer.id}-${shorter.id}`,
                severity: "warn",
                title: `${longer.name} disperses ${pct}% wider than ${shorter.name}`,
                body: `Your longer club has looser σ than the next one down. Worth questioning whether the extra distance is worth the variance.`,
                action: {
                    label: `Open ${longer.name}`,
                    clubId: longer.id,
                    kind: "open-club",
                },
            });
            if (out.length >= 1) break;
        }
    }
    return out;
}

function staleData(
    clubs: Club[],
    byClub: Map<string, ShotRow[]>,
    now: Date,
): Insight[] {
    const out: Insight[] = [];
    const cutoff = now.getTime() - STALE_DAYS * 24 * 60 * 60 * 1000;
    for (const club of clubs) {
        const recent = byClub.get(club.id) ?? [];
        if (recent.length < 6) continue;
        const lastShot = recent
            .map((s) => s.timestamp.getTime())
            .reduce((a, b) => Math.max(a, b), 0);
        if (lastShot && lastShot < cutoff) {
            const days = Math.floor(
                (now.getTime() - lastShot) / (24 * 60 * 60 * 1000),
            );
            out.push({
                id: `stale-${club.id}`,
                severity: "info",
                title: `${club.name} σ may be stale`,
                body: `No tracked shots in ${days} days. Hit a few at the range to refresh dispersion.`,
                action: {
                    label: `Open ${club.name}`,
                    clubId: club.id,
                    kind: "open-club",
                },
            });
            if (out.length >= 1) break;
        }
    }
    return out;
}

function longBias(
    clubs: Club[],
    byClub: Map<string, ShotRow[]>,
): Insight[] {
    const out: Insight[] = [];
    for (const club of clubs) {
        const list = (byClub.get(club.id) ?? []).filter(
            (s) => !(s.longDelta === 0 && s.latDelta === 0),
        );
        if (list.length < BIAS_MIN_SHOTS) continue;
        const stats = dispersionFromShots(
            list.map((s) => ({ lat: s.latDelta, long: s.longDelta })),
        );
        if (Math.abs(stats.longBias) >= BIAS_THRESHOLD_YARDS) {
            const dir = stats.longBias > 0 ? "long" : "short";
            out.push({
                id: `bias-long-${club.id}`,
                severity: "info",
                title: `${club.name} is averaging ${dir} ${Math.abs(stats.longBias).toFixed(1)}y`,
                body: `Across ${list.length} tracked shots, your carry consistently lands ${dir} of expected. Update stored carry?`,
                action: {
                    label: `Open ${club.name}`,
                    clubId: club.id,
                    kind: "open-club",
                },
            });
            if (out.length >= 1) break;
        }
    }
    return out;
}

function sigmaTightening(
    clubs: Club[],
    byClub: Map<string, ShotRow[]>,
): Insight[] {
    const out: Insight[] = [];
    for (const club of clubs) {
        const list = (byClub.get(club.id) ?? []).filter(
            (s) => !(s.longDelta === 0 && s.latDelta === 0),
        );
        if (list.length < TIGHTENING_MIN_SHOTS) continue;
        const stats = dispersionFromShots(
            list.map((s) => ({ lat: s.latDelta, long: s.longDelta })),
        );
        const delta = club.carrySd - stats.carrySd;
        if (delta >= TIGHTENING_DELTA) {
            out.push({
                id: `tight-${club.id}`,
                severity: "good",
                title: `${club.name} σ is ${delta.toFixed(1)}y tighter than stored`,
                body: `Real shots show better dispersion (σ↕ ${stats.carrySd.toFixed(1)}) than your stored value (σ↕ ${club.carrySd.toFixed(1)}). Save the measured σ?`,
                action: {
                    label: `Open ${club.name}`,
                    clubId: club.id,
                    kind: "open-club",
                },
            });
            if (out.length >= 1) break;
        }
    }
    return out;
}
