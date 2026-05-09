// Type definitions mirroring iOS Models.swift. Kept narrow — the web demo
// only needs Club, ShotScenario, and ClubResult.

export interface Club {
  id: string;
  name: string;
  carryYards: number;
  carrySd: number;
  lateralSd: number;
}

export interface ShotScenario {
  distanceToTargetYards: number;
  safeZoneWidthYards: number;
  safeZoneDepthYards: number;
  /// Lateral aim offset in yards. Positive = aiming right of target.
  aimLateralYards?: number;
}

export interface ClubResult {
  clubId: string;
  probabilityInZone: number;
  expectedCarry: number;
}
