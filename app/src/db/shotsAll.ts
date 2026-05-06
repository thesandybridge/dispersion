import type { ShotRow } from "../types";
import { dbSelect } from "./client";

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

export async function listAllShots(limit = 5000): Promise<ShotRow[]> {
    const rows = await dbSelect<Row[]>(
        "SELECT id, session_id, club_id, target_distance_yards, long_delta, lat_delta, outcome, timestamp FROM shots ORDER BY timestamp DESC LIMIT $1",
        [limit],
    );
    return rows.map(rowToShot);
}
