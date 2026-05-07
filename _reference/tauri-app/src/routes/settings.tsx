import { useRef, useState, type ReactNode } from "react";
import { createFileRoute } from "@tanstack/react-router";
import { useQueryClient } from "@tanstack/react-query";
import {
    BeakerIcon,
    BugIcon,
    ChevronRightIcon,
    DatabaseIcon,
    DownloadIcon,
    RulerIcon,
    Trash2Icon,
    UploadIcon,
    WrenchIcon,
} from "lucide-react";
import { useClubs } from "@/lib/queries";
import { buildBackup, parseBackup } from "@/lib/backup";
import { createClub, deleteAllClubs } from "@/db/clubs";
import { createSession, listSessions } from "@/db/sessions";
import { createShot, listShotsBySession } from "@/db/shots";
import type { ShotOutcomeTag } from "@/types";
import { useSettings } from "@/lib/settingsStore";
import { newId } from "@/lib/id";
import { ConfirmDialog } from "@/components/ConfirmDialog";
import { SAMPLE_BAG } from "@/lib/sampleBag";
import { cn } from "@/lib/cn";
import { Switch } from "@/components/ui/switch";
import { ToggleGroup, ToggleGroupItem } from "@/components/ui/toggle-group";

export const Route = createFileRoute("/settings")({
    component: SettingsPage,
});

function SettingsPage() {
    const clubs = useClubs();
    const qc = useQueryClient();
    const settings = useSettings();
    const fileRef = useRef<HTMLInputElement>(null);
    const [status, setStatus] = useState<{
        kind: "ok" | "err";
        text: string;
    } | null>(null);
    const [busy, setBusy] = useState(false);
    const [clearConfirm, setClearConfirm] = useState(false);
    const [seedConfirm, setSeedConfirm] = useState(false);

    async function handleExport() {
        if (!clubs.data) return;
        setBusy(true);
        try {
            const sessions = await listSessions(10_000);
            const allShots = (
                await Promise.all(
                    sessions.map((s) => listShotsBySession(s.id)),
                )
            ).flat();
            const backup = buildBackup(clubs.data, sessions, allShots);
            const blob = new Blob([JSON.stringify(backup, null, 2)], {
                type: "application/json",
            });
            const url = URL.createObjectURL(blob);
            const a = document.createElement("a");
            const stamp = new Date().toISOString().slice(0, 10);
            a.href = url;
            a.download = `dispersion-${stamp}.json`;
            a.click();
            URL.revokeObjectURL(url);
            setStatus({
                kind: "ok",
                text: `Exported ${clubs.data.length} clubs · ${sessions.length} sessions · ${allShots.length} shots.`,
            });
        } catch (e) {
            setStatus({ kind: "err", text: (e as Error).message });
        } finally {
            setBusy(false);
        }
    }

    async function handleImportFile(file: File) {
        setBusy(true);
        setStatus(null);
        try {
            const text = await file.text();
            const backup = parseBackup(text);
            await deleteAllClubs();
            for (const c of backup.clubs) {
                await createClub({
                    id: c.id,
                    name: c.name,
                    carryYards: c.carryYards,
                    carrySd: c.carrySd,
                    lateralSd: c.lateralSd,
                });
            }
            for (const s of backup.sessions) {
                await createSession({
                    id: s.id,
                    kind: s.kind === "round" ? "round" : "range",
                    label: s.label,
                });
            }
            for (const s of backup.shots) {
                const tags = s.outcome
                    ? (s.outcome
                          .split(",")
                          .map((t) => t.trim())
                          .filter(Boolean) as ShotOutcomeTag[])
                    : [];
                await createShot({
                    id: s.id,
                    sessionId: s.sessionId,
                    clubId: s.clubId,
                    targetDistanceYards: s.targetDistanceYards,
                    longDelta: s.longDelta,
                    latDelta: s.latDelta,
                    outcomes: tags,
                });
            }
            await qc.invalidateQueries({ queryKey: ["clubs"] });
            await qc.invalidateQueries({ queryKey: ["sessions"] });
            await qc.invalidateQueries({ queryKey: ["shots"] });
            await qc.invalidateQueries({ queryKey: ["shotCounts"] });
            setStatus({
                kind: "ok",
                text: `Imported ${backup.clubs.length} clubs · ${backup.sessions.length} sessions · ${backup.shots.length} shots.`,
            });
        } catch (e) {
            setStatus({ kind: "err", text: (e as Error).message });
        } finally {
            setBusy(false);
        }
    }

    async function doClear() {
        setClearConfirm(false);
        setBusy(true);
        try {
            await deleteAllClubs();
            await qc.invalidateQueries({ queryKey: ["clubs"] });
            setStatus({ kind: "ok", text: "All data cleared." });
        } catch (e) {
            setStatus({ kind: "err", text: (e as Error).message });
        } finally {
            setBusy(false);
        }
    }

    async function doSeed() {
        setSeedConfirm(false);
        setBusy(true);
        try {
            await deleteAllClubs();
            for (const c of SAMPLE_BAG) {
                await createClub({ id: newId(), ...c });
            }
            await qc.invalidateQueries({ queryKey: ["clubs"] });
            setStatus({ kind: "ok", text: "Seeded sample bag." });
        } catch (e) {
            setStatus({ kind: "err", text: (e as Error).message });
        } finally {
            setBusy(false);
        }
    }

    const clubCount = clubs.data?.length ?? 0;

    return (
        <div className="flex flex-1 min-h-0 flex-col overflow-hidden bg-background text-foreground">
            <Hero clubCount={clubCount} />

            <div className="mx-auto w-full max-w-2xl flex-1 min-h-0 overflow-auto px-5 pb-10 md:px-7">
                <Group
                    icon={<RulerIcon className="size-4" />}
                    label="Units"
                    accent="primary"
                >
                    <Row
                        label="Distance"
                        helper="Used everywhere yardage is shown"
                    >
                        <ToggleGroup
                            type="single"
                            value={settings.unit}
                            onValueChange={(v) =>
                                v &&
                                settings.setUnit(v as "yards" | "meters")
                            }
                        >
                            <ToggleGroupItem value="yards">
                                Yards
                            </ToggleGroupItem>
                            <ToggleGroupItem value="meters">
                                Meters
                            </ToggleGroupItem>
                        </ToggleGroup>
                    </Row>
                </Group>

                <Group
                    icon={<DatabaseIcon className="size-4" />}
                    label="Data"
                    accent="water"
                >
                    <ActionRow
                        icon={<DownloadIcon className="size-4" />}
                        label="Export"
                        value={`${clubCount} club${clubCount === 1 ? "" : "s"}`}
                        helper="Download a full backup as JSON"
                        onClick={handleExport}
                        disabled={busy || clubCount === 0}
                    />
                    <ActionRow
                        icon={<UploadIcon className="size-4" />}
                        label="Import"
                        value="Replace local"
                        helper="Restore from a JSON backup"
                        onClick={() => fileRef.current?.click()}
                        disabled={busy}
                    />
                    <input
                        ref={fileRef}
                        type="file"
                        accept="application/json,.json"
                        className="hidden"
                        onChange={(e) => {
                            const file = e.target.files?.[0];
                            e.target.value = "";
                            if (file) void handleImportFile(file);
                        }}
                    />
                    <ActionRow
                        icon={<Trash2Icon className="size-4" />}
                        label="Clear all data"
                        value={`${clubCount} club${clubCount === 1 ? "" : "s"}`}
                        helper="Removes every club and shot. Cannot be undone."
                        onClick={() => setClearConfirm(true)}
                        disabled={busy}
                        danger
                    />
                </Group>

                <Group
                    icon={<WrenchIcon className="size-4" />}
                    label="Developer"
                    accent="warn"
                >
                    <Row
                        label="Debug overlay"
                        helper="Shows live state in the corner"
                    >
                        <Switch
                            checked={settings.debugOverlay}
                            onCheckedChange={settings.setDebugOverlay}
                        />
                    </Row>
                    <ActionRow
                        icon={<BeakerIcon className="size-4" />}
                        label="Seed sample bag"
                        value="13 clubs"
                        helper="Replace your bag with a realistic starter set"
                        onClick={() => setSeedConfirm(true)}
                        disabled={busy}
                    />
                    <ActionRow
                        icon={<BugIcon className="size-4" />}
                        label="Replay onboarding"
                        value="↗"
                        helper="Show the first-run flow next launch"
                        onClick={() => {
                            settings.resetOnboarding();
                            setStatus({
                                kind: "ok",
                                text: "Onboarding will show next time.",
                            });
                        }}
                        disabled={busy}
                    />
                </Group>

                {status && (
                    <div
                        className={cn(
                            "mb-4 rounded-xl border px-3.5 py-2.5 text-[12px]",
                            status.kind === "ok"
                                ? "border-primary/30 bg-primary/10 text-primary"
                                : "border-destructive/40 bg-destructive/10 text-destructive",
                        )}
                    >
                        {status.text}
                    </div>
                )}

                <div className="mt-8 text-center font-mono text-[11px] leading-relaxed text-muted-foreground">
                    Dispersion v0.1.0 · local-only build
                    <br />
                    stored in localStorage + sqlite
                </div>
            </div>

            <ConfirmDialog
                open={clearConfirm}
                onOpenChange={setClearConfirm}
                title="Delete all clubs?"
                description="This removes every club in your bag. Cannot be undone."
                confirmLabel="Delete all"
                danger
                onConfirm={doClear}
            />
            <ConfirmDialog
                open={seedConfirm}
                onOpenChange={setSeedConfirm}
                title="Replace bag with sample?"
                description={`Wipes your current bag and inserts ${SAMPLE_BAG.length} sample clubs (Driver → Lob Wedge).`}
                confirmLabel="Replace"
                danger
                onConfirm={doSeed}
            />
        </div>
    );
}

function Hero({ clubCount }: { clubCount: number }) {
    return (
        <div
            className="screen-header relative overflow-hidden border-b border-border px-5 pb-7 md:px-7"
            style={{
                background:
                    "radial-gradient(140% 80% at 100% 0%, rgba(98,179,117,0.18) 0%, rgba(98,179,117,0) 60%), linear-gradient(180deg, #0e1a13 0%, #070d0a 100%)",
            }}
        >
            <div
                aria-hidden
                className="pointer-events-none absolute -top-12 -right-16 size-[260px] rounded-full"
                style={{
                    background:
                        "radial-gradient(circle at center, rgba(98,179,117,0.32) 0%, rgba(98,179,117,0) 65%)",
                }}
            />
            <div className="eyebrow text-primary relative">Settings</div>
            <h1
                className="headline relative mt-1"
                style={{ fontSize: "clamp(34px, 8vw, 44px)" }}
            >
                Preferences
            </h1>
            <div className="relative mt-2 flex items-center gap-2 font-mono text-[11px] tabular text-muted-foreground">
                <span>Local-only · v0.1</span>
                <span className="size-0.5 rounded-full bg-muted-foreground/40" />
                <span>{clubCount} clubs</span>
            </div>
        </div>
    );
}

const accentMap = {
    primary: "text-primary",
    water: "text-[#7aa3cc]",
    warn: "text-[#e6c068]",
} as const;

function Group({
    label,
    icon,
    accent = "primary",
    children,
}: {
    label: string;
    icon: ReactNode;
    accent?: keyof typeof accentMap;
    children: ReactNode;
}) {
    return (
        <div className="mb-5 mt-5">
            <div className="mb-2 flex items-center gap-2 px-1">
                <span
                    className={cn(
                        "flex size-7 items-center justify-center rounded-full bg-muted/60",
                        accentMap[accent],
                    )}
                >
                    {icon}
                </span>
                <span className="eyebrow-strong text-muted-foreground">
                    {label}
                </span>
            </div>
            <div className="overflow-hidden rounded-2xl border border-border bg-card divide-y divide-border/60">
                {children}
            </div>
        </div>
    );
}

function Row({
    label,
    helper,
    children,
}: {
    label: string;
    helper?: string;
    children: ReactNode;
}) {
    return (
        <div className="flex items-center justify-between gap-3 px-4 py-3.5">
            <div className="min-w-0">
                <div className="text-[14px] font-medium leading-tight">
                    {label}
                </div>
                {helper && (
                    <div className="mt-0.5 text-[12px] leading-snug text-muted-foreground">
                        {helper}
                    </div>
                )}
            </div>
            {children}
        </div>
    );
}

function ActionRow({
    icon,
    label,
    value,
    helper,
    onClick,
    disabled,
    danger,
}: {
    icon: ReactNode;
    label: string;
    value: string;
    helper?: string;
    onClick: () => void;
    disabled?: boolean;
    danger?: boolean;
}) {
    return (
        <button
            onClick={onClick}
            disabled={disabled}
            className={cn(
                "flex w-full items-center gap-3 px-4 py-3.5 text-left transition-colors hover:bg-muted/40 disabled:opacity-50 disabled:hover:bg-transparent",
            )}
        >
            <span
                className={cn(
                    "flex size-8 items-center justify-center rounded-full bg-muted/50",
                    danger ? "text-destructive" : "text-foreground/80",
                )}
            >
                {icon}
            </span>
            <div className="min-w-0 flex-1">
                <div
                    className={cn(
                        "text-[14px] font-medium leading-tight",
                        danger && "text-destructive",
                    )}
                >
                    {label}
                </div>
                {helper && (
                    <div className="mt-0.5 text-[12px] leading-snug text-muted-foreground">
                        {helper}
                    </div>
                )}
            </div>
            <span className="flex shrink-0 items-center gap-1.5 font-mono tabular text-[11px] text-muted-foreground">
                {value}
                <ChevronRightIcon className="size-3 opacity-60" />
            </span>
        </button>
    );
}

