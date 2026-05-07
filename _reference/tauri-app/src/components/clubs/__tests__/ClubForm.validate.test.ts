import { describe, expect, it } from "vitest";
import { validate } from "../ClubForm";

const ok = { name: "7 Iron", carryYards: "165", carrySd: "5", lateralSd: "6" };

describe("ClubForm validate", () => {
    it("accepts valid input and trims name", () => {
        const r = validate({ ...ok, name: "  7 Iron  " });
        expect(r.errors).toEqual({});
        expect(r.parsed?.name).toBe("7 Iron");
        expect(r.parsed?.carryYards).toBe(165);
    });

    it("rejects empty name", () => {
        const r = validate({ ...ok, name: "" });
        expect(r.errors.name).toBeDefined();
        expect(r.parsed).toBeUndefined();
    });

    it("rejects name over 60 chars", () => {
        const r = validate({ ...ok, name: "a".repeat(61) });
        expect(r.errors.name).toMatch(/60/);
    });

    it("rejects non-positive carry", () => {
        expect(validate({ ...ok, carryYards: "0" }).errors.carryYards).toBeDefined();
        expect(validate({ ...ok, carryYards: "-5" }).errors.carryYards).toBeDefined();
        expect(validate({ ...ok, carryYards: "abc" }).errors.carryYards).toBeDefined();
    });

    it("rejects carry over 500", () => {
        const r = validate({ ...ok, carryYards: "501" });
        expect(r.errors.carryYards).toMatch(/500/);
    });

    it("rejects non-positive sd", () => {
        expect(validate({ ...ok, carrySd: "0" }).errors.carrySd).toBeDefined();
        expect(validate({ ...ok, lateralSd: "-1" }).errors.lateralSd).toBeDefined();
    });

    it("rejects sd over 100", () => {
        expect(validate({ ...ok, carrySd: "101" }).errors.carrySd).toMatch(/100/);
        expect(validate({ ...ok, lateralSd: "200" }).errors.lateralSd).toMatch(/100/);
    });
});
