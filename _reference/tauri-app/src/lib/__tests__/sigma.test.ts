import { describe, expect, it } from "vitest";
import { dispersionFromShots, mean, sampleSd } from "../sigma";

describe("mean", () => {
    it("returns 0 for empty", () => {
        expect(mean([])).toBe(0);
    });
    it("computes average", () => {
        expect(mean([1, 2, 3, 4])).toBe(2.5);
    });
});

describe("sampleSd (n-1)", () => {
    it("returns 0 for n < 2", () => {
        expect(sampleSd([])).toBe(0);
        expect(sampleSd([5])).toBe(0);
    });
    it("matches reference", () => {
        expect(sampleSd([2, 4, 4, 4, 5, 5, 7, 9])).toBeCloseTo(2.138089935, 6);
    });
});

describe("dispersionFromShots", () => {
    it("computes σ along each axis independently", () => {
        const shots = [
            { lat: -3, long: 4 },
            { lat: 2, long: -2 },
            { lat: -1, long: 8 },
            { lat: 4, long: -5 },
        ];
        const r = dispersionFromShots(shots);
        expect(r.n).toBe(4);
        expect(r.carrySd).toBeCloseTo(sampleSd([4, -2, 8, -5]), 9);
        expect(r.lateralSd).toBeCloseTo(sampleSd([-3, 2, -1, 4]), 9);
    });
});
