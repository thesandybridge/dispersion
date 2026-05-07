import { useEffect } from "react";
import { useNavigate, useRouterState } from "@tanstack/react-router";
import { useClubs } from "../lib/queries";
import { useSettings } from "../lib/settingsStore";

const PROTECTED_PATHS = ["/calculator", "/range"];

export function EmptyBagGuard() {
    const navigate = useNavigate();
    const clubs = useClubs();
    const onboardingComplete = useSettings((s) => s.onboardingComplete);
    const pathname = useRouterState({
        select: (s) => s.location.pathname,
    });

    useEffect(() => {
        if (clubs.isLoading || clubs.isFetching || !clubs.data) return;
        const empty = clubs.data.length === 0;
        if (!empty) return;
        if (!PROTECTED_PATHS.some((p) => pathname.startsWith(p))) return;

        if (!onboardingComplete) {
            navigate({
                to: "/onboarding",
                search: { step: 1 } as never,
                replace: true,
            });
        } else {
            navigate({ to: "/clubs", replace: true });
        }
    }, [clubs.isLoading, clubs.data, onboardingComplete, pathname, navigate]);

    return null;
}
