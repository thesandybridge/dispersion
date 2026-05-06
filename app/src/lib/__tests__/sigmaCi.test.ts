import { describe, expect, it } from "vitest";
import { sampleSdCi } from "../sigma";

describe("sampleSdCi", () => {
    it("returns zero half-width for n < 3", () => {
        expect(sampleSdCi([1, 2]).halfWidth).toBe(0);
        expect(sampleSdCi([5]).halfWidth).toBe(0);
        expect(sampleSdCi([]).halfWidth).toBe(0);
    });

    it("brackets the sample sd between lower and upper", () => {
        const ci = sampleSdCi([2, 4, 4, 4, 5, 5, 7, 9]);
        expect(ci.lower).toBeLessThan(ci.sd);
        expect(ci.upper).toBeGreaterThan(ci.sd);
        expect(ci.n).toBe(8);
    });

    it("interval shrinks as n grows", () => {
        const small = sampleSdCi([1, 2, 3, 4, 5]);
        const large = sampleSdCi(
            Array.from({ length: 50 }, (_, i) => (i % 5) + 1),
        );
        expect(large.halfWidth).toBeLessThan(small.halfWidth);
    });

    it("matches reference: n=10, sd=2 → roughly ±0.7y at 95%", () => {
        // 10 samples with sd ≈ 2, using known-stable values
        const xs = [-3, -2, -1, -0.5, 0.5, 1, 1.5, 2, 2.5, 3];
        const ci = sampleSdCi(xs);
        // Wilson-Hilferty for n=10 gives a half-width around 0.6-1.0 at 95%
        expect(ci.halfWidth).toBeGreaterThan(0.4);
        expect(ci.halfWidth).toBeLessThan(1.5);
    });
});
