import { StrictMode, lazy, Suspense } from "react";
import { createRoot } from "react-dom/client";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { RouterProvider, createRouter } from "@tanstack/react-router";
import { routeTree } from "./routeTree.gen";
import { ErrorBoundary } from "./components/ErrorBoundary";
import "./index.css";

const queryClient = new QueryClient({
    defaultOptions: {
        queries: {
            staleTime: 30_000,
            refetchOnWindowFocus: false,
        },
    },
});

const router = createRouter({
    routeTree,
    defaultPreload: "intent",
    context: { queryClient },
});

declare module "@tanstack/react-router" {
    interface Register {
        router: typeof router;
    }
}

const Devtools = import.meta.env.DEV
    ? lazy(() => import("./devtools").then((m) => ({ default: m.Devtools })))
    : null;

createRoot(document.getElementById("root")!).render(
    <StrictMode>
        <ErrorBoundary>
            <QueryClientProvider client={queryClient}>
                <RouterProvider router={router} />
                {Devtools && (
                    <Suspense fallback={null}>
                        <Devtools router={router} />
                    </Suspense>
                )}
            </QueryClientProvider>
        </ErrorBoundary>
    </StrictMode>,
);
