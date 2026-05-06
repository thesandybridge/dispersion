export type ClubCategory =
    | "driver"
    | "wood"
    | "hybrid"
    | "long-iron"
    | "mid-iron"
    | "short-iron"
    | "wedge"
    | "putter";

export type CategoryStyle = {
    label: string;
    accent: string;
    accentDeep: string;
    gradient: string;
    inkOnAccent: string;
};

const STYLES: Record<ClubCategory, CategoryStyle> = {
    driver: {
        label: "Driver",
        accent: "#62b375",
        accentDeep: "#2c8a5e",
        gradient: "linear-gradient(135deg, #2c8a5e 0%, #16624a 100%)",
        inkOnAccent: "#0a1410",
    },
    wood: {
        label: "Wood",
        accent: "#a9d18e",
        accentDeep: "#62b375",
        gradient: "linear-gradient(135deg, #62b375 0%, #2c8a5e 100%)",
        inkOnAccent: "#0a1410",
    },
    hybrid: {
        label: "Hybrid",
        accent: "#e6c068",
        accentDeep: "#b08e3a",
        gradient: "linear-gradient(135deg, #d4a942 0%, #8a6d22 100%)",
        inkOnAccent: "#1a2419",
    },
    "long-iron": {
        label: "Long iron",
        accent: "#c87060",
        accentDeep: "#8a4a3e",
        gradient: "linear-gradient(135deg, #b85a4a 0%, #6b3a30 100%)",
        inkOnAccent: "#f6f1e1",
    },
    "mid-iron": {
        label: "Mid iron",
        accent: "#1f3a5f",
        accentDeep: "#102342",
        gradient: "linear-gradient(135deg, #1f3a5f 0%, #102342 100%)",
        inkOnAccent: "#f6f1e1",
    },
    "short-iron": {
        label: "Short iron",
        accent: "#5b8db8",
        accentDeep: "#36648c",
        gradient: "linear-gradient(135deg, #4d7fa8 0%, #2a4f74 100%)",
        inkOnAccent: "#f6f1e1",
    },
    wedge: {
        label: "Wedge",
        accent: "#f0e7b8",
        accentDeep: "#c4b878",
        gradient: "linear-gradient(135deg, #d4c98a 0%, #8a7c4a 100%)",
        inkOnAccent: "#1a2419",
    },
    putter: {
        label: "Putter",
        accent: "rgba(26,36,25,0.6)",
        accentDeep: "rgba(26,36,25,0.85)",
        gradient: "linear-gradient(135deg, #4a544c 0%, #1a2419 100%)",
        inkOnAccent: "#f6f1e1",
    },
};

const PATTERNS: Array<{ rx: RegExp; cat: ClubCategory }> = [
    { rx: /\bdriver\b|\bdvr\b/i, cat: "driver" },
    { rx: /\bwood\b|\b\dw\b|\b\d wood\b/i, cat: "wood" },
    { rx: /\bhybrid\b|\bh\d\b|\b\dh\b|\butility\b/i, cat: "hybrid" },
    { rx: /\b(lob|sand|gap|pitch)\s*wedge|\b(lw|sw|gw|pw)\b|\bwedge\b/i, cat: "wedge" },
    { rx: /\bputter\b|\bptr\b/i, cat: "putter" },
    { rx: /\b[1-4]\s*iron\b|\b[1-4]i\b/i, cat: "long-iron" },
    { rx: /\b[5-7]\s*iron\b|\b[5-7]i\b/i, cat: "mid-iron" },
    { rx: /\b[8-9]\s*iron\b|\b[8-9]i\b/i, cat: "short-iron" },
];

export function categoryFromName(name: string): ClubCategory {
    const trimmed = name.trim();
    for (const { rx, cat } of PATTERNS) {
        if (rx.test(trimmed)) return cat;
    }
    return "mid-iron";
}

export function categoryFromCarry(carryYards: number): ClubCategory {
    if (carryYards >= 250) return "driver";
    if (carryYards >= 220) return "wood";
    if (carryYards >= 200) return "hybrid";
    if (carryYards >= 180) return "long-iron";
    if (carryYards >= 150) return "mid-iron";
    if (carryYards >= 130) return "short-iron";
    if (carryYards >= 60) return "wedge";
    return "putter";
}

export function categorize(name: string, carryYards: number): ClubCategory {
    const byName = categoryFromName(name);
    if (byName !== "mid-iron") return byName;
    return categoryFromCarry(carryYards);
}

export function styleOf(category: ClubCategory): CategoryStyle {
    return STYLES[category];
}
