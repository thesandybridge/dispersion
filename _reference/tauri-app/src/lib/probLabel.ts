export type ProbLabel = {
    label: "STRONGLY FAVORED" | "FAVORED" | "MARGINAL" | "POOR";
    color: string;
};

export function probLabel(p: number): ProbLabel {
    if (p >= 0.6) return { label: "STRONGLY FAVORED", color: "#62b375" };
    if (p >= 0.4) return { label: "FAVORED", color: "#a9d18e" };
    if (p >= 0.2) return { label: "MARGINAL", color: "#e6c068" };
    return { label: "POOR", color: "#c87060" };
}
