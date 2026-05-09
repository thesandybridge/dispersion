// Pure math helpers — port of iOS Sigma.swift. Sample mean + sample stddev
// for a small set of (x, y) shot points. The web demo doesn't need the
// "fit a distribution to logged shots" path, but the helper is here for
// completeness and parity with the iOS algorithm.

export interface ShotXY {
  lat: number;
  long: number;
}

export interface DispersionStats {
  carrySd: number;
  lateralSd: number;
  longBias: number;
  latBias: number;
  n: number;
}

export const EMPTY_DISPERSION: DispersionStats = {
  carrySd: 0,
  lateralSd: 0,
  longBias: 0,
  latBias: 0,
  n: 0,
};

/// Sample mean + sample stddev (n-1 denominator) for a small set of shots.
export function dispersionFromShots(shots: ShotXY[]): DispersionStats {
  const n = shots.length;
  if (n < 1) return EMPTY_DISPERSION;

  const sumLong = shots.reduce((a, s) => a + s.long, 0);
  const sumLat = shots.reduce((a, s) => a + s.lat, 0);
  const meanLong = sumLong / n;
  const meanLat = sumLat / n;

  if (n < 2) {
    return {
      carrySd: 0,
      lateralSd: 0,
      longBias: meanLong,
      latBias: meanLat,
      n,
    };
  }

  let longSqSum = 0;
  let latSqSum = 0;
  for (const s of shots) {
    longSqSum += (s.long - meanLong) ** 2;
    latSqSum += (s.lat - meanLat) ** 2;
  }
  const carrySd = Math.sqrt(longSqSum / (n - 1));
  const lateralSd = Math.sqrt(latSqSum / (n - 1));
  return {
    carrySd,
    lateralSd,
    longBias: meanLong,
    latBias: meanLat,
    n,
  };
}
