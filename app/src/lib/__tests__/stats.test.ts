import { describe, expect, it } from "vitest";
import { erf, normalCdf } from "../stats";

describe("erf", () => {
    it("erf(0) is 0", () => {
        expect(erf(0)).toBeCloseTo(0, 6);
    });

    it("matches reference values", () => {
        expect(erf(0.5)).toBeCloseTo(0.5204998778, 6);
        expect(erf(1)).toBeCloseTo(0.8427007929, 6);
        expect(erf(2)).toBeCloseTo(0.9953222650, 6);
    });

    it("is odd: erf(-x) = -erf(x)", () => {
        for (const x of [0.1, 0.7, 1.3, 2.5]) {
            expect(erf(-x)).toBeCloseTo(-erf(x), 10);
        }
    });
});

describe("normalCdf", () => {
    it("Phi(0) = 0.5", () => {
        expect(normalCdf(0)).toBeCloseTo(0.5, 6);
    });

    it("matches reference values", () => {
        expect(normalCdf(1)).toBeCloseTo(0.8413447461, 6);
        expect(normalCdf(-1)).toBeCloseTo(0.1586552539, 6);
        expect(normalCdf(1.96)).toBeCloseTo(0.9750021049, 5);
    });

    it("respects mean and sd", () => {
        expect(normalCdf(105, 100, 5)).toBeCloseTo(normalCdf(1), 6);
    });

    it("throws on non-positive sd", () => {
        expect(() => normalCdf(0, 0, 0)).toThrow();
        expect(() => normalCdf(0, 0, -1)).toThrow();
    });
});
