import { useEffect, useMemo, useRef, useState } from "react";
import {
    AnimatePresence,
    motion,
    useMotionValue,
    useMotionValueEvent,
} from "framer-motion";
import { useMatchRoute, useNavigate } from "@tanstack/react-router";
import {
    BriefcaseIcon,
    FlagIcon,
    SettingsIcon,
    TargetIcon,
    XIcon,
    type LucideIcon,
} from "lucide-react";
import { cn } from "@/lib/cn";
import { tap as hapticTap, notify as notifyHaptic } from "@/lib/haptics";
import { useDial, type DialAction } from "@/lib/dialStore";
import { useClubs } from "@/lib/queries";

// Re-exported so existing imports keep working.
export type RadialAction = DialAction;

type RouteId = "/calculator" | "/clubs" | "/range" | "/settings";

type RouteDef = {
    id: RouteId;
    label: string;
    icon: LucideIcon;
};

const ROUTES: ReadonlyArray<RouteDef> = [
    { id: "/calculator", label: "Calc", icon: TargetIcon },
    { id: "/clubs", label: "Bag", icon: BriefcaseIcon },
    { id: "/range", label: "Range", icon: FlagIcon },
    { id: "/settings", label: "Settings", icon: SettingsIcon },
];

const RADIUS = 160;
const START_DEG = 90;
const END_DEG = 180;
const FAB_SIZE = 56;
const ITEM_SIZE = 48;

// Joystick: route icons are arranged in a horizontal track to the left of the
// FAB. Each icon sits at a fixed x offset; the FAB's drag position selects
// whichever icon is *closest* to it. Direct manipulation, no thresholds.
const ROUTE_ICON_SIZE = 44;
const ROUTE_GAP = 16;
const ROUTE_SLOT = ROUTE_ICON_SIZE + ROUTE_GAP; // 60px between centers
const ROUTE_FIRST_OFFSET = -ROUTE_SLOT; // first icon center is one slot left of FAB
const JOY_X_MIN = ROUTE_FIRST_OFFSET * ROUTES.length - 12; // small overshoot
const JOY_X_MAX = 24; // tiny rightward elastic
const JOY_Y_MAX = 18;
const JOY_Y_MIN = -18;
// How close the FAB needs to be to an icon to "snap" to it (px from center).
const SNAP_RADIUS = ROUTE_SLOT / 2 + 4;
// Minimum drag distance before we treat the gesture as a route choice.
const ROUTE_TRIGGER = 18;

// Compute icon center x for slot i (0-based, leftmost = 0).
function routeSlotX(i: number): number {
    return ROUTE_FIRST_OFFSET - i * ROUTE_SLOT;
}

/**
 * Persistent bottom-right hub. Two interaction modes on the same FAB:
 *
 *  • Tap → fan an arc of route-specific action satellites (read from `useDial`).
 *  • Drag (joystick) → reveal a horizontal route track; release to navigate.
 *
 * The arc is up-and-left (90° → 180°). Items are 48×48 with absolute label tags,
 * so spacing is uniform regardless of label length.
 */
export function RadialDial() {
    const actions = useDial((s) => s.actions);
    const navigate = useNavigate();
    const matchRoute = useMatchRoute();
    const containerRef = useRef<HTMLDivElement>(null);
    // Routes that EmptyBagGuard redirects away from when the bag is empty.
    // Reflect that here so the joystick doesn't appear to "fail".
    const clubsQuery = useClubs();
    const bagEmpty =
        !clubsQuery.isLoading && (clubsQuery.data?.length ?? 0) === 0;
    const PROTECTED_ROUTES = new Set<RouteId>(["/calculator", "/range"]);
    const routeDisabled = (id: RouteId) => bagEmpty && PROTECTED_ROUTES.has(id);

    const [open, setOpen] = useState(false);
    const [joyActive, setJoyActive] = useState(false);
    const [hoveredActionId, setHoveredActionId] = useState<string | null>(null);

    const hoveredAction = useMemo(
        () => actions.find((a) => a.id === hoveredActionId) ?? null,
        [actions, hoveredActionId],
    );

    // Motion values for the FAB joystick. We expose dragX so the route track
    // overlay can react in real time.
    const dragX = useMotionValue(0);
    const dragY = useMotionValue(0);

    // Determine the currently-active route for the route track highlight.
    const currentRouteIndex = useMemo(() => {
        for (let i = 0; i < ROUTES.length; i++) {
            if (matchRoute({ to: ROUTES[i]!.id, fuzzy: true }) !== false) {
                return i;
            }
        }
        return 0;
    }, [matchRoute]);

    // Hovered route index: the icon whose fixed x position is closest to
    // the FAB's current dragX. -1 means "no icon close enough to count".
    const [hoverIndex, setHoverIndex] = useState<number>(-1);

    useMotionValueEvent(dragX, "change", (x) => {
        // Find the closest *enabled* route slot to x.
        let bestI = -1;
        let bestDist = Infinity;
        for (let i = 0; i < ROUTES.length; i++) {
            if (routeDisabled(ROUTES[i]!.id)) continue;
            const slot = routeSlotX(i);
            const d = Math.abs(slot - x);
            if (d < bestDist) {
                bestDist = d;
                bestI = i;
            }
        }
        if (bestDist <= SNAP_RADIUS) {
            setHoverIndex(bestI);
        } else {
            setHoverIndex(-1);
        }
    });

    // Outside-click + Escape close for the action menu.
    useEffect(() => {
        if (!open) return;
        function handleDown(e: MouseEvent | TouchEvent) {
            if (!containerRef.current) return;
            const target = e.target as Node;
            if (!containerRef.current.contains(target)) setOpen(false);
        }
        function handleKey(e: KeyboardEvent) {
            if (e.key === "Escape") setOpen(false);
        }
        window.addEventListener("mousedown", handleDown);
        window.addEventListener("touchstart", handleDown);
        window.addEventListener("keydown", handleKey);
        return () => {
            window.removeEventListener("mousedown", handleDown);
            window.removeEventListener("touchstart", handleDown);
            window.removeEventListener("keydown", handleKey);
        };
    }, [open]);

    const n = Math.max(actions.length, 1);
    const span = END_DEG - START_DEG;
    const step = n === 1 ? 0 : span / (n - 1);

    function commitJoystick() {
        // Recompute the snapped slot from the live motion value at release
        // time — React state for `hoverIndex` may be one render behind, which
        // misses the icon you just dragged onto.
        const offsetX = dragX.get();
        const distance = Math.abs(offsetX);
        let bestI = -1;
        let bestDist = Infinity;
        for (let i = 0; i < ROUTES.length; i++) {
            if (routeDisabled(ROUTES[i]!.id)) continue;
            const slot = routeSlotX(i);
            const d = Math.abs(slot - offsetX);
            if (d < bestDist) {
                bestDist = d;
                bestI = i;
            }
        }
        const liveHover = bestDist <= SNAP_RADIUS ? bestI : -1;

        if (
            distance >= ROUTE_TRIGGER &&
            liveHover !== -1 &&
            liveHover !== currentRouteIndex
        ) {
            const target = ROUTES[liveHover]!.id;
            void notifyHaptic("success");
            navigate({ to: target as never });
        } else {
            hapticTap("light");
        }
        setJoyActive(false);
        setHoverIndex(-1);
        // Let `dragSnapToOrigin` spring the FAB back; calling `set(0)` here
        // would clobber the spring and the FAB would teleport.
    }

    // In dev, lift the dial above the TanStack devtools floating tab so it
    // doesn't sit underneath it.
    const isDev = import.meta.env.DEV;
    const bottomOffset = isDev
        ? "calc(max(env(safe-area-inset-bottom), 16px) + 56px)"
        : "max(env(safe-area-inset-bottom), 16px)";

    return (
        <div
            ref={containerRef}
            className="pointer-events-none fixed right-4 z-40"
            style={{ bottom: bottomOffset }}
        >
            {/* Backdrop scrim while menu is open */}
            <AnimatePresence>
                {open && (
                    <motion.button
                        key="scrim"
                        type="button"
                        aria-label="Close menu"
                        initial={{ opacity: 0 }}
                        animate={{ opacity: 1 }}
                        exit={{ opacity: 0 }}
                        onClick={() => setOpen(false)}
                        className="pointer-events-auto fixed inset-0 -z-10 bg-black/45"
                    />
                )}
            </AnimatePresence>

            {/* Joystick route track — visible while dragging */}
            <AnimatePresence>
                {joyActive && (
                    <RouteTrack
                        currentIndex={currentRouteIndex}
                        hoverIndex={hoverIndex}
                        disabled={ROUTES.map((r) => routeDisabled(r.id))}
                    />
                )}
            </AnimatePresence>

            {/* Hub box: 56×56 to match FAB. Satellites + FAB live inside. */}
            <div
                className="relative"
                style={{ width: FAB_SIZE, height: FAB_SIZE }}
            >
                <AnimatePresence>
                    {open &&
                        actions.map((a, i) => {
                            const deg = START_DEG + step * i;
                            const rad = (deg * Math.PI) / 180;
                            const x = Math.cos(rad) * RADIUS;
                            const y = -Math.sin(rad) * RADIUS;
                            return (
                                <DialItem
                                    key={a.id}
                                    action={a}
                                    targetX={x}
                                    targetY={y}
                                    delay={i * 0.03}
                                    onHover={(id) => setHoveredActionId(id)}
                                    onAfterClick={() => setOpen(false)}
                                />
                            );
                        })}
                </AnimatePresence>

                {/* Single floating caption shown above the FAB while menu is open.
                    Defaults to the first action's label, updates on hover. */}
                <AnimatePresence>
                    {open && actions.length > 0 && (
                        <motion.div
                            key="caption"
                            initial={{ opacity: 0, y: 4 }}
                            animate={{ opacity: 1, y: 0 }}
                            exit={{ opacity: 0, y: 4 }}
                            transition={{ delay: 0.05 }}
                            className="pointer-events-none absolute right-1/2 translate-x-1/2 -top-9 whitespace-nowrap rounded-full bg-foreground px-3 py-1 font-mono text-[10px] uppercase tracking-[0.18em] text-background shadow"
                        >
                            {(hoveredAction ?? actions[0])?.label}
                        </motion.div>
                    )}
                </AnimatePresence>

                {/* The FAB. Two roles: tap = open menu, drag = joystick. */}
                <motion.button
                    aria-label={open ? "Close actions" : "Open actions"}
                    aria-expanded={open}
                    drag
                    dragConstraints={{
                        left: JOY_X_MIN,
                        right: JOY_X_MAX,
                        top: JOY_Y_MIN,
                        bottom: JOY_Y_MAX,
                    }}
                    dragElastic={0.18}
                    dragMomentum={false}
                    dragSnapToOrigin
                    dragTransition={{
                        bounceStiffness: 480,
                        bounceDamping: 32,
                    }}
                    style={{ x: dragX, y: dragY }}
                    onDragStart={() => {
                        setOpen(false);
                        setJoyActive(true);
                        hapticTap("light");
                    }}
                    onDragEnd={commitJoystick}
                    onClick={() => {
                        if (joyActive) return;
                        if (actions.length === 0) {
                            // Nothing to expand; haptic only.
                            hapticTap("light");
                            return;
                        }
                        hapticTap("light");
                        setOpen((v) => !v);
                    }}
                    whileTap={{ scale: 0.94 }}
                    className={cn(
                        "pointer-events-auto absolute inset-0 grid cursor-grab place-items-center rounded-full transition-colors active:cursor-grabbing",
                        "shadow-[0_8px_24px_rgba(0,0,0,0.45),0_2px_6px_rgba(0,0,0,0.30)]",
                        "border border-primary/30",
                        joyActive
                            ? "bg-foreground text-background"
                            : open
                              ? "bg-foreground text-background"
                              : "bg-primary text-primary-foreground",
                    )}
                >
                    {/* Soft halo while idle */}
                    <span
                        aria-hidden
                        className="pointer-events-none absolute -inset-2 rounded-full"
                        style={{
                            background:
                                "conic-gradient(from 0deg, rgba(169,209,142,0.0) 0deg, rgba(169,209,142,0.32) 4deg, rgba(169,209,142,0) 12deg, rgba(169,209,142,0) 348deg, rgba(169,209,142,0.32) 356deg, rgba(169,209,142,0) 360deg)",
                            opacity: open || joyActive ? 0 : 0.55,
                            transition: "opacity 200ms",
                        }}
                    />
                    <motion.span
                        initial={false}
                        animate={{ rotate: open ? 90 : 0 }}
                        transition={{ type: "spring", stiffness: 380, damping: 30 }}
                        className="relative grid place-items-center"
                    >
                        {open ? (
                            <XIcon className="size-6" strokeWidth={2.4} />
                        ) : (
                            <DialFabGlyph />
                        )}
                    </motion.span>
                </motion.button>
            </div>
        </div>
    );
}

function DialItem({
    action,
    targetX,
    targetY,
    delay,
    onHover,
    onAfterClick,
}: {
    action: RadialAction;
    targetX: number;
    targetY: number;
    delay: number;
    onHover: (id: string | null) => void;
    onAfterClick: () => void;
}) {
    const tone =
        action.tone === "danger"
            ? "bg-destructive text-destructive-foreground border-destructive/40"
            : action.tone === "primary"
              ? "bg-primary text-primary-foreground border-primary/40"
              : "bg-card text-foreground border-border";

    // 48×48 satellite anchored such that its center sits at the FAB's center
    // when (x,y) = (0,0). With FAB=56 and item=48, that's offset 4px from each
    // edge, hence right:4 bottom:4.
    return (
        <motion.div
            initial={{ x: 0, y: 0, scale: 0.4, opacity: 0 }}
            animate={{ x: targetX, y: targetY, scale: 1, opacity: 1 }}
            exit={{ x: 0, y: 0, scale: 0.4, opacity: 0 }}
            transition={{
                type: "spring",
                stiffness: 360,
                damping: 28,
                delay,
            }}
            className="pointer-events-auto absolute"
            style={{ width: ITEM_SIZE, height: ITEM_SIZE, right: 4, bottom: 4 }}
        >
            <motion.button
                disabled={action.disabled}
                onClick={() => {
                    hapticTap("medium");
                    action.onClick();
                    onAfterClick();
                }}
                onPointerEnter={() => onHover(action.id)}
                onPointerLeave={() => onHover(null)}
                onPointerDown={() => onHover(action.id)}
                whileTap={{ scale: 0.92 }}
                className={cn(
                    "grid size-12 place-items-center rounded-full border shadow-[0_6px_16px_rgba(0,0,0,0.45)] transition-colors",
                    "disabled:opacity-40 disabled:pointer-events-none",
                    tone,
                )}
                aria-label={action.label}
            >
                {action.icon}
            </motion.button>
        </motion.div>
    );
}

function DialFabGlyph() {
    return (
        <svg
            width="22"
            height="22"
            viewBox="0 0 22 22"
            fill="none"
            aria-hidden
        >
            <circle cx="11" cy="11" r="3" fill="currentColor" />
            <circle
                cx="11"
                cy="11"
                r="7.5"
                stroke="currentColor"
                strokeWidth="1.5"
                strokeDasharray="2 3"
                opacity="0.5"
            />
        </svg>
    );
}

/**
 * Route track shown during a joystick drag. Each route icon sits at a fixed
 * x offset from the FAB (parent has its origin at the FAB's center). The user
 * physically drags the FAB along this track and the icon they're closest to
 * is the one that activates.
 */
function RouteTrack({
    currentIndex,
    hoverIndex,
    disabled,
}: {
    currentIndex: number;
    hoverIndex: number;
    disabled: boolean[];
}) {
    return (
        <>
            {ROUTES.map((r, i) => {
                const isCurrent = i === currentIndex;
                const isHover = i === hoverIndex;
                const isDisabled = disabled[i] ?? false;
                const Icon = r.icon;
                // Icon center should land at routeSlotX(i) relative to FAB
                // center. Our FAB center is at right:4 bottom:4 inside the
                // 56px hub. We anchor the icon by its right edge offset, so:
                //   right = (FAB inset 4) + (FAB half - icon half) - slotX
                //         = 4 + 6 - slotX  (since slotX is negative, this grows)
                const iconRight = -ROUTE_ICON_SIZE / 2 - routeSlotX(i) + FAB_SIZE / 2;
                return (
                    <motion.div
                        key={r.id}
                        initial={{ opacity: 0, scale: 0.7, y: 12 }}
                        animate={{
                            opacity: 1,
                            scale: isHover ? 1.12 : 1,
                            y: 0,
                        }}
                        exit={{ opacity: 0, scale: 0.7, y: 12 }}
                        transition={{
                            type: "spring",
                            stiffness: 420,
                            damping: 30,
                            delay: 0.02 * i,
                        }}
                        className="pointer-events-none absolute"
                        style={{
                            // Sit the icons in a track ABOVE the FAB y-level
                            // so the FAB doesn't visually swallow them as it
                            // drags through the same column.
                            right: iconRight,
                            bottom:
                                (FAB_SIZE - ROUTE_ICON_SIZE) / 2 +
                                FAB_SIZE +
                                12,
                            width: ROUTE_ICON_SIZE,
                            height: ROUTE_ICON_SIZE,
                        }}
                    >
                        <div
                            className={cn(
                                "relative flex size-full items-center justify-center rounded-full border transition-colors",
                                isDisabled
                                    ? "border-border/30 bg-card/40 text-muted-foreground/40"
                                    : isHover
                                      ? "border-primary bg-primary text-primary-foreground shadow-[0_0_0_4px_rgba(169,209,142,0.18)]"
                                      : isCurrent
                                        ? "border-border bg-card text-foreground"
                                        : "border-border bg-card/70 text-muted-foreground",
                            )}
                        >
                            <Icon
                                className="size-5"
                                strokeWidth={isHover ? 2.2 : 1.8}
                            />
                            {isHover && (
                                <motion.span
                                    initial={{ opacity: 0, y: 4 }}
                                    animate={{ opacity: 1, y: 0 }}
                                    className="absolute -top-7 left-1/2 -translate-x-1/2 whitespace-nowrap rounded-full bg-foreground px-2 py-0.5 font-mono text-[10px] uppercase tracking-[0.16em] text-background shadow"
                                >
                                    {r.label}
                                </motion.span>
                            )}
                            {isCurrent && !isHover && (
                                <span
                                    className="absolute -bottom-1 left-1/2 size-1 -translate-x-1/2 rounded-full bg-primary"
                                    aria-hidden
                                />
                            )}
                        </div>
                    </motion.div>
                );
            })}
        </>
    );
}
