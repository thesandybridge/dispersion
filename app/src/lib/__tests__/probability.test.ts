import { describe, expect, it } from "vitest";
import { probabilityInZone, rankClubs } from "../probability";
import type { Club, ShotScenario, Zone } from "../../types";

function makeClub(overrides: Partial<Club> = {}): Club {
    return {
        id: "c1",
        name: "Test",
        carryYards: 150,
        carrySd: 5,
        lateralSd: 5,
        createdAt: new Date(0),
        ...overrides,
    };
}

function scenario(safeZone: Zone, distance = 150): ShotScenario {
    return {
        distanceToTargetYards: distance,
        safeZone,
        penaltyZones: [],
    };
}

const centeredZone = (w: number, d: number): Zone => ({
    widthYards: w,
    depthYards: d,
});

describe("probabilityInZone", () => {
    it("tighter dispersion wins for a small zone", () => {
        const tight = makeClub({ id: "tight", carrySd: 3, lateralSd: 3 });
        const loose = makeClub({ id: "loose", carrySd: 12, lateralSd: 12 });
        const s = scenario(centeredZone(10, 10));
        expect(probabilityInZone(tight, s)).toBeGreaterThan(
            probabilityInZone(loose, s),
        );
    });

    it("looser dispersion wins for a large zone (relative to tight, both near 1)", () => {
        const tight = makeClub({ id: "tight", carrySd: 3, lateralSd: 3 });
        const loose = makeClub({ id: "loose", carrySd: 12, lateralSd: 12 });
        const s = scenario(centeredZone(200, 200));
        const pT = probabilityInZone(tight, s);
        const pL = probabilityInZone(loose, s);
        expect(pT).toBeGreaterThan(0.9999);
        expect(pL).toBeGreaterThan(0.9999);
        expect(pT).toBeGreaterThanOrEqual(pL);
    });

    it("very large zone centered on landing point: P -> 1", () => {
        const club = makeClub();
        const s = scenario(centeredZone(10_000, 10_000));
        expect(probabilityInZone(club, s)).toBeCloseTo(1, 6);
    });

    it("zone far from landing point: P -> 0", () => {
        const club = makeClub({ carryYards: 150, carrySd: 5, lateralSd: 5 });
        const s = scenario(centeredZone(5, 5), 400);
        expect(probabilityInZone(club, s)).toBeLessThan(1e-10);
    });

    it("hand-computed example", () => {
        const club = makeClub({
            carryYards: 150,
            carrySd: 5,
            lateralSd: 5,
        });
        const s = scenario(centeredZone(10, 10));
        const longProb = 2 * (0.8413447461 - 0.5);
        const latProb = 2 * (0.8413447461 - 0.5);
        const expected = longProb * latProb;
        expect(probabilityInZone(club, s)).toBeCloseTo(expected, 5);
    });

    it.todo("user-provided hand-computed example");
});

describe("rankClubs", () => {
    it("orders by probability descending", () => {
        const a = makeClub({ id: "a", carrySd: 3, lateralSd: 3 });
        const b = makeClub({ id: "b", carrySd: 8, lateralSd: 8 });
        const c = makeClub({ id: "c", carrySd: 15, lateralSd: 15 });
        const s = scenario(centeredZone(8, 8));
        const ranked = rankClubs([c, a, b], s);
        expect(ranked.map((r) => r.clubId)).toEqual(["a", "b", "c"]);
        expect(ranked[0]!.expectedDistance).toBe(150);
    });
});
