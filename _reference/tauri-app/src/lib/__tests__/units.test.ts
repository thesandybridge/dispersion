import { describe, expect, it } from "vitest";
import {
    formatDistance,
    fromYards,
    toYards,
    unitLabel,
} from "../units";

describe("units", () => {
    it("identity for yards", () => {
        expect(fromYards(150, "yards")).toBe(150);
        expect(toYards(150, "yards")).toBe(150);
    });

    it("yards <-> meters roundtrip", () => {
        for (const yd of [10, 50, 150, 300]) {
            const m = fromYards(yd, "meters");
            expect(toYards(m, "meters")).toBeCloseTo(yd, 9);
        }
    });

    it("uses standard yard = 0.9144 m", () => {
        expect(fromYards(1, "meters")).toBeCloseTo(0.9144, 6);
        expect(toYards(1, "meters")).toBeCloseTo(1 / 0.9144, 6);
    });

    it("formatDistance produces unit suffix", () => {
        expect(formatDistance(100, "yards", 0)).toBe("100 yd");
        expect(formatDistance(100, "meters", 1)).toBe("91.4 m");
    });

    it("unitLabel short and long", () => {
        expect(unitLabel("yards")).toBe("yd");
        expect(unitLabel("yards", false)).toBe("yards");
        expect(unitLabel("meters", false)).toBe("meters");
    });
});
