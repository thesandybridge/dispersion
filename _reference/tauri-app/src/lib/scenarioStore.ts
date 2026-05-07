import { create } from "zustand";
import { persist } from "zustand/middleware";
import { DEFAULT_PRESET_ID } from "./presets";

const MAX_DISTANCE = 1_000;
const MAX_ZONE = 500;

export const LIE_TYPES = [
    { id: "tee", label: "Tee", multiplier: 1.0 },
    { id: "fairway", label: "Fairway", multiplier: 1.0 },
    { id: "light-rough", label: "Light rough", multiplier: 1.25 },
    { id: "rough", label: "Rough", multiplier: 1.55 },
    { id: "sand", label: "Sand", multiplier: 1.85 },
    { id: "hardpan", label: "Hardpan", multiplier: 1.2 },
] as const;

export type LieId = (typeof LIE_TYPES)[number]["id"];

export type ScenarioState = {
    distance: number;
    width: number;
    depth: number;
    preset?: string;
    windMph: number;
    elevationFt: number;
    lie: LieId;
    minProbability: number;
    set: (patch: Partial<Omit<ScenarioState, "set">>) => void;
};

function clamp(n: number, lo: number, hi: number): number {
    return Math.min(hi, Math.max(lo, n));
}

function safe(state: Partial<ScenarioState>): Partial<ScenarioState> {
    const out: Partial<ScenarioState> = { ...state };
    if (out.distance != null) {
        out.distance = clamp(
            Number.isFinite(out.distance) ? out.distance : 168,
            1,
            MAX_DISTANCE,
        );
    }
    if (out.width != null) {
        out.width = clamp(
            Number.isFinite(out.width) && out.width > 0 ? out.width : 28,
            1,
            MAX_ZONE,
        );
    }
    if (out.depth != null) {
        out.depth = clamp(
            Number.isFinite(out.depth) && out.depth > 0 ? out.depth : 30,
            1,
            MAX_ZONE,
        );
    }
    if (out.windMph != null) {
        out.windMph = clamp(
            Number.isFinite(out.windMph) ? out.windMph : 0,
            -30,
            30,
        );
    }
    if (out.elevationFt != null) {
        out.elevationFt = clamp(
            Number.isFinite(out.elevationFt) ? out.elevationFt : 0,
            -50,
            50,
        );
    }
    if (out.minProbability != null) {
        out.minProbability = clamp(
            Number.isFinite(out.minProbability) ? out.minProbability : 0,
            0,
            0.99,
        );
    }
    return out;
}

export const useScenario = create<ScenarioState>()(
    persist(
        (set) => ({
            distance: 168,
            width: 28,
            depth: 30,
            preset: DEFAULT_PRESET_ID,
            windMph: 0,
            elevationFt: 0,
            lie: "fairway",
            minProbability: 0,
            set: (patch) => set(safe(patch)),
        }),
        {
            name: "dispersion.scenario.v4",
            partialize: (s) => ({
                distance: s.distance,
                width: s.width,
                depth: s.depth,
                preset: s.preset,
                windMph: s.windMph,
                elevationFt: s.elevationFt,
                lie: s.lie,
                minProbability: s.minProbability,
            }),
        },
    ),
);

export function lieMultiplier(id: LieId): number {
    return LIE_TYPES.find((l) => l.id === id)?.multiplier ?? 1;
}

// Effective playing distance after wind + elevation.
// Convention: windMph negative = headwind, positive = tailwind.
// elevationFt positive = uphill (longer play), negative = downhill.
export function effectiveDistance(
    distance: number,
    windMph: number,
    elevationFt: number,
): number {
    const tailAdjust = windMph;
    const elevAdjust = elevationFt;
    return Math.max(1, distance - tailAdjust + elevAdjust);
}
