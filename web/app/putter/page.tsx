import type { Metadata } from "next";
import Link from "next/link";
import { PageLayout } from "@/components/PageLayout";
import { FeatureWalkthroughList } from "@/components/FeatureWalkthrough";

export const metadata: Metadata = {
  title: "Putter mode — practice with make rate by distance and lag stats",
  description:
    "Putter is its own thing in Dispersion — separate model, separate stats, separate practice mode. A linear putting lane, distance brackets from 0–3 ft to 30+ ft, lag-putt proximity tracking, and a session that's yours to save or end.",
  alternates: { canonical: "/putter" },
  openGraph: {
    title: "Putter mode — Dispersion",
    description:
      "Linear putting lane. Make rate by distance bracket. Lag-putt proximity. Sessions are independent of the rest of your bag.",
    url: "/putter",
  },
};

const accentStrong = { color: "var(--accent-strong)" };

// ─── Editorial visual frame ──────────────────────────────────────────

function VisualFrame({ children, label, dark = false }: { children: React.ReactNode; label?: string; dark?: boolean }) {
  return (
    <div
      className="overflow-hidden rounded-3xl"
      style={{
        background: dark
          ? "linear-gradient(180deg, #0d4634 0%, #082819 100%)"
          : "var(--bg-elevated)",
        boxShadow:
          "0 0 0 1px var(--border), 0 32px 64px -32px rgba(11, 61, 46, 0.20), 0 8px 16px -8px rgba(0,0,0,0.06)",
      }}
    >
      {label && (
        <div
          className="flex items-center justify-between border-b px-5 py-3 font-mono text-[10px] uppercase tracking-[0.2em]"
          style={{
            borderColor: dark ? "rgba(246,241,225,0.10)" : "var(--border)",
            color: dark ? "rgba(246,241,225,0.55)" : "var(--fg-muted)",
          }}
        >
          <span>{label}</span>
          <span className="flex gap-1.5">
            <span className="h-1.5 w-1.5 rounded-full" style={{ background: "currentColor", opacity: 0.4 }} />
            <span className="h-1.5 w-1.5 rounded-full" style={{ background: "currentColor", opacity: 0.4 }} />
            <span className="h-1.5 w-1.5 rounded-full" style={{ background: "currentColor", opacity: 0.4 }} />
          </span>
        </div>
      )}
      {children}
    </div>
  );
}

// ─── Visuals ─────────────────────────────────────────────────────────

/// Linear putting lane — mirrors the iOS PuttingGreenField. Cup at top,
/// "you" tee at bottom, distance ticks along the centerline, a
/// dispersed cluster of made/missed putts on the green.
function LaneVisual() {
  return (
    <VisualFrame label="Putt · 6 ft practice" dark>
      <div className="relative aspect-[3/4] w-full">
        <svg
          viewBox="0 0 300 400"
          className="absolute inset-0 h-full w-full"
          aria-hidden="true"
        >
          <defs>
            <radialGradient id="green" cx="50%" cy="55%" r="68%">
              <stop offset="0%" stopColor="#62b375" stopOpacity="0.30" />
              <stop offset="60%" stopColor="#2c8a5e" stopOpacity="0.20" />
              <stop offset="100%" stopColor="#0b3d2e" stopOpacity="0.32" />
            </radialGradient>
          </defs>

          <rect width="300" height="400" fill="url(#green)" />

          {/* Centerline (cup → tee) */}
          <line
            x1="150" y1="44" x2="150" y2="352"
            stroke="rgba(255,255,255,0.12)" strokeWidth="1"
          />

          {/* Distance ticks on the right (1 ft @ 6 ft span) */}
          {[1, 2, 3, 4, 5].map((ft) => {
            const y = 44 + (ft / 6) * (352 - 44);
            return (
              <g key={ft}>
                <line
                  x1="156" y1={y} x2="164" y2={y}
                  stroke="rgba(255,255,255,0.32)"
                  strokeWidth="0.8"
                />
                <text
                  x="170" y={y + 3}
                  fontFamily="ui-monospace, SFMono-Regular, monospace"
                  fontSize="10"
                  fill="rgba(255,255,255,0.50)"
                >
                  {ft}
                </text>
              </g>
            );
          })}

          {/* Cup — concentric rim + hole */}
          <circle cx="150" cy="44" r="11" fill="rgba(255,255,255,0.10)" />
          <circle cx="150" cy="44" r="8" fill="rgba(0,0,0,0.78)" stroke="rgba(255,255,255,0.55)" strokeWidth="1" />

          {/* Tee marker — small dot with faint ring */}
          <circle cx="150" cy="352" r="4" fill="rgba(255,255,255,0.45)" />
          <circle cx="150" cy="352" r="7" fill="none" stroke="rgba(255,255,255,0.18)" strokeWidth="0.8" />

          {/* Sample landings */}
          {[
            { x: 152, y: 48,  made: true },   // tap-in
            { x: 158, y: 70,  made: false },
            { x: 144, y: 90,  made: false },
            { x: 154, y: 60,  made: true },
            { x: 168, y: 110, made: false },
            { x: 138, y: 100, made: false },
          ].map((p, i) => (
            <g key={i}>
              <circle
                cx={p.x} cy={p.y} r="11"
                fill="#62b375" fillOpacity={p.made ? "0.30" : "0.10"}
              />
              <circle
                cx={p.x} cy={p.y} r={p.made ? "5" : "4"}
                fill={p.made ? "#62b375" : "rgba(246, 241, 225, 0.85)"}
                stroke="rgba(255,255,255,0.7)"
                strokeWidth="1"
              />
            </g>
          ))}

          {/* Live drag preview (cursor at ~3.4 ft past center, slight right) */}
          <line
            x1="150" y1="44" x2="159" y2="180"
            stroke="#62b375" strokeWidth="1" strokeDasharray="3 3" opacity="0.7"
          />
          <circle cx="159" cy="180" r="14" fill="#62b375" fillOpacity="0.28" />
          <circle cx="159" cy="180" r="6" fill="#62b375" stroke="rgba(255,255,255,0.7)" strokeWidth="1.2" />
        </svg>

        {/* Drag readout badge */}
        <div className="absolute left-1/2 top-3 -translate-x-1/2">
          <div
            className="flex items-center gap-1.5 rounded-full px-3 py-1.5 font-mono text-[11px] font-semibold"
            style={{
              background: "rgba(0,0,0,0.65)",
              color: "#f6f1e1",
              boxShadow: "inset 0 0 0 1px rgba(246,241,225,0.30)",
            }}
          >
            <svg viewBox="0 0 24 24" fill="none" strokeWidth="2" stroke="currentColor" className="h-3 w-3">
              <path d="M3 3l18 18M3 21L21 3" strokeLinecap="round" />
            </svg>
            2.7 ft
          </div>
        </div>
      </div>
    </VisualFrame>
  );
}

/// Vertical column of session dots — newest at top, makes filled, misses
/// hollow. Same idiom as the iOS app's session dot column.
function SessionDotsVisual() {
  const putts: { made: boolean }[] = [
    { made: true },
    { made: false },
    { made: true },
    { made: true },
    { made: false },
    { made: true },
    { made: true },
    { made: false },
    { made: true },
    { made: true },
    { made: true },
    { made: false },
  ];
  const makes = putts.filter((p) => p.made).length;
  return (
    <VisualFrame label="Session dots">
      <div className="flex items-center gap-6 p-7">
        <div
          className="flex flex-col items-center rounded-xl px-3 py-3"
          style={{
            background: "var(--bg)",
            boxShadow: "0 0 0 1px var(--border)",
            minWidth: 48,
          }}
        >
          <span
            className="font-mono text-base font-semibold tabular-nums"
            style={accentStrong}
          >
            {putts.length}
          </span>
          <span
            className="mt-0.5 font-mono text-[8px] font-medium"
            style={{ color: "var(--fg-muted)", letterSpacing: "0.14em" }}
          >
            PUTTS
          </span>
        </div>

        <div className="flex flex-col gap-1.5">
          {putts.map((p, i) => {
            const opacity = Math.max(0.4, 1 - i * 0.05);
            return p.made ? (
              <span
                key={i}
                className="block h-3 w-3 rounded-full"
                style={{
                  background: "var(--accent)",
                  opacity,
                  boxShadow: "inset 0 0 0 0.5px rgba(255,255,255,0.35)",
                }}
              />
            ) : (
              <span
                key={i}
                className="block h-3 w-3 rounded-full border-[1.5px]"
                style={{
                  borderColor: "var(--fg-soft)",
                  opacity,
                }}
              />
            );
          })}
        </div>

        <div className="flex-1">
          <div className="flex items-baseline gap-2">
            <span
              className="font-display text-3xl font-semibold tabular-nums"
              style={accentStrong}
            >
              {Math.round((makes / putts.length) * 100)}%
            </span>
            <span className="font-mono text-xs" style={{ color: "var(--fg-muted)" }}>
              made · this session
            </span>
          </div>
          <div className="mt-1 font-mono text-[11px]" style={{ color: "var(--fg-soft)" }}>
            {makes} of {putts.length} from 6 ft
          </div>
        </div>
      </div>
    </VisualFrame>
  );
}

/// Make-rate-by-bracket horizontal bar chart, mirrors PutterDetailView.
function BracketBreakdownVisual() {
  const brackets: { label: string; attempts: number; makes: number }[] = [
    { label: "0–3", attempts: 24, makes: 23 },
    { label: "3–6", attempts: 38, makes: 28 },
    { label: "6–15", attempts: 42, makes: 18 },
    { label: "15–30", attempts: 22, makes: 4 },
    { label: "30+", attempts: 8, makes: 1 },
  ];
  const barColor = (pct: number) =>
    pct >= 0.7 ? "var(--accent)" : pct >= 0.45 ? "var(--accent-soft)" : pct >= 0.20 ? "#e6c068" : "#c87060";

  return (
    <VisualFrame label="Make rate by distance">
      <div className="space-y-2 p-7">
        {brackets.map((b) => {
          const pct = b.makes / b.attempts;
          return (
            <div key={b.label} className="flex items-center gap-3">
              <span
                className="w-12 font-mono text-[11px] font-medium"
                style={{ color: "var(--fg-muted)" }}
              >
                {b.label}
              </span>
              <div
                className="relative h-2 flex-1 overflow-hidden rounded-full"
                style={{ background: "var(--border)" }}
              >
                <span
                  className="absolute inset-y-0 left-0 rounded-full"
                  style={{
                    width: `${Math.max(pct * 100, 4)}%`,
                    background: barColor(pct),
                  }}
                />
              </div>
              <span
                className="font-mono text-[11px] tabular-nums"
                style={{ color: "var(--fg-muted)" }}
              >
                {b.makes}/{b.attempts}
              </span>
              <span
                className="w-10 text-right font-mono text-[12px] font-semibold tabular-nums"
                style={accentStrong}
              >
                {Math.round(pct * 100)}%
              </span>
            </div>
          );
        })}
      </div>
    </VisualFrame>
  );
}

/// Save / End / Undo pills as they appear in the iOS app.
function ActionPillsVisual() {
  return (
    <VisualFrame label="Session actions">
      <div className="flex flex-col items-center gap-6 p-10">
        <div className="flex flex-wrap items-center justify-center gap-2">
          <Pill icon="undo" label="Undo" />
          <Pill icon="check" label="Save" tinted="accent" />
          <Pill icon="trash" label="End" tinted="danger" />
        </div>

        <div className="space-y-3 text-center text-sm" style={{ color: "var(--fg-soft)" }}>
          <div>
            <strong style={accentStrong}>Save</strong> commits the session.
            Your putts stay in the database; the session resets.
          </div>
          <div>
            <strong style={{ color: "var(--accent)" }}>Undo</strong> removes only the last putt.
          </div>
          <div>
            <strong style={{ color: "#c87060" }}>End</strong> deletes every putt logged in the session. Confirm before discarding.
          </div>
        </div>
      </div>
    </VisualFrame>
  );
}

function Pill({ icon, label, tinted }: { icon: "undo" | "check" | "trash"; label: string; tinted?: "accent" | "danger" }) {
  const tint = tinted === "accent" ? "var(--accent)" : tinted === "danger" ? "#c87060" : "var(--fg)";
  const ring = tinted ? `${tint}` : "var(--border-strong)";
  const Icon = () => {
    switch (icon) {
      case "undo":
        return (
          <svg viewBox="0 0 24 24" fill="none" strokeWidth="2" stroke="currentColor" className="h-3 w-3">
            <path d="M9 14L4 9l5-5M4 9h11a5 5 0 110 10h-3" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
        );
      case "check":
        return (
          <svg viewBox="0 0 24 24" fill="currentColor" className="h-3 w-3">
            <circle cx="12" cy="12" r="10" />
            <path d="M8.5 12.5l2.5 2.5 4.5-5" stroke="var(--bg-elevated)" strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
        );
      case "trash":
        return (
          <svg viewBox="0 0 24 24" fill="currentColor" className="h-3 w-3">
            <path d="M5 7h14l-1 13a2 2 0 01-2 2H8a2 2 0 01-2-2L5 7zM9 4h6l1 3H8l1-3z" />
          </svg>
        );
    }
  };
  return (
    <span
      className="inline-flex items-center gap-1.5 rounded-full px-3 py-1.5 font-mono text-[11px] font-medium"
      style={{
        color: tint,
        background: "var(--bg-elevated)",
        boxShadow: `inset 0 0 0 1px ${ring}, 0 4px 12px -4px rgba(0,0,0,0.10)`,
      }}
    >
      <Icon />
      {label}
    </span>
  );
}

// ─── Page ────────────────────────────────────────────────────────────

export default function PutterPage() {
  return (
    <PageLayout
      eyebrow="Putter mode"
      title={
        <>
          The putter is{" "}
          <span className="italic" style={{ color: "var(--accent)" }}>
            its own thing.
          </span>
        </>
      }
      lede="Putting isn't aerial dispersion — it's distance control on a green. Dispersion gives the putter a separate model, separate stats, and a practice mode built around how a real putt actually feels: a line down a lane, a cup at the end."
    >
      <section className="container-prose pt-16 pb-20 sm:pt-24">
        <FeatureWalkthroughList
          steps={[
            {
              eyebrow: "The lane",
              title: "Tap or drag where the ball stopped.",
              body: (
                <>
                  Pick a distance. The lane scales — cup at the top, your tee
                  at the bottom, distance ticks running up the centerline.
                  Tap or drag anywhere on the green to log where the ball
                  came to rest. Inside the cup zone counts as a make;
                  everywhere else, the residual distance feeds the lag-putt
                  stats.
                </>
              ),
              bullets: [
                "Distance picker: 2 / 3 / 5 / 8 / 10 / 15 / 20 / 30 ft",
                "Live drag readout shows make-or-miss + residual feet",
                "Latest landing keeps a halo while you queue the next putt",
              ],
              visual: <LaneVisual />,
            },
            {
              eyebrow: "Session dots",
              title: "See the whole session at a glance.",
              body: (
                <>
                  A vertical dot column on the left edge of the green tracks
                  every putt this session — newest on top. Filled accent for
                  makes, hollow rings for misses, older dots fade as the
                  column grows. Above the dots: a counter pill with the live
                  total.
                </>
              ),
              bullets: [
                "One dot per logged putt, color-coded make / miss",
                "Newest on top, oldest fades down",
                "Counter pill always visible — never lose track of the count",
              ],
              visual: <SessionDotsVisual />,
            },
            {
              eyebrow: "Bracket breakdown",
              title: "Honest stats at every distance.",
              body: (
                <>
                  Putter detail in the bag screen breaks your make rate down
                  by bracket — 0–3 ft, 3–6 ft, 6–15 ft, 15–30 ft, 30+ ft.
                  Bars are color-coded against PGA tour benchmarks so you
                  can see where the work is. Lag-putt proximity (how far
                  past or short of the cup the ball ends up on a miss) is
                  averaged across all your missed putts.
                </>
              ),
              bullets: [
                "Five distance brackets with a color-coded percentage",
                "Average lag proximity computed from missed putts",
                "Sessions and total-putt counters in the header card",
              ],
              visual: <BracketBreakdownVisual />,
            },
            {
              eyebrow: "Save · Undo · End",
              title: "Sessions you actually control.",
              body: (
                <>
                  The putter session is local to the practice screen — it
                  doesn't hijack the live range or course tracker. Save
                  commits the session and clears the screen so you can start
                  fresh. End deletes everything logged in the session
                  (confirm dialog with the count). Undo removes only the
                  most recent putt.
                </>
              ),
              bullets: [
                "Save — commit + clear, putts stay in the database",
                "Undo — remove only the last putt",
                "End — discard the entire session, with a confirm dialog",
                "Independent of the rest of the app's session state",
              ],
              visual: <ActionPillsVisual />,
            },
          ]}
        />
      </section>

      <section className="surface-elev border-t py-16" style={{ borderColor: "var(--border)" }}>
        <div className="container-prose flex flex-col items-start gap-6 md:flex-row md:items-center md:justify-between">
          <div>
            <span className="eyebrow">More</span>
            <h3
              className="mt-2 font-display text-2xl font-semibold tracking-tight"
              style={accentStrong}
            >
              See the math behind the rest of the bag.
            </h3>
          </div>
          <Link
            href="/math"
            className="inline-flex items-center gap-2 rounded-full px-5 py-2.5 text-base font-medium transition"
            style={{ background: "var(--accent-strong)", color: "var(--bg)" }}
          >
            The math
            <svg viewBox="0 0 24 24" fill="none" strokeWidth="2" stroke="currentColor" className="h-4 w-4">
              <path d="M5 12h14M13 5l7 7-7 7" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
          </Link>
        </div>
      </section>
    </PageLayout>
  );
}
