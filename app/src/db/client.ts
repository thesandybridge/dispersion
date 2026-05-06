import Database from "@tauri-apps/plugin-sql";

let dbPromise: Promise<Database> | null = null;

export function getDb(): Promise<Database> {
    if (!dbPromise) {
        dbPromise = Database.load("sqlite:dispersion.db").catch((err) => {
            console.error("[db] failed to load sqlite:dispersion.db", err);
            dbPromise = null;
            throw err;
        });
    }
    return dbPromise;
}

export async function dbExecute(
    sql: string,
    params: unknown[],
): Promise<void> {
    const db = await getDb();
    try {
        await db.execute(sql, params);
    } catch (err) {
        console.error("[db.execute] failed", { sql, params, err });
        throw err;
    }
}

export async function dbSelect<T>(
    sql: string,
    params: unknown[] = [],
): Promise<T> {
    const db = await getDb();
    try {
        return await db.select<T>(sql, params);
    } catch (err) {
        console.error("[db.select] failed", { sql, params, err });
        throw err;
    }
}
