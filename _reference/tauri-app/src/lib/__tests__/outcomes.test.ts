import { describe, expect, it } from "vitest";
import {
    decodeOutcome,
    encodeOutcome,
    toggleTag,
} from "../outcomes";

describe("encode/decode outcomes", () => {
    it("empty -> null", () => {
        expect(encodeOutcome([])).toBeNull();
        expect(decodeOutcome(null)).toEqual([]);
    });

    it("roundtrip preserves tags", () => {
        const out = encodeOutcome(["left", "short", "penalty"]);
        expect(out).toBe("short,left,penalty");
        expect(decodeOutcome(out)).toEqual(["short", "left", "penalty"]);
    });

    it("dedupes and orders deterministically", () => {
        expect(encodeOutcome(["right", "right", "long"])).toBe("long,right");
    });

    it("rejects bogus tags on decode", () => {
        expect(decodeOutcome("nope,left,xx")).toEqual(["left"]);
    });
});

describe("toggleTag", () => {
    it("adds when missing", () => {
        expect(toggleTag([], "left")).toEqual(["left"]);
    });
    it("removes when present", () => {
        expect(toggleTag(["left", "long"], "left")).toEqual(["long"]);
    });
    it("'in' clears all and stays alone", () => {
        expect(toggleTag(["left", "long"], "in")).toEqual(["in"]);
    });
    it("adding an axis-conflict replaces the conflicting tag", () => {
        expect(toggleTag(["short"], "long")).toEqual(["long"]);
        expect(toggleTag(["left"], "right")).toEqual(["right"]);
    });
    it("adding to an 'in' set replaces it", () => {
        expect(toggleTag(["in"], "long")).toEqual(["long"]);
    });
    it("penalty co-exists with directional tags", () => {
        expect(toggleTag(["left", "long"], "penalty")).toEqual([
            "left",
            "long",
            "penalty",
        ]);
    });
});
