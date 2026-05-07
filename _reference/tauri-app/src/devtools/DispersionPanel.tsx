import { useQueryClient } from "@tanstack/react-query";
import { useUiStore } from "../lib/uiStore";
import { useSettings } from "../lib/settingsStore";
import { useClubs } from "../lib/queries";
import { createClub, deleteAllClubs } from "../db/clubs";
import { newId } from "../lib/id";

const SAMPLE_BAG: Array<{
    name: string;
    carryYards: number;
    carrySd: number;
    lateralSd: number;
}> = [
    { name: "Driver", carryYards: 270, carrySd: 12, lateralSd: 18 },
    { name: "3 Wood", carryYards: 245, carrySd: 10, lateralSd: 14 },
    { name: "5 Iron", carryYards: 195, carrySd: 7, lateralSd: 9 },
    { name: "7 Iron", carryYards: 170, carrySd: 6, lateralSd: 7 },
    { name: "9 Iron", carryYards: 145, carrySd: 5, lateralSd: 6 },
    { name: "Pitching Wedge", carryYards: 125, carrySd: 4, lateralSd: 5 },
    { name: "Sand Wedge", carryYards: 95, carrySd: 4, lateralSd: 5 },
];

export function DispersionPanel() {
    const ui = useUiStore();
    const settings = useSettings();
    const clubs = useClubs();
    const qc = useQueryClient();

    async function seedSampleBag() {
        await deleteAllClubs();
        for (const c of SAMPLE_BAG) {
            await createClub({ id: newId(), ...c });
        }
        await qc.invalidateQueries({ queryKey: ["clubs"] });
    }

    async function clearAll() {
        await deleteAllClubs();
        await qc.invalidateQueries({ queryKey: ["clubs"] });
    }

    return (
        <div
            style={{
                fontFamily:
                    "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace",
                fontSize: 12,
                padding: 12,
                color: "#1a2419",
                background: "#f4efe3",
                height: "100%",
                overflow: "auto",
            }}
        >
            <Section title="App state">
                <Stat label="Clubs in DB">
                    {clubs.isLoading ? "…" : String(clubs.data?.length ?? 0)}
                </Stat>
                <Stat label="Cheatsheet open">{String(ui.cheatsheetOpen)}</Stat>
                <Stat label="newClub requests">
                    {String(ui.newClubRequestId)}
                </Stat>
                <Stat label="Unit">{settings.unit}</Stat>
                <Stat label="Onboarding done">
                    {String(settings.onboardingComplete)}
                </Stat>
            </Section>

            <Section title="Quick actions">
                <Btn onClick={ui.openCheatsheet}>Open Cheatsheet</Btn>
                <Btn onClick={ui.requestNewClub}>Request new club</Btn>
                <Btn
                    onClick={() =>
                        settings.setUnit(
                            settings.unit === "yards" ? "meters" : "yards",
                        )
                    }
                >
                    Toggle unit ({settings.unit})
                </Btn>
                <Btn onClick={() => void seedSampleBag()}>Seed sample bag</Btn>
                <Btn onClick={() => void clearAll()} danger>
                    Clear all clubs
                </Btn>
            </Section>

        </div>
    );
}

function Section({
    title,
    children,
}: {
    title: string;
    children: React.ReactNode;
}) {
    return (
        <div style={{ marginBottom: 16 }}>
            <div
                style={{
                    fontSize: 10,
                    letterSpacing: "0.18em",
                    textTransform: "uppercase",
                    opacity: 0.5,
                    marginBottom: 6,
                }}
            >
                {title}
            </div>
            <div style={{ display: "flex", flexDirection: "column", gap: 4 }}>
                {children}
            </div>
        </div>
    );
}

function Stat({
    label,
    children,
}: {
    label: string;
    children: React.ReactNode;
}) {
    return (
        <div style={{ display: "flex", justifyContent: "space-between" }}>
            <span style={{ opacity: 0.7 }}>{label}</span>
            <span style={{ fontWeight: 500 }}>{children}</span>
        </div>
    );
}

function Btn({
    onClick,
    danger,
    children,
}: {
    onClick: () => void;
    danger?: boolean;
    children: React.ReactNode;
}) {
    return (
        <button
            onClick={onClick}
            style={{
                fontFamily: "inherit",
                fontSize: 12,
                padding: "6px 10px",
                borderRadius: 999,
                border: `1px solid ${danger ? "#b91c1c40" : "#1a241920"}`,
                background: danger ? "#b91c1c10" : "#ffffff80",
                color: danger ? "#b91c1c" : "#1a2419",
                cursor: "pointer",
                textAlign: "left",
            }}
        >
            {children}
        </button>
    );
}
