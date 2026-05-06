export type {
    Club,
    NewClub,
    SessionRow,
    NewSession,
    SessionKind,
    ShotRow,
    NewShot,
    ShotOutcome,
    ShotOutcomeTag,
    FaceStrikeRow,
    NewFaceStrike,
    TestClub,
    NewTestClub,
} from "./db/schema";

export type Zone = {
    widthYards: number;
    depthYards: number;
};

export type ShotScenario = {
    distanceToTargetYards: number;
    safeZone: Zone;
    penaltyZones: Zone[];
};

export type ClubResult = {
    clubId: string;
    probabilityInZone: number;
    expectedDistance: number;
};
