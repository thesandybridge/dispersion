import { sqliteTable, text, real, integer } from "drizzle-orm/sqlite-core";

export const clubs = sqliteTable("clubs", {
    id: text("id").primaryKey(),
    name: text("name").notNull(),
    carryYards: real("carry_yards").notNull(),
    carrySd: real("carry_sd").notNull(),
    lateralSd: real("lateral_sd").notNull(),
    createdAt: integer("created_at", { mode: "timestamp_ms" }).notNull(),
});

export type Club = typeof clubs.$inferSelect;
export type NewClub = typeof clubs.$inferInsert;

export const sessions = sqliteTable("sessions", {
    id: text("id").primaryKey(),
    kind: text("kind").notNull(),
    label: text("label").notNull(),
    startedAt: integer("started_at", { mode: "timestamp_ms" }).notNull(),
});

export type SessionRow = typeof sessions.$inferSelect;
export type NewSession = typeof sessions.$inferInsert;
export type SessionKind = "range" | "round";

export const shots = sqliteTable("shots", {
    id: text("id").primaryKey(),
    sessionId: text("session_id").notNull(),
    clubId: text("club_id").notNull(),
    targetDistanceYards: real("target_distance_yards").notNull(),
    longDelta: real("long_delta").notNull(),
    latDelta: real("lat_delta").notNull(),
    outcome: text("outcome"),
    timestamp: integer("timestamp", { mode: "timestamp_ms" }).notNull(),
});

export type ShotRow = typeof shots.$inferSelect;
export type NewShot = typeof shots.$inferInsert;

export const testClubs = sqliteTable("test_clubs", {
    id: text("id").primaryKey(),
    name: text("name").notNull(),
    carryYards: real("carry_yards").notNull(),
    carrySd: real("carry_sd").notNull(),
    lateralSd: real("lateral_sd").notNull(),
    source: text("source").notNull().default(""),
    createdAt: integer("created_at", { mode: "timestamp_ms" }).notNull(),
});

export type TestClub = typeof testClubs.$inferSelect;
export type NewTestClub = typeof testClubs.$inferInsert;

export const faceStrikes = sqliteTable("face_strikes", {
    id: text("id").primaryKey(),
    clubId: text("club_id").notNull(),
    x: real("x").notNull(),
    y: real("y").notNull(),
    note: text("note").notNull().default(""),
    sessionId: text("session_id"),
    shotId: text("shot_id"),
    timestamp: integer("timestamp", { mode: "timestamp_ms" }).notNull(),
});

export type FaceStrikeRow = typeof faceStrikes.$inferSelect;
export type NewFaceStrike = typeof faceStrikes.$inferInsert;
export type ShotOutcomeTag =
    | "in"
    | "short"
    | "long"
    | "left"
    | "right"
    | "penalty";
export type ShotOutcome = ShotOutcomeTag;
