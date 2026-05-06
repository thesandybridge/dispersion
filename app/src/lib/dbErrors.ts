export function describeDbError(err: unknown): string {
    const msg = err instanceof Error ? err.message : String(err);
    if (/no such table/i.test(msg)) {
        return `${msg} — restart \`pnpm tauri dev\` so migrations re-run`;
    }
    return msg;
}
