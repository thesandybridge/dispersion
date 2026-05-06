import type { ShotOutcomeTag, ShotRow } from "../types";
import { encodeOutcome } from "../lib/outcomes";
import { dbExecute, dbSelect } from "./client";

type Row = {
    id: string;
    session_id: string;
    club_id: string;
    target_distance_yards: number;
    long_delta: number;
    lat_delta: number;
    outcome: string | null;
    timestamp: number;
};

function rowToShot(r: Row): ShotRow {
    return {
        id: r.id,
        sessionId: r.session_id,
        clubId: r.club_id,
        targetDistanceYards: r.target_distance_yards,
        longDelta: r.long_delta,
        latDelta: r.lat_delta,
        outcome: r.outcome,
        timestamp: new Date(r.timestamp),
    };
}

export async function createShot(input: {
    id: string;
    sessionId: string;
    clubId: string;
    targetDistanceYards: number;
    longDelta: number;
    latDelta: number;
    outcomes?: ShotOutcomeTag[];
}): Promise<ShotRow> {
    const timestamp = Date.now();
    const outcome = encodeOutcome(input.outcomes ?? []);
    await dbExecute(
        "INSERT INTO shots (id, session_id, club_id, target_distance_yards, long_delta, lat_delta, outcome, timestamp) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)",
        [
            input.id,
            input.sessionId,
            input.clubId,
            input.targetDistanceYards,
            input.longDelta,
            input.latDelta,
            outcome,
            timestamp,
        ],
    );
    return {
        id: input.id,
        sessionId: input.sessionId,
        clubId: input.clubId,
        targetDistanceYards: input.targetDistanceYards,
        longDelta: input.longDelta,
        latDelta: input.latDelta,
        outcome,
        timestamp: new Date(timestamp),
    };
}

export async function listShotsBySession(
    sessionId: string,
): Promise<ShotRow[]> {
    const rows = await dbSelect<Row[]>(
        "SELECT id, session_id, club_id, target_distance_yards, long_delta, lat_delta, outcome, timestamp FROM shots WHERE session_id = $1 ORDER BY timestamp ASC",
        [sessionId],
    );
    return rows.map(rowToShot);
}

export async function listShotsByClub(
    clubId: string,
    limit = 200,
): Promise<ShotRow[]> {
    const rows = await dbSelect<Row[]>(
        "SELECT id, session_id, club_id, target_distance_yards, long_delta, lat_delta, outcome, timestamp FROM shots WHERE club_id = $1 ORDER BY timestamp DESC LIMIT $2",
        [clubId, limit],
    );
    return rows.map(rowToShot);
}

export async function shotCounts(): Promise<{
    total: number;
    last30Days: number;
}> {
    const cutoff = Date.now() - 30 * 24 * 60 * 60 * 1000;
    const total = await dbSelect<Array<{ n: number }>>(
        "SELECT COUNT(*) as n FROM shots",
    );
    const recent = await dbSelect<Array<{ n: number }>>(
        "SELECT COUNT(*) as n FROM shots WHERE timestamp >= $1",
        [cutoff],
    );
    return {
        total: total[0]?.n ?? 0,
        last30Days: recent[0]?.n ?? 0,
    };
}

export async function deleteShot(id: string): Promise<void> {
    await dbExecute("DELETE FROM shots WHERE id = $1", [id]);
}

export async function deleteAllShots(): Promise<void> {
    await dbExecute("DELETE FROM shots", []);
}
