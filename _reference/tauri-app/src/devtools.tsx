import type { AnyRouter } from "@tanstack/react-router";
import { TanStackDevtools } from "@tanstack/react-devtools";
import { ReactQueryDevtoolsPanel } from "@tanstack/react-query-devtools";
import { TanStackRouterDevtoolsPanel } from "@tanstack/react-router-devtools";
import { DispersionPanel } from "./devtools/DispersionPanel";

export function Devtools({ router }: { router: AnyRouter }) {
    return (
        <TanStackDevtools
            config={{
                position: "bottom-right",
                hideUntilHover: true,
                openHotkey: ["Alt", "D"],
                panelLocation: "bottom",
            }}
            plugins={[
                {
                    name: "Dispersion",
                    render: <DispersionPanel />,
                },
                {
                    name: "TanStack Router",
                    render: <TanStackRouterDevtoolsPanel router={router} />,
                },
                {
                    name: "TanStack Query",
                    render: <ReactQueryDevtoolsPanel />,
                },
            ]}
        />
    );
}
