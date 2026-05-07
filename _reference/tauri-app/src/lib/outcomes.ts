import type { ShotOutcomeTag } from "../types";

export const OUTCOME_TAGS: ShotOutcomeTag[] = [
    "in",
    "short",
    "long",
    "left",
    "right",
    "penalty",
];

export function encodeOutcome(tags: ShotOutcomeTag[]): string | null {
    if (tags.length === 0) return null;
    const seen = new Set<ShotOutcomeTag>();
    const ordered = OUTCOME_TAGS.filter((t) => {
        if (!tags.includes(t) || seen.has(t)) return false;
        seen.add(t);
        return true;
    });
    return ordered.length > 0 ? ordered.join(",") : null;
}

export function decodeOutcome(raw: string | null): ShotOutcomeTag[] {
    if (!raw) return [];
    return raw
        .split(",")
        .map((s) => s.trim() as ShotOutcomeTag)
        .filter((t) => OUTCOME_TAGS.includes(t));
}

export function isMutuallyExclusive(
    a: ShotOutcomeTag,
    b: ShotOutcomeTag,
): boolean {
    if (a === b) return false;
    if ((a === "short" && b === "long") || (a === "long" && b === "short"))
        return true;
    if ((a === "left" && b === "right") || (a === "right" && b === "left"))
        return true;
    if (a === "in" || b === "in") return true;
    return false;
}

export function toggleTag(
    tags: ShotOutcomeTag[],
    tag: ShotOutcomeTag,
): ShotOutcomeTag[] {
    if (tags.includes(tag)) return tags.filter((t) => t !== tag);
    if (tag === "in") return ["in"];
    const next = tags.filter((t) => !isMutuallyExclusive(tag, t));
    return [...next, tag];
}
