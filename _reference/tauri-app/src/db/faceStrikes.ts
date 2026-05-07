import type { FaceStrikeRow } from "../types";
import { dbExecute, dbSelect } from "./client";

type Row = {
    id: string;
    club_id: string;
    x: number;
    y: number;
    note: string;
    session_id: string | null;
    shot_id: string | null;
    timestamp: number;
};

function rowToStrike(r: Row): FaceStrikeRow {
    return {
        id: r.id,
        clubId: r.club_id,
        x: r.x,
        y: r.y,
        note: r.note,
        sessionId: r.session_id,
        shotId: r.shot_id,
        timestamp: new Date(r.timestamp),
    };
}

export async function createFaceStrike(input: {
    id: string;
    clubId: string;
    x: number;
    y: number;
    note: string;
    sessionId?: string | null;
    shotId?: string | null;
}): Promise<FaceStrikeRow> {
    const timestamp = Date.now();
    await dbExecute(
        "INSERT INTO face_strikes (id, club_id, x, y, note, session_id, shot_id, timestamp) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)",
        [
            input.id,
            input.clubId,
            input.x,
            input.y,
            input.note,
            input.sessionId ?? null,
            input.shotId ?? null,
            timestamp,
        ],
    );
    return {
        id: input.id,
        clubId: input.clubId,
        x: input.x,
        y: input.y,
        note: input.note,
        sessionId: input.sessionId ?? null,
        shotId: input.shotId ?? null,
        timestamp: new Date(timestamp),
    };
}

export async function listFaceStrikesByClub(
    clubId: string,
    limit = 200,
): Promise<FaceStrikeRow[]> {
    const rows = await dbSelect<Row[]>(
        "SELECT id, club_id, x, y, note, session_id, shot_id, timestamp FROM face_strikes WHERE club_id = $1 ORDER BY timestamp DESC LIMIT $2",
        [clubId, limit],
    );
    return rows.map(rowToStrike);
}

export async function deleteFaceStrike(id: string): Promise<void> {
    await dbExecute("DELETE FROM face_strikes WHERE id = $1", [id]);
}

export async function deleteFaceStrikesByClub(clubId: string): Promise<void> {
    await dbExecute("DELETE FROM face_strikes WHERE club_id = $1", [clubId]);
}

export async function deleteAllFaceStrikes(): Promise<void> {
    await dbExecute("DELETE FROM face_strikes", []);
}
