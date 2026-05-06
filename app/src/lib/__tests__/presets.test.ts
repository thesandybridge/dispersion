import { describe, expect, it } from "vitest";
import {
    DEFAULT_PRESET_ID,
    ZONE_PRESETS,
    getPreset,
} from "../presets";

describe("zone presets", () => {
    it("default preset id resolves to a real preset", () => {
        expect(getPreset(DEFAULT_PRESET_ID)).toBeDefined();
    });

    it("ids and labels are unique", () => {
        const ids = new Set<string>();
        const labels = new Set<string>();
        for (const p of ZONE_PRESETS) {
            expect(ids.has(p.id), `dup id ${p.id}`).toBe(false);
            expect(labels.has(p.label), `dup label ${p.label}`).toBe(false);
            ids.add(p.id);
            labels.add(p.label);
        }
    });

    it("all dimensions are positive yards", () => {
        for (const p of ZONE_PRESETS) {
            expect(p.zone.widthYards).toBeGreaterThan(0);
            expect(p.zone.depthYards).toBeGreaterThan(0);
        }
    });

    it("getPreset returns undefined for unknown id", () => {
        expect(getPreset("nope")).toBeUndefined();
    });
});
