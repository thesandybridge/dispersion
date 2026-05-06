import type { SessionKind, SessionRow } from "../types";
import { dbExecute, dbSelect } from "./client";

type Row = {
    id: string;
    kind: string;
    label: string;
    started_at: number;
};

function rowToSession(r: Row): SessionRow {
    return {
        id: r.id,
        kind: r.kind,
        label: r.label,
        startedAt: new Date(r.started_at),
    };
}

export async function createSession(input: {
    id: string;
    kind: SessionKind;
    label: string;
}): Promise<SessionRow> {
    const startedAt = Date.now();
    await dbExecute(
        "INSERT INTO sessions (id, kind, label, started_at) VALUES ($1, $2, $3, $4)",
        [input.id, input.kind, input.label, startedAt],
    );
    return {
        id: input.id,
        kind: input.kind,
        label: input.label,
        startedAt: new Date(startedAt),
    };
}

export async function listSessions(limit = 100): Promise<SessionRow[]> {
    const rows = await dbSelect<Row[]>(
        "SELECT id, kind, label, started_at FROM sessions ORDER BY started_at DESC LIMIT $1",
        [limit],
    );
    return rows.map(rowToSession);
}

export async function deleteSession(id: string): Promise<void> {
    await dbExecute("DELETE FROM shots WHERE session_id = $1", [id]);
    await dbExecute("DELETE FROM sessions WHERE id = $1", [id]);
}

export async function deleteAllSessions(): Promise<void> {
    await dbExecute("DELETE FROM shots", []);
    await dbExecute("DELETE FROM sessions", []);
}
