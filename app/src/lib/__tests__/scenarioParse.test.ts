import { describe, expect, it } from "vitest";
import {
    MAX_DISTANCE,
    MAX_OFFSET,
    MAX_ZONE,
    clamp,
    parseFinite,
    parsePositive,
} from "../scenarioParse";

describe("clamp", () => {
    it("respects bounds", () => {
        expect(clamp(5, 0, 10)).toBe(5);
        expect(clamp(-1, 0, 10)).toBe(0);
        expect(clamp(99, 0, 10)).toBe(10);
    });
});

describe("parsePositive", () => {
    it("falls back on non-numbers and non-positives", () => {
        expect(parsePositive("abc", 100)).toBe(100);
        expect(parsePositive(0, 100)).toBe(100);
        expect(parsePositive(-5, 100)).toBe(100);
        expect(parsePositive(NaN, 100)).toBe(100);
    });
    it("clamps to max", () => {
        expect(parsePositive(99999, 100, 200)).toBe(200);
        expect(parsePositive(50, 100, 200)).toBe(50);
    });
    it("default max is MAX_ZONE", () => {
        expect(parsePositive(MAX_ZONE + 100, 1)).toBe(MAX_ZONE);
    });
});

describe("parseFinite", () => {
    it("falls back on non-numbers", () => {
        expect(parseFinite("abc", 5)).toBe(5);
        expect(parseFinite(NaN, 5)).toBe(5);
    });
    it("allows zero and negatives", () => {
        expect(parseFinite(0, 5)).toBe(0);
        expect(parseFinite(-3, 5)).toBe(-3);
    });
    it("clamps within ±max", () => {
        expect(parseFinite(99999, 0, 100)).toBe(100);
        expect(parseFinite(-99999, 0, 100)).toBe(-100);
    });
    it("default max is MAX_OFFSET", () => {
        expect(parseFinite(MAX_OFFSET + 50, 0)).toBe(MAX_OFFSET);
    });
});

describe("MAX_DISTANCE constant", () => {
    it("is reasonable for golf yardages", () => {
        expect(MAX_DISTANCE).toBeGreaterThanOrEqual(500);
    });
});
