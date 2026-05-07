import type { Club, ClubResult, ShotScenario, Zone } from "../types";
import { normalCdf } from "./stats";

type ZoneBounds = {
    longMin: number;
    longMax: number;
    latMin: number;
    latMax: number;
};

function zoneBounds(zone: Zone, distanceToTargetYards: number): ZoneBounds {
    return {
        longMin: distanceToTargetYards - zone.depthYards / 2,
        longMax: distanceToTargetYards + zone.depthYards / 2,
        latMin: -zone.widthYards / 2,
        latMax: zone.widthYards / 2,
    };
}

export function probabilityInZone(
    club: Club,
    scenario: ShotScenario,
): number {
    const { longMin, longMax, latMin, latMax } = zoneBounds(
        scenario.safeZone,
        scenario.distanceToTargetYards,
    );

    const longProb =
        normalCdf(longMax, club.carryYards, club.carrySd) -
        normalCdf(longMin, club.carryYards, club.carrySd);
    const latProb =
        normalCdf(latMax, 0, club.lateralSd) -
        normalCdf(latMin, 0, club.lateralSd);

    return longProb * latProb;
}

export function rankClubs(
    clubs: Club[],
    scenario: ShotScenario,
): ClubResult[] {
    return clubs
        .map((club) => ({
            clubId: club.id,
            probabilityInZone: probabilityInZone(club, scenario),
            expectedDistance: club.carryYards,
        }))
        .sort((a, b) => b.probabilityInZone - a.probabilityInZone);
}
