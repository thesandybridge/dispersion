import { describe, expect, it } from "vitest";
import { summarizeShots } from "../shotStats";
import type { ShotRow } from "../../types";

function shot(args: {
    sessionId: string;
    long: number;
    lat: number;
    t: number;
}): ShotRow {
    return {
        id: `s-${args.t}-${args.long}-${args.lat}`,
        sessionId: args.sessionId,
        clubId: "c1",
        targetDistanceYards: 150,
        longDelta: args.long,
        latDelta: args.lat,
        outcome: null,
        timestamp: new Date(args.t),
    };
}

describe("summarizeShots", () => {
    it("returns null on empty", () => {
        expect(summarizeShots([])).toBeNull();
    });

    it("groups by session and computes σ per session", () => {
        const shots: ShotRow[] = [
            shot({ sessionId: "a", long: 1, lat: 1, t: 1000 }),
            shot({ sessionId: "a", long: -1, lat: -1, t: 1100 }),
            shot({ sessionId: "a", long: 0, lat: 0, t: 1200 }),
            shot({ sessionId: "b", long: 5, lat: 4, t: 5000 }),
            shot({ sessionId: "b", long: -5, lat: -4, t: 5100 }),
        ];
        const r = summarizeShots(shots);
        expect(r).not.toBeNull();
        expect(r!.totalShots).toBe(5);
        expect(r!.sessionCount).toBe(2);
        expect(r!.sigmaSeries).toHaveLength(2);
        const first = r!.sigmaSeries[0]!;
        const second = r!.sigmaSeries[1]!;
        expect(first).toBeLessThan(second);
    });

    it("filters out sessions with < 2 shots", () => {
        const shots: ShotRow[] = [
            shot({ sessionId: "tiny", long: 3, lat: 0, t: 0 }),
            shot({ sessionId: "ok", long: 1, lat: 0, t: 100 }),
            shot({ sessionId: "ok", long: -1, lat: 0, t: 200 }),
        ];
        const r = summarizeShots(shots);
        expect(r!.sigmaSeries).toHaveLength(1);
    });

    it("delta is the change between latest two session σs", () => {
        const shots: ShotRow[] = [
            shot({ sessionId: "old", long: 5, lat: 0, t: 0 }),
            shot({ sessionId: "old", long: -5, lat: 0, t: 100 }),
            shot({ sessionId: "new", long: 1, lat: 0, t: 1000 }),
            shot({ sessionId: "new", long: -1, lat: 0, t: 1100 }),
        ];
        const r = summarizeShots(shots);
        expect(r!.deltaCarrySd).not.toBeNull();
        expect(r!.deltaCarrySd!).toBeLessThan(0);
    });
});
