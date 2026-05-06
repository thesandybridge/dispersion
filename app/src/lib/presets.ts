import type { Zone } from "../types";

export type ZonePreset = {
    id: string;
    label: string;
    hint: string;
    zone: Zone;
};

export const ZONE_PRESETS: ZonePreset[] = [
    {
        id: "green",
        label: "Average green",
        hint: "Mid-sized putting surface",
        zone: { widthYards: 28, depthYards: 30 },
    },
    {
        id: "tight",
        label: "Tight fairway",
        hint: "Trees both sides",
        zone: { widthYards: 24, depthYards: 60 },
    },
    {
        id: "wide",
        label: "Wide fairway",
        hint: "Generous tee shot",
        zone: { widthYards: 50, depthYards: 80 },
    },
    {
        id: "pin",
        label: "Tucked pin",
        hint: "Tournament back-right",
        zone: { widthYards: 12, depthYards: 14 },
    },
];

export const DEFAULT_PRESET_ID = "green";

export function getPreset(id: string): ZonePreset | undefined {
    return ZONE_PRESETS.find((p) => p.id === id);
}
