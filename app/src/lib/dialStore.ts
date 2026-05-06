import { create } from "zustand";
import type { ReactNode } from "react";

export type DialAction = {
    id: string;
    label: string;
    icon: ReactNode;
    onClick: () => void;
    tone?: "default" | "primary" | "danger";
    disabled?: boolean;
};

type DialState = {
    actions: DialAction[];
    setActions: (a: DialAction[]) => void;
};

/**
 * App-wide store for the persistent radial dial. Each route calls
 * `setActions(...)` on mount with route-specific items, and `setActions([])`
 * on unmount. The dial is rendered once in the root layout.
 */
export const useDial = create<DialState>((set) => ({
    actions: [],
    setActions: (actions) => set({ actions }),
}));
