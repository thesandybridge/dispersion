export type Unit = "yards" | "meters";

const YARDS_PER_METER = 1 / 0.9144;
const METERS_PER_YARD = 0.9144;

export function unitLabel(unit: Unit, short = true): string {
    if (unit === "yards") return short ? "yd" : "yards";
    return short ? "m" : "meters";
}

export function fromYards(yards: number, unit: Unit): number {
    return unit === "yards" ? yards : yards * METERS_PER_YARD;
}

export function toYards(value: number, unit: Unit): number {
    return unit === "yards" ? value : value * YARDS_PER_METER;
}

export function formatDistance(yards: number, unit: Unit, digits = 0): string {
    const v = fromYards(yards, unit);
    return `${v.toFixed(digits)} ${unitLabel(unit)}`;
}

export function roundForUnit(value: number, unit: Unit): number {
    const factor = unit === "yards" ? 10 : 100;
    return Math.round(value * factor) / factor;
}
