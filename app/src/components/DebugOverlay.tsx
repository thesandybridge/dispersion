import { useRouterState } from "@tanstack/react-router";
import { useSettings } from "../lib/settingsStore";
import { useActiveSession } from "../lib/sessionStore";
import { useClubs } from "../lib/queries";

export function DebugOverlay() {
    const enabled = useSettings((s) => s.debugOverlay);
    const unit = useSettings((s) => s.unit);
    const session = useActiveSession((s) => s.active);
    const clubs = useClubs();
    const route = useRouterState({
        select: (s) => s.location.pathname,
    });

    if (!enabled) return null;

    return (
        <div
            className="hidden md:block fixed bottom-3 right-3 z-50 pointer-events-none px-3 py-2 rounded-lg font-mono text-[10px] leading-relaxed"
            style={{
                background: "rgba(10,20,16,0.85)",
                color: "rgba(246,241,225,0.85)",
                border: "1px solid rgba(246,241,225,0.18)",
                backdropFilter: "blur(6px)",
                WebkitBackdropFilter: "blur(6px)",
                maxWidth: 220,
            }}
        >
            <div style={{ color: "#a9d18e", marginBottom: 2 }}>◆ debug</div>
            <Row k="route" v={route} />
            <Row k="unit" v={unit} />
            <Row k="clubs" v={String(clubs.data?.length ?? "…")} />
            <Row
                k="session"
                v={session ? `${session.kind} ${session.id.slice(0, 6)}` : "—"}
            />
        </div>
    );
}

function Row({ k, v }: { k: string; v: string }) {
    return (
        <div
            className="flex justify-between gap-2"
            style={{ color: "rgba(246,241,225,0.7)" }}
        >
            <span>{k}</span>
            <span style={{ color: "rgba(246,241,225,0.95)" }}>{v}</span>
        </div>
    );
}
