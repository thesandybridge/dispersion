export function mean(values: number[]): number {
    if (values.length === 0) return 0;
    let sum = 0;
    for (const v of values) sum += v;
    return sum / values.length;
}

export function sampleSd(values: number[]): number {
    const n = values.length;
    if (n < 2) return 0;
    const m = mean(values);
    let sq = 0;
    for (const v of values) {
        const d = v - m;
        sq += d * d;
    }
    return Math.sqrt(sq / (n - 1));
}

export type ShotXY = { lat: number; long: number };

export function dispersionFromShots(shots: ShotXY[]): {
    carrySd: number;
    lateralSd: number;
    longBias: number;
    latBias: number;
    n: number;
} {
    const longs = shots.map((s) => s.long);
    const lats = shots.map((s) => s.lat);
    return {
        carrySd: sampleSd(longs),
        lateralSd: sampleSd(lats),
        longBias: mean(longs),
        latBias: mean(lats),
        n: shots.length,
    };
}

// Wilson–Hilferty χ² quantile approximation: χ²(p, k) ≈ k * (1 - 2/(9k) + z * sqrt(2/(9k)))^3
function chiSqQuantile(p: number, k: number): number {
    if (k <= 0) return 0;
    const z = inverseStdNormal(p);
    const a = 2 / (9 * k);
    const inner = 1 - a + z * Math.sqrt(a);
    return Math.max(0, k * inner * inner * inner);
}

// Beasley–Springer–Moro inverse normal CDF (good to ~7 decimal places)
function inverseStdNormal(p: number): number {
    if (p <= 0 || p >= 1) {
        if (p === 0.5) return 0;
        if (p <= 0) return -Infinity;
        return Infinity;
    }
    const a = [
        -3.969683028665376e1, 2.209460984245205e2, -2.759285104469687e2,
        1.38357751867269e2, -3.066479806614716e1, 2.506628277459239,
    ];
    const b = [
        -5.447609879822406e1, 1.615858368580409e2, -1.556989798598866e2,
        6.680131188771972e1, -1.328068155288572e1,
    ];
    const c = [
        -7.784894002430293e-3, -3.223964580411365e-1,
        -2.400758277161838, -2.549732539343734, 4.374664141464968,
        2.938163982698783,
    ];
    const d = [
        7.784695709041462e-3, 3.224671290700398e-1,
        2.445134137142996, 3.754408661907416,
    ];
    const pLow = 0.02425;
    const pHigh = 1 - pLow;
    let q: number;
    let r: number;
    if (p < pLow) {
        q = Math.sqrt(-2 * Math.log(p));
        return (
            (((((c[0]! * q + c[1]!) * q + c[2]!) * q + c[3]!) * q + c[4]!) *
                q +
                c[5]!) /
            ((((d[0]! * q + d[1]!) * q + d[2]!) * q + d[3]!) * q + 1)
        );
    } else if (p <= pHigh) {
        q = p - 0.5;
        r = q * q;
        return (
            ((((((a[0]! * r + a[1]!) * r + a[2]!) * r + a[3]!) * r + a[4]!) *
                r +
                a[5]!) *
                q) /
            (((((b[0]! * r + b[1]!) * r + b[2]!) * r + b[3]!) * r + b[4]!) *
                r +
                1)
        );
    } else {
        q = Math.sqrt(-2 * Math.log(1 - p));
        return -(
            (((((c[0]! * q + c[1]!) * q + c[2]!) * q + c[3]!) * q + c[4]!) *
                q +
                c[5]!) /
            ((((d[0]! * q + d[1]!) * q + d[2]!) * q + d[3]!) * q + 1)
        );
    }
}

export type SdInterval = {
    sd: number;
    lower: number;
    upper: number;
    halfWidth: number;
    n: number;
};

export function sampleSdCi(values: number[], confidence = 0.95): SdInterval {
    const n = values.length;
    const sd = sampleSd(values);
    if (n < 3) {
        return { sd, lower: sd, upper: sd, halfWidth: 0, n };
    }
    const k = n - 1;
    const alpha = 1 - confidence;
    const chiHigh = chiSqQuantile(1 - alpha / 2, k);
    const chiLow = chiSqQuantile(alpha / 2, k);
    const lower = chiHigh > 0 ? sd * Math.sqrt(k / chiHigh) : sd;
    const upper = chiLow > 0 ? sd * Math.sqrt(k / chiLow) : sd;
    return { sd, lower, upper, halfWidth: (upper - lower) / 2, n };
}
