import { create } from "zustand";
import { persist } from "zustand/middleware";
import type { Unit } from "./units";

export type SettingsState = {
    unit: Unit;
    debugOverlay: boolean;
    onboardingComplete: boolean;
    setUnit: (unit: Unit) => void;
    setDebugOverlay: (on: boolean) => void;
    completeOnboarding: () => void;
    resetOnboarding: () => void;
};

export const useSettings = create<SettingsState>()(
    persist(
        (set) => ({
            unit: "yards",
            debugOverlay: false,
            onboardingComplete: false,
            setUnit: (unit) => set({ unit }),
            setDebugOverlay: (debugOverlay) => set({ debugOverlay }),
            completeOnboarding: () => set({ onboardingComplete: true }),
            resetOnboarding: () => set({ onboardingComplete: false }),
        }),
        {
            name: "dispersion.settings.v1",
            partialize: (s) => ({
                unit: s.unit,
                debugOverlay: s.debugOverlay,
                onboardingComplete: s.onboardingComplete,
            }),
        },
    ),
);
