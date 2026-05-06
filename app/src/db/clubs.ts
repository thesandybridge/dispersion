import type { Club, NewClub } from "../types";
import { dbExecute, dbSelect } from "./client";

type ClubRow = {
    id: string;
    name: string;
    carry_yards: number;
    carry_sd: number;
    lateral_sd: number;
    created_at: number;
};

function rowToClub(row: ClubRow): Club {
    return {
        id: row.id,
        name: row.name,
        carryYards: row.carry_yards,
        carrySd: row.carry_sd,
        lateralSd: row.lateral_sd,
        createdAt: new Date(row.created_at),
    };
}

export async function listClubs(): Promise<Club[]> {
    const rows = await dbSelect<ClubRow[]>(
        "SELECT id, name, carry_yards, carry_sd, lateral_sd, created_at FROM clubs ORDER BY carry_yards DESC",
    );
    return rows.map(rowToClub);
}

export async function createClub(input: Omit<NewClub, "createdAt">): Promise<Club> {
    const createdAt = Date.now();
    await dbExecute(
        "INSERT INTO clubs (id, name, carry_yards, carry_sd, lateral_sd, created_at) VALUES ($1, $2, $3, $4, $5, $6)",
        [
            input.id,
            input.name,
            input.carryYards,
            input.carrySd,
            input.lateralSd,
            createdAt,
        ],
    );
    return {
        id: input.id,
        name: input.name,
        carryYards: input.carryYards,
        carrySd: input.carrySd,
        lateralSd: input.lateralSd,
        createdAt: new Date(createdAt),
    };
}

export async function updateClub(
    id: string,
    patch: Pick<Club, "name" | "carryYards" | "carrySd" | "lateralSd">,
): Promise<void> {
    await dbExecute(
        "UPDATE clubs SET name = $1, carry_yards = $2, carry_sd = $3, lateral_sd = $4 WHERE id = $5",
        [patch.name, patch.carryYards, patch.carrySd, patch.lateralSd, id],
    );
}

export async function deleteClub(id: string): Promise<void> {
    await dbExecute("DELETE FROM face_strikes WHERE club_id = $1", [id]);
    await dbExecute("DELETE FROM shots WHERE club_id = $1", [id]);
    await dbExecute("DELETE FROM clubs WHERE id = $1", [id]);
}

export async function deleteAllClubs(): Promise<void> {
    await dbExecute("DELETE FROM face_strikes", []);
    await dbExecute("DELETE FROM shots", []);
    await dbExecute("DELETE FROM sessions", []);
    await dbExecute("DELETE FROM clubs", []);
}
