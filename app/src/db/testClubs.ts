import type { TestClub } from "../types";
import { dbExecute, dbSelect } from "./client";

type Row = {
    id: string;
    name: string;
    carry_yards: number;
    carry_sd: number;
    lateral_sd: number;
    source: string;
    created_at: number;
};

function rowToClub(r: Row): TestClub {
    return {
        id: r.id,
        name: r.name,
        carryYards: r.carry_yards,
        carrySd: r.carry_sd,
        lateralSd: r.lateral_sd,
        source: r.source,
        createdAt: new Date(r.created_at),
    };
}

export async function listTestClubs(): Promise<TestClub[]> {
    const rows = await dbSelect<Row[]>(
        "SELECT id, name, carry_yards, carry_sd, lateral_sd, source, created_at FROM test_clubs ORDER BY created_at DESC",
    );
    return rows.map(rowToClub);
}

export async function createTestClub(input: {
    id: string;
    name: string;
    carryYards: number;
    carrySd: number;
    lateralSd: number;
    source?: string;
}): Promise<TestClub> {
    const createdAt = Date.now();
    await dbExecute(
        "INSERT INTO test_clubs (id, name, carry_yards, carry_sd, lateral_sd, source, created_at) VALUES ($1, $2, $3, $4, $5, $6, $7)",
        [
            input.id,
            input.name,
            input.carryYards,
            input.carrySd,
            input.lateralSd,
            input.source ?? "",
            createdAt,
        ],
    );
    return {
        id: input.id,
        name: input.name,
        carryYards: input.carryYards,
        carrySd: input.carrySd,
        lateralSd: input.lateralSd,
        source: input.source ?? "",
        createdAt: new Date(createdAt),
    };
}

export async function updateTestClub(
    id: string,
    patch: Pick<
        TestClub,
        "name" | "carryYards" | "carrySd" | "lateralSd" | "source"
    >,
): Promise<void> {
    await dbExecute(
        "UPDATE test_clubs SET name = $1, carry_yards = $2, carry_sd = $3, lateral_sd = $4, source = $5 WHERE id = $6",
        [
            patch.name,
            patch.carryYards,
            patch.carrySd,
            patch.lateralSd,
            patch.source,
            id,
        ],
    );
}

export async function deleteTestClub(id: string): Promise<void> {
    await dbExecute("DELETE FROM test_clubs WHERE id = $1", [id]);
}

export async function promoteTestClubToBag(
    testId: string,
): Promise<{ name: string; carryYards: number; carrySd: number; lateralSd: number } | null> {
    const rows = await dbSelect<Row[]>(
        "SELECT id, name, carry_yards, carry_sd, lateral_sd, source, created_at FROM test_clubs WHERE id = $1",
        [testId],
    );
    const r = rows[0];
    if (!r) return null;
    await dbExecute("DELETE FROM test_clubs WHERE id = $1", [testId]);
    return {
        name: r.name,
        carryYards: r.carry_yards,
        carrySd: r.carry_sd,
        lateralSd: r.lateral_sd,
    };
}
