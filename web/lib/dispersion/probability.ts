// Pure probability math — TypeScript port of iOS Probability.swift. The web
// demo runs the same algorithm as the iOS app so what readers see in the
// browser is what they'll get on their phone.

import type { Club, ClubResult, ShotScenario } from "./types";

/// Standard-normal CDF via Abramowitz & Stegun 26.2.17 — mirrors Swift.
export function normalCdf(x: number): number {
  // Abramowitz & Stegun rational approximation. Max error ~7.5e-8.
  const t = 1 / (1 + 0.2316419 * Math.abs(x));
  const d = 0.3989422804014327 * Math.exp(-(x * x) / 2);
  let p =
    d *
    t *
    (0.31938153 +
      t *
        (-0.356563782 +
          t * (1.781477937 + t * (-1.821255978 + t * 1.330274429))));
  if (x > 0) p = 1 - p;
  return p;
}

/// Probability that a single Gaussian-distributed value falls within [lo, hi].
export function gaussianBand(
  mean: number,
  sd: number,
  lo: number,
  hi: number
): number {
  if (sd <= 0) {
    // Degenerate case: it's all at the mean. Return 1 if mean ∈ [lo, hi].
    return mean >= lo && mean <= hi ? 1 : 0;
  }
  const z1 = (lo - mean) / sd;
  const z2 = (hi - mean) / sd;
  return Math.max(0, normalCdf(z2) - normalCdf(z1));
}

/// Probability the shot lands inside the safe zone, applying the DECADE
/// short-side penalty when the club's expected carry is short of target.
export function probabilityInZone(
  club: Club,
  scenario: ShotScenario,
  shortSideBias = 0.08
): number {
  const longLo = -scenario.safeZoneDepthYards / 2;
  const longHi = scenario.safeZoneDepthYards / 2;
  const latLo = -scenario.safeZoneWidthYards / 2;
  const latHi = scenario.safeZoneWidthYards / 2;

  const meanLong = club.carryYards - scenario.distanceToTargetYards;
  const meanLat = scenario.aimLateralYards ?? 0;

  const pLong = gaussianBand(meanLong, club.carrySd, longLo, longHi);
  const pLat = gaussianBand(meanLat, club.lateralSd, latLo, latHi);
  let p = pLong * pLat;

  if (meanLong < 0 && shortSideBias > 0) {
    const shortness = Math.abs(meanLong);
    const penalty = Math.exp(-shortSideBias * shortness);
    p *= penalty;
  }
  return p;
}

/// Rank a bag against a scenario by descending probability-in-zone.
export function rankClubs(
  clubs: Club[],
  scenario: ShotScenario,
  shortSideBias = 0.08
): ClubResult[] {
  return clubs
    .map((club) => ({
      clubId: club.id,
      probabilityInZone: probabilityInZone(club, scenario, shortSideBias),
      expectedCarry: club.carryYards,
    }))
    .sort((a, b) => b.probabilityInZone - a.probabilityInZone);
}

/// Convenience: human-friendly probability label, matching iOS ProbLabelRegistry.
export function probLabel(p: number): {
  label: "Strong" | "Favored" | "Marginal" | "Poor";
  color: string;
} {
  if (p >= 0.85) return { label: "Strong", color: "#62b375" };
  if (p >= 0.65) return { label: "Favored", color: "#a9d18e" };
  if (p >= 0.4) return { label: "Marginal", color: "#e6c068" };
  return { label: "Poor", color: "#c87060" };
}
