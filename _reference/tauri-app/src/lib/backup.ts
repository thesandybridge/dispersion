import type { Club, NewClub, ShotRow, SessionRow } from "../types";

export type BackupV1 = {
    version: 1;
    exportedAt: string;
    clubs: Array<{
        id: string;
        name: string;
        carryYards: number;
        carrySd: number;
        lateralSd: number;
        createdAt: string;
    }>;
};

export type BackupV2 = {
    version: 2;
    exportedAt: string;
    clubs: BackupV1["clubs"];
    sessions: Array<{
        id: string;
        kind: string;
        label: string;
        startedAt: string;
    }>;
    shots: Array<{
        id: string;
        sessionId: string;
        clubId: string;
        targetDistanceYards: number;
        longDelta: number;
        latDelta: number;
        outcome: string | null;
        timestamp: string;
    }>;
};

export type AnyBackup = BackupV1 | BackupV2;

export function buildBackup(
    clubs: Club[],
    sessions: SessionRow[] = [],
    shots: ShotRow[] = [],
): BackupV2 {
    return {
        version: 2,
        exportedAt: new Date().toISOString(),
        clubs: clubs.map((c) => ({
            id: c.id,
            name: c.name,
            carryYards: c.carryYards,
            carrySd: c.carrySd,
            lateralSd: c.lateralSd,
            createdAt: c.createdAt.toISOString(),
        })),
        sessions: sessions.map((s) => ({
            id: s.id,
            kind: s.kind,
            label: s.label,
            startedAt: s.startedAt.toISOString(),
        })),
        shots: shots.map((s) => ({
            id: s.id,
            sessionId: s.sessionId,
            clubId: s.clubId,
            targetDistanceYards: s.targetDistanceYards,
            longDelta: s.longDelta,
            latDelta: s.latDelta,
            outcome: s.outcome,
            timestamp: s.timestamp.toISOString(),
        })),
    };
}

export function parseBackup(text: string): BackupV2 {
    let raw: unknown;
    try {
        raw = JSON.parse(text);
    } catch {
        throw new Error("Not valid JSON");
    }
    if (typeof raw !== "object" || raw === null) {
        throw new Error("Expected an object");
    }
    const obj = raw as Record<string, unknown>;
    const version = obj.version;
    if (version !== 1 && version !== 2) {
        throw new Error(`Unsupported backup version: ${String(version)}`);
    }
    if (!Array.isArray(obj.clubs)) {
        throw new Error("Missing clubs array");
    }
    const clubs = obj.clubs.map((c, i) => parseClub(c, i));
    const sessions =
        version === 2 && Array.isArray(obj.sessions)
            ? obj.sessions.map((s, i) => parseSession(s, i))
            : [];
    const shots =
        version === 2 && Array.isArray(obj.shots)
            ? obj.shots.map((s, i) => parseShot(s, i))
            : [];
    return {
        version: 2,
        exportedAt: typeof obj.exportedAt === "string" ? obj.exportedAt : "",
        clubs,
        sessions,
        shots,
    };
}

function parseClub(raw: unknown, i: number): BackupV1["clubs"][number] {
    if (typeof raw !== "object" || raw === null)
        throw new Error(`clubs[${i}]: not an object`);
    const c = raw as Record<string, unknown>;
    const required = [
        "id",
        "name",
        "carryYards",
        "carrySd",
        "lateralSd",
        "createdAt",
    ] as const;
    for (const k of required) {
        if (!(k in c)) throw new Error(`clubs[${i}]: missing ${k}`);
    }
    if (typeof c.id !== "string" || typeof c.name !== "string")
        throw new Error(`clubs[${i}]: id/name must be strings`);
    for (const k of ["carryYards", "carrySd", "lateralSd"] as const) {
        if (typeof c[k] !== "number" || !Number.isFinite(c[k]))
            throw new Error(`clubs[${i}]: ${k} must be a finite number`);
    }
    if (typeof c.createdAt !== "string")
        throw new Error(`clubs[${i}]: createdAt must be a string`);
    return {
        id: c.id,
        name: c.name,
        carryYards: c.carryYards as number,
        carrySd: c.carrySd as number,
        lateralSd: c.lateralSd as number,
        createdAt: c.createdAt,
    };
}

function parseSession(raw: unknown, i: number): BackupV2["sessions"][number] {
    if (typeof raw !== "object" || raw === null)
        throw new Error(`sessions[${i}]: not an object`);
    const s = raw as Record<string, unknown>;
    if (typeof s.id !== "string" || typeof s.kind !== "string" || typeof s.label !== "string")
        throw new Error(`sessions[${i}]: id/kind/label must be strings`);
    if (typeof s.startedAt !== "string")
        throw new Error(`sessions[${i}]: startedAt must be a string`);
    return {
        id: s.id,
        kind: s.kind,
        label: s.label,
        startedAt: s.startedAt,
    };
}

function parseShot(raw: unknown, i: number): BackupV2["shots"][number] {
    if (typeof raw !== "object" || raw === null)
        throw new Error(`shots[${i}]: not an object`);
    const s = raw as Record<string, unknown>;
    if (
        typeof s.id !== "string" ||
        typeof s.sessionId !== "string" ||
        typeof s.clubId !== "string"
    )
        throw new Error(`shots[${i}]: id/sessionId/clubId must be strings`);
    for (const k of [
        "targetDistanceYards",
        "longDelta",
        "latDelta",
    ] as const) {
        if (typeof s[k] !== "number" || !Number.isFinite(s[k]))
            throw new Error(`shots[${i}]: ${k} must be a finite number`);
    }
    if (typeof s.timestamp !== "string")
        throw new Error(`shots[${i}]: timestamp must be a string`);
    return {
        id: s.id,
        sessionId: s.sessionId,
        clubId: s.clubId,
        targetDistanceYards: s.targetDistanceYards as number,
        longDelta: s.longDelta as number,
        latDelta: s.latDelta as number,
        outcome: typeof s.outcome === "string" ? s.outcome : null,
        timestamp: s.timestamp,
    };
}

export function backupToNewClubs(backup: AnyBackup): NewClub[] {
    return backup.clubs.map((c) => ({
        id: c.id,
        name: c.name,
        carryYards: c.carryYards,
        carrySd: c.carrySd,
        lateralSd: c.lateralSd,
        createdAt: new Date(c.createdAt),
    }));
}
