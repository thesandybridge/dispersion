import { createRootRouteWithContext, Outlet } from "@tanstack/react-router";
import type { QueryClient } from "@tanstack/react-query";
import { BottomTabs } from "@/components/BottomTabs";
import { DebugOverlay } from "@/components/DebugOverlay";
import { EmptyBagGuard } from "@/components/EmptyBagGuard";
import { RadialDial } from "@/components/range/RadialDial";

export const Route = createRootRouteWithContext<{
    queryClient: QueryClient;
}>()({
    component: RootLayout,
});

function RootLayout() {
    return (
        <div
            className="h-svh flex flex-col overflow-hidden"
            style={{ background: "var(--bg)", color: "var(--fg)" }}
        >
            <main className="flex-1 min-h-0 min-w-0 flex flex-col overflow-hidden">
                <Outlet />
            </main>
            <BottomTabs />
            <RadialDial />
            <EmptyBagGuard />
            <DebugOverlay />
        </div>
    );
}
