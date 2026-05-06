import { Link, useMatchRoute } from "@tanstack/react-router";
import { motion } from "framer-motion";
import {
    BriefcaseIcon,
    FlagIcon,
    SettingsIcon,
    TargetIcon,
    type LucideIcon,
} from "lucide-react";
import { useActiveSession } from "@/lib/sessionStore";
import { tap } from "@/lib/haptics";
import { cn } from "@/lib/cn";

type TabDef = {
    to: "/calculator" | "/clubs" | "/range" | "/settings";
    icon: LucideIcon;
    label: string;
};

const TABS: ReadonlyArray<TabDef> = [
    { to: "/calculator", icon: TargetIcon, label: "Calc" },
    { to: "/clubs", icon: BriefcaseIcon, label: "My Bag" },
    { to: "/range", icon: FlagIcon, label: "Range" },
    { to: "/settings", icon: SettingsIcon, label: "Settings" },
];

export function BottomTabs() {
    const matchRoute = useMatchRoute();
    const session = useActiveSession((s) => s.active);

    return (
        <nav
            className="relative flex shrink-0 justify-around border-t border-[rgba(244,239,227,0.08)] bg-[#0b1410] pt-2"
            style={{
                paddingBottom: "max(env(safe-area-inset-bottom), 14px)",
            }}
        >
            {TABS.map((t) => {
                const isActive =
                    matchRoute({ to: t.to, fuzzy: true }) !== false;
                const Icn = t.icon;
                const showPulse =
                    session != null &&
                    ((t.to === "/range" && session.kind === "range") ||
                        (t.to === "/calculator" && session.kind === "round"));
                return (
                    <Link
                        key={t.to}
                        to={t.to}
                        onClick={() => tap("light")}
                        className={cn(
                            "relative flex min-w-[64px] flex-col items-center justify-center gap-1 py-1.5 font-mono text-[10px] tracking-[0.16em] uppercase transition-colors",
                            isActive
                                ? "text-primary"
                                : "text-[rgba(244,239,227,0.55)] hover:text-[rgba(244,239,227,0.85)]",
                        )}
                    >
                        {isActive && (
                            <motion.span
                                layoutId="bottomTabIndicator"
                                className="absolute -top-2 left-1/2 h-[3px] w-7 -translate-x-1/2 rounded-full bg-primary"
                                transition={{
                                    type: "spring",
                                    stiffness: 380,
                                    damping: 32,
                                }}
                            />
                        )}
                        {showPulse && (
                            <span className="absolute right-3 top-1.5">
                                <span className="absolute inset-0 size-1.5 animate-ping rounded-full bg-primary/60" />
                                <span className="relative block size-1.5 rounded-full bg-primary" />
                            </span>
                        )}
                        <Icn size={20} strokeWidth={isActive ? 2.2 : 1.8} />
                        {t.label}
                    </Link>
                );
            })}
        </nav>
    );
}
