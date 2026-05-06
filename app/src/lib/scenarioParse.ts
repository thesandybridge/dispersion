export const MAX_DISTANCE = 1_000;
export const MAX_ZONE = 500;
export const MAX_OFFSET = 500;

export function clamp(n: number, min: number, max: number): number {
    return Math.min(max, Math.max(min, n));
}

export function parsePositive(
    v: unknown,
    fallback: number,
    max = MAX_ZONE,
): number {
    const n = Number(v);
    if (!Number.isFinite(n) || n <= 0) return fallback;
    return clamp(n, Number.MIN_VALUE, max);
}

export function parseFinite(
    v: unknown,
    fallback: number,
    max = MAX_OFFSET,
): number {
    const n = Number(v);
    if (!Number.isFinite(n)) return fallback;
    return clamp(n, -max, max);
}
