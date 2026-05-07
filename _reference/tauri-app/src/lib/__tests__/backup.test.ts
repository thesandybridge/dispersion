import { describe, expect, it } from "vitest";
import { buildBackup, parseBackup } from "../backup";
import type { Club, ShotRow, SessionRow } from "../../types";

const club: Club = {
    id: "abc",
    name: "7 Iron",
    carryYards: 165,
    carrySd: 5,
    lateralSd: 6,
    createdAt: new Date("2025-01-01T00:00:00Z"),
};

const session: SessionRow = {
    id: "sess1",
    kind: "range",
    label: "Range session",
    startedAt: new Date("2025-01-02T12:00:00Z"),
};

const shot: ShotRow = {
    id: "sh1",
    sessionId: "sess1",
    clubId: "abc",
    targetDistanceYards: 165,
    longDelta: 3,
    latDelta: -2,
    outcome: "long,left",
    timestamp: new Date("2025-01-02T12:01:00Z"),
};

describe("backup roundtrip (v2)", () => {
    it("preserves clubs + sessions + shots", () => {
        const backup = buildBackup([club], [session], [shot]);
        const parsed = parseBackup(JSON.stringify(backup));
        expect(parsed.version).toBe(2);
        expect(parsed.clubs).toHaveLength(1);
        expect(parsed.sessions).toHaveLength(1);
        expect(parsed.shots).toHaveLength(1);
        expect(parsed.shots[0]).toMatchObject({
            sessionId: "sess1",
            clubId: "abc",
            longDelta: 3,
            latDelta: -2,
            outcome: "long,left",
        });
    });

    it("v1 import (clubs only) still works and produces empty sessions/shots", () => {
        const v1 = {
            version: 1,
            exportedAt: "",
            clubs: [
                {
                    id: "abc",
                    name: "7 Iron",
                    carryYards: 165,
                    carrySd: 5,
                    lateralSd: 6,
                    createdAt: "2025-01-01T00:00:00Z",
                },
            ],
        };
        const parsed = parseBackup(JSON.stringify(v1));
        expect(parsed.version).toBe(2);
        expect(parsed.clubs).toHaveLength(1);
        expect(parsed.sessions).toHaveLength(0);
        expect(parsed.shots).toHaveLength(0);
    });
});

describe("parseBackup validation", () => {
    it("rejects non-JSON", () => {
        expect(() => parseBackup("not json")).toThrow(/JSON/);
    });

    it("rejects unsupported version", () => {
        expect(() =>
            parseBackup(JSON.stringify({ version: 99, clubs: [] })),
        ).toThrow(/version/);
    });

    it("rejects missing clubs array", () => {
        expect(() => parseBackup(JSON.stringify({ version: 1 }))).toThrow(
            /clubs/,
        );
    });

    it("rejects club with non-finite number", () => {
        const bad = {
            version: 1,
            exportedAt: "",
            clubs: [
                {
                    id: "x",
                    name: "x",
                    carryYards: "nope",
                    carrySd: 5,
                    lateralSd: 5,
                    createdAt: "2025-01-01",
                },
            ],
        };
        expect(() => parseBackup(JSON.stringify(bad))).toThrow(/carryYards/);
    });

    it("rejects shot with bad number", () => {
        const bad = {
            version: 2,
            exportedAt: "",
            clubs: [],
            sessions: [],
            shots: [
                {
                    id: "x",
                    sessionId: "s",
                    clubId: "c",
                    targetDistanceYards: "x",
                    longDelta: 0,
                    latDelta: 0,
                    timestamp: "2025-01-01",
                },
            ],
        };
        expect(() => parseBackup(JSON.stringify(bad))).toThrow(
            /targetDistanceYards/,
        );
    });
});
