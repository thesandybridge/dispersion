import { useMemo, useState } from "react";
import {
    accentColor,
    fontFamily,
    material as resolveMaterial,
    TAG_ACCENTS,
    TAG_FONTS,
    TAG_MATERIALS,
    useProfile,
    type ProfileAccent,
    type ProfileFont,
    type ProfileMaterial,
} from "../../lib/profileStore";
import { useClubs, useShotCounts } from "../../lib/queries";
import { DispersionGlyph } from "../primitives/DispersionGlyph";

export function BagTagPanel() {
    const profile = useProfile();
    const clubs = useClubs();
    const shotCounts = useShotCounts();
    const [editing, setEditing] = useState(false);

    const aggregated = useMemo(() => {
        const data = clubs.data ?? [];
        if (data.length === 0)
            return { carrySd: 5, lateralSd: 7, carry: 165 };
        const meanSd = (xs: number[]) =>
            xs.length === 0 ? 0 : xs.reduce((s, v) => s + v, 0) / xs.length;
        return {
            carrySd: meanSd(data.map((c) => c.carrySd)) || 5,
            lateralSd: meanSd(data.map((c) => c.lateralSd)) || 7,
            carry: meanSd(data.map((c) => c.carryYards)) || 165,
        };
    }, [clubs.data]);

    return (
        <div className="px-5 py-6 md:px-7 md:py-8 max-w-2xl mx-auto">
            <div className="flex items-center justify-between mb-5">
                <div>
                    <div
                        className="text-[10px] tracking-[0.2em] uppercase"
                        style={{ color: "rgba(26,36,25,0.5)" }}
                    >
                        Your tag
                    </div>
                    <div
                        className="font-display"
                        style={{
                            fontSize: 24,
                            letterSpacing: "-0.02em",
                            marginTop: 2,
                        }}
                    >
                        {editing ? "Customize" : "On the bag"}
                    </div>
                </div>
                <button
                    onClick={() => setEditing((v) => !v)}
                    className="px-3 py-1.5 rounded-full text-[12px]"
                    style={{
                        background: editing
                            ? "#1a2419"
                            : "rgba(26,36,25,0.06)",
                        color: editing ? "#f4efe3" : "#1a2419",
                    }}
                >
                    {editing ? "Done" : "Edit"}
                </button>
            </div>

            <BagTag
                name={profile.name}
                handicap={profile.handicap}
                homeCourse={profile.homeCourse}
                motto={profile.motto}
                accent={profile.accent}
                contact={profile.contact}
                font={profile.font}
                material={profile.material}
                clubs={clubs.data?.length ?? 0}
                shots={shotCounts.data?.total ?? 0}
                carrySd={aggregated.carrySd}
                lateralSd={aggregated.lateralSd}
            />

            {editing && (
                <div className="mt-7 grid gap-4">
                    <Field
                        label="Name"
                        value={profile.name}
                        onChange={(v) => profile.setProfile({ name: v })}
                        placeholder="Player name"
                    />
                    <div className="grid grid-cols-2 gap-3">
                        <Field
                            label="Handicap"
                            value={profile.handicap}
                            onChange={(v) =>
                                profile.setProfile({ handicap: v })
                            }
                            placeholder="4.2"
                        />
                        <Field
                            label="Home course"
                            value={profile.homeCourse}
                            onChange={(v) =>
                                profile.setProfile({ homeCourse: v })
                            }
                            placeholder="Pebble Hills GC"
                        />
                    </div>
                    <Field
                        label="Motto"
                        value={profile.motto}
                        onChange={(v) => profile.setProfile({ motto: v })}
                        placeholder='"Pick the safe shot."'
                    />
                    <Field
                        label="Contact"
                        value={profile.contact}
                        onChange={(v) =>
                            profile.setProfile({ contact: v })
                        }
                        placeholder="phone or email"
                    />

                    <PickerSection label="Font">
                        {TAG_FONTS.map((f) => {
                            const active = f.id === profile.font;
                            return (
                                <button
                                    key={f.id}
                                    onClick={() =>
                                        profile.setProfile({
                                            font: f.id as ProfileFont,
                                        })
                                    }
                                    className="px-3 py-1.5 rounded-full text-[13px]"
                                    style={{
                                        fontFamily: f.family,
                                        background: active
                                            ? "#1a2419"
                                            : "rgba(26,36,25,0.04)",
                                        color: active
                                            ? "#f4efe3"
                                            : "#1a2419",
                                        border: active
                                            ? "1px solid transparent"
                                            : "1px solid rgba(26,36,25,0.12)",
                                    }}
                                >
                                    {f.label}
                                </button>
                            );
                        })}
                    </PickerSection>

                    <PickerSection label="Strap material">
                        {TAG_MATERIALS.map((m) => {
                            const active = m.id === profile.material;
                            return (
                                <button
                                    key={m.id}
                                    onClick={() =>
                                        profile.setProfile({
                                            material: m.id as ProfileMaterial,
                                        })
                                    }
                                    className="flex items-center gap-2 px-3 py-1.5 rounded-full text-[12px]"
                                    style={{
                                        border: active
                                            ? `1.5px solid ${m.accent}`
                                            : "1px solid rgba(26,36,25,0.12)",
                                        background: active
                                            ? `${m.accent}1f`
                                            : "rgba(26,36,25,0.04)",
                                        color: "#1a2419",
                                    }}
                                >
                                    <span
                                        className="rounded-full"
                                        style={{
                                            width: 14,
                                            height: 14,
                                            background: `linear-gradient(180deg, ${m.strapTop} 0%, ${m.strapBottom} 100%)`,
                                            border: `1px solid ${m.grommet}`,
                                        }}
                                    />
                                    {m.label}
                                </button>
                            );
                        })}
                    </PickerSection>

                    <PickerSection label="Accent">
                        {TAG_ACCENTS.map((a) => {
                            const active = a.id === profile.accent;
                            return (
                                <button
                                    key={a.id}
                                    onClick={() =>
                                        profile.setProfile({
                                            accent: a.id as ProfileAccent,
                                        })
                                    }
                                    className="flex items-center gap-2 px-3 py-1.5 rounded-full text-[12px]"
                                    style={{
                                        border: active
                                            ? `1.5px solid ${a.value}`
                                            : "1px solid rgba(26,36,25,0.12)",
                                        background: active
                                            ? `${a.value}1a`
                                            : "rgba(26,36,25,0.04)",
                                        color: "#1a2419",
                                    }}
                                >
                                    <span
                                        className="w-3 h-3 rounded-full"
                                        style={{ background: a.value }}
                                    />
                                    {a.label}
                                </button>
                            );
                        })}
                    </PickerSection>
                </div>
            )}
        </div>
    );
}

function PickerSection({
    label,
    children,
}: {
    label: string;
    children: React.ReactNode;
}) {
    return (
        <div>
            <div
                className="text-[10px] tracking-[0.18em] uppercase mb-2"
                style={{ color: "rgba(26,36,25,0.55)" }}
            >
                {label}
            </div>
            <div className="flex flex-wrap gap-2">{children}</div>
        </div>
    );
}

function BagTag({
    name,
    handicap,
    homeCourse,
    motto,
    accent,
    contact,
    font,
    material,
    clubs,
    shots,
    carrySd,
    lateralSd,
}: {
    name: string;
    handicap: string;
    homeCourse: string;
    motto: string;
    accent: ProfileAccent;
    contact: string;
    font: ProfileFont;
    material: ProfileMaterial;
    clubs: number;
    shots: number;
    carrySd: number;
    lateralSd: number;
}) {
    const c = accentColor(accent);
    const ff = fontFamily(font);
    const mat = resolveMaterial(material);
    const initials =
        (name || "—")
            .split(/\s+/)
            .map((p) => p[0])
            .filter(Boolean)
            .slice(0, 2)
            .join("")
            .toUpperCase() || "—";

    return (
        <div className="relative mx-auto" style={{ maxWidth: 420 }}>
            {/* loop strap */}
            <div
                className="mx-auto mb-[-8px] h-7 w-12 relative z-10"
                style={{
                    background: `linear-gradient(180deg, ${mat.strapTop} 0%, ${mat.strapBottom} 100%)`,
                    borderRadius: "12px 12px 6px 6px",
                    boxShadow:
                        "inset 0 1px 0 rgba(255,255,255,0.18), 0 2px 4px rgba(0,0,0,0.25)",
                }}
            >
                <div
                    className="absolute left-1/2 top-2.5 -translate-x-1/2 rounded-full"
                    style={{
                        width: 10,
                        height: 10,
                        background: mat.grommet,
                        boxShadow: "inset 0 1px 1px rgba(0,0,0,0.6)",
                    }}
                />
            </div>

            <div
                className="relative rounded-[26px] overflow-hidden"
                style={{
                    background:
                        "linear-gradient(180deg, #1f2a23 0%, #131c16 60%, #0d1410 100%)",
                    boxShadow:
                        "0 24px 50px rgba(0,0,0,0.32), 0 8px 18px rgba(0,0,0,0.18), inset 0 1px 0 rgba(246,241,225,0.08)",
                    color: "#f6f1e1",
                }}
            >
                {/* corner punch hole */}
                <div
                    className="absolute top-3 right-3 rounded-full z-10"
                    style={{
                        width: 14,
                        height: 14,
                        background: mat.grommet,
                        boxShadow:
                            "inset 0 1px 1px rgba(0,0,0,0.6), 0 0 0 2px rgba(246,241,225,0.06)",
                    }}
                />

                {/* accent bar along left */}
                <div
                    className="absolute left-0 top-0 bottom-0"
                    style={{
                        width: 6,
                        background: `linear-gradient(180deg, ${c} 0%, ${c}80 100%)`,
                    }}
                />

                {/* dispersion stamp watermark */}
                <div
                    className="absolute pointer-events-none"
                    style={{
                        right: -32,
                        bottom: -28,
                        opacity: 0.18,
                        transform: "rotate(-12deg)",
                    }}
                >
                    <DispersionStamp
                        carrySd={carrySd}
                        lateralSd={lateralSd}
                        accent={c}
                    />
                </div>

                <div className="pl-7 pr-6 pt-7 pb-6 relative">
                    <div className="flex items-start justify-between gap-3">
                        <div>
                            <div
                                className="text-[10px] tracking-[0.24em] uppercase"
                                style={{ color: c }}
                            >
                                ◆ Dispersion · Bag tag
                            </div>
                            <div
                                style={{
                                    fontFamily: ff,
                                    fontSize: "clamp(34px, 8vw, 44px)",
                                    letterSpacing: "-0.02em",
                                    color: "#f6f1e1",
                                    marginTop: 6,
                                    lineHeight: 1.05,
                                    fontWeight: font === "mono" ? 500 : 400,
                                }}
                            >
                                {name || "Set your name"}
                            </div>
                            {homeCourse && (
                                <div
                                    className="font-mono text-[11px] mt-2 tracking-[0.04em]"
                                    style={{
                                        color: "rgba(246,241,225,0.55)",
                                    }}
                                >
                                    {homeCourse}
                                </div>
                            )}
                        </div>
                        <Monogram
                            letters={initials}
                            accent={c}
                            font={ff}
                        />
                    </div>

                    {motto && (
                        <div
                            className="italic mt-4 text-[15px] leading-snug"
                            style={{
                                color: c,
                                fontFamily: ff,
                            }}
                        >
                            “{motto}”
                        </div>
                    )}

                    <div
                        className="grid grid-cols-3 gap-3 mt-5 pt-5"
                        style={{
                            borderTop:
                                "1px dashed rgba(246,241,225,0.14)",
                        }}
                    >
                        <Stat
                            label="Hcp"
                            value={handicap || "—"}
                            accent={c}
                            font={ff}
                        />
                        <Stat
                            label="Clubs"
                            value={String(clubs)}
                            accent={c}
                            font={ff}
                            mono
                        />
                        <Stat
                            label="Shots"
                            value={shots.toLocaleString()}
                            accent={c}
                            font={ff}
                            mono
                        />
                    </div>

                    <div
                        className="mt-5 pt-3.5 flex items-center justify-between"
                        style={{
                            borderTop: "1px solid rgba(246,241,225,0.08)",
                        }}
                    >
                        <div className="flex items-center gap-2">
                            <DispersionGlyph
                                carrySd={carrySd}
                                lateralSd={lateralSd}
                                width={28}
                                height={18}
                                fill={c}
                                stroke={c}
                            />
                            <div
                                className="font-mono text-[10px] tracking-[0.16em] uppercase"
                                style={{ color: "rgba(246,241,225,0.45)" }}
                            >
                                σ {carrySd.toFixed(1)} × {lateralSd.toFixed(1)}
                            </div>
                        </div>
                        {contact && (
                            <div
                                className="font-mono text-[10px]"
                                style={{
                                    color: "rgba(246,241,225,0.55)",
                                }}
                            >
                                {contact}
                            </div>
                        )}
                    </div>
                </div>
            </div>
        </div>
    );
}

function DispersionStamp({
    carrySd,
    lateralSd,
    accent,
}: {
    carrySd: number;
    lateralSd: number;
    accent: string;
}) {
    const w = 220;
    const h = 220;
    const cx = w / 2;
    const cy = h / 2;
    const facets = 28;
    const baseRY = 80;
    const baseRX = baseRY * (lateralSd / Math.max(carrySd, 0.01));
    const rx = Math.min(95, Math.max(20, baseRX));
    const ry = baseRY;
    const rings = [2.6, 2.0, 1.4, 0.8].map((k) => {
        const pts: string[] = [];
        for (let i = 0; i < facets; i++) {
            const t = (i / facets) * Math.PI * 2;
            const x = cx + Math.cos(t) * rx * (k / 2.6);
            const y = cy + Math.sin(t) * ry * (k / 2.6);
            pts.push(`${x.toFixed(1)},${y.toFixed(1)}`);
        }
        return { d: `M${pts.join(" L")} Z`, k };
    });
    return (
        <svg width={w} height={h} viewBox={`0 0 ${w} ${h}`}>
            <g fill="none" stroke={accent} strokeWidth="0.8">
                {rings.map((r, i) => (
                    <path key={i} d={r.d} opacity={0.4 + i * 0.15} />
                ))}
            </g>
            <circle cx={cx} cy={cy} r="2" fill={accent} />
        </svg>
    );
}

function Monogram({
    letters,
    accent,
    font,
}: {
    letters: string;
    accent: string;
    font: string;
}) {
    return (
        <div
            className="shrink-0 flex items-center justify-center rounded-full"
            style={{
                width: 56,
                height: 56,
                background: "rgba(246,241,225,0.06)",
                border: `1.5px solid ${accent}`,
                color: accent,
                fontFamily: font,
                fontSize: 22,
                letterSpacing: "0.04em",
                fontFeatureSettings: '"tnum"',
            }}
        >
            {letters}
        </div>
    );
}

function Stat({
    label,
    value,
    accent,
    font,
    mono,
}: {
    label: string;
    value: string;
    accent: string;
    font: string;
    mono?: boolean;
}) {
    return (
        <div>
            <div
                className="text-[9px] tracking-[0.18em] uppercase"
                style={{ color: accent }}
            >
                {label}
            </div>
            <div
                className={mono ? "tabular" : "tabular"}
                style={{
                    fontFamily: mono ? "var(--font-mono)" : font,
                    fontSize: mono ? 18 : 24,
                    color: "#f6f1e1",
                    marginTop: 2,
                    letterSpacing: mono ? "0" : "-0.01em",
                }}
            >
                {value}
            </div>
        </div>
    );
}

function Field({
    label,
    value,
    onChange,
    placeholder,
}: {
    label: string;
    value: string;
    onChange: (v: string) => void;
    placeholder?: string;
}) {
    return (
        <label className="block">
            <div
                className="text-[10px] tracking-[0.18em] uppercase mb-1.5"
                style={{ color: "rgba(26,36,25,0.55)" }}
            >
                {label}
            </div>
            <input
                type="text"
                value={value}
                onChange={(e) => onChange(e.target.value)}
                placeholder={placeholder}
                className="w-full px-3 py-2 rounded-lg bg-white outline-none"
                style={{
                    border: "1px solid rgba(26,36,25,0.15)",
                    color: "#1a2419",
                    fontSize: 16,
                }}
            />
        </label>
    );
}
