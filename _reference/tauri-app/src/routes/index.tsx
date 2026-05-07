import { createFileRoute, redirect } from "@tanstack/react-router";
import { useSettings } from "../lib/settingsStore";
import { listClubs } from "../db/clubs";

export const Route = createFileRoute("/")({
    beforeLoad: async () => {
        const onboardingComplete = useSettings.getState().onboardingComplete;
        if (!onboardingComplete) {
            try {
                const clubs = await listClubs();
                if (clubs.length === 0) {
                    throw redirect({
                    to: "/onboarding",
                    search: { step: 1 } as never,
                });
                }
            } catch (err) {
                if (err && typeof err === "object" && "to" in err) throw err;
            }
        }
        throw redirect({ to: "/calculator", search: {} as never });
    },
});
