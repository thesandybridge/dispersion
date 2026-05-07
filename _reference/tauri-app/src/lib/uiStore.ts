import { create } from "zustand";

type UiState = {
    cheatsheetOpen: boolean;
    newClubRequestId: number;
    openCheatsheet: () => void;
    closeCheatsheet: () => void;
    requestNewClub: () => void;
};

export const useUiStore = create<UiState>((set) => ({
    cheatsheetOpen: false,
    newClubRequestId: 0,
    openCheatsheet: () => set({ cheatsheetOpen: true }),
    closeCheatsheet: () => set({ cheatsheetOpen: false }),
    requestNewClub: () =>
        set((s) => ({ newClubRequestId: s.newClubRequestId + 1 })),
}));
