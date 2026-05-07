import { create } from "zustand";
import type { SessionKind } from "../types";

type Active = {
    id: string;
    kind: SessionKind;
    label: string;
} | null;

type State = {
    active: Active;
    setActive: (a: Active) => void;
    clearActive: () => void;
};

export const useActiveSession = create<State>((set) => ({
    active: null,
    setActive: (a) => set({ active: a }),
    clearActive: () => set({ active: null }),
}));
