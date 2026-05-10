import type { Metadata } from "next";
import Link from "next/link";
import { PageLayout } from "@/components/PageLayout";
import { FeatureWalkthroughList } from "@/components/FeatureWalkthrough";
import { DispersionCanvas } from "@/components/DispersionCanvas";

export const metadata: Metadata = {
  title: "Range mode — calibrate your bag, watch your sigma tighten",
  description:
    "Range mode in Dispersion is where you teach the app your dispersion. Tap to log shots, watch σ update live, save calibration when the confidence is there. Personal-best banners, swing-type tags, miss-direction analytics built in.",
  alternates: { canonical: "/range" },
  openGraph: {
    title: "Range mode — Dispersion",
    description:
      "Tap to log shots, watch σ update live, save calibration when confidence is there.",
    url: "/range",
  },
};

const accentStrong = { color: "var(--accent-strong)" };

// ─── Editorial visual frame ───────────────────────────────────────────

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

function RadarVisual() {
  return (
    <VisualFrame label="Range · radar" dark>
      <div className="relative aspect-square w-full">
        <DispersionCanvas
          carry={158}
          carrySd={6}
          lateralSd={9}
          distanceToTarget={158}
          zoneWidth={25}
          zoneDepth={25}
          zoneKind="green"
        />
      </div>
      <div
        className="grid grid-cols-3 divide-x px-1"
        style={{
          background: "rgba(0,0,0,0.30)",
          color: "#e8efe5",
        }}
      >
        {[
          { label: "σ↕", value: "6.0" },
          { label: "σ↔", value: "9.0" },
          { label: "n", value: "14" },
        ].map((s) => (
          <div key={s.label} className="px-4 py-3 text-center" style={{ borderColor: "rgba(246,241,225,0.08)" }}>
            <div className="font-mono text-[10px] uppercase tracking-[0.2em]" style={{ color: "rgba(246,241,225,0.55)" }}>
              {s.label}
            </div>
            <div className="mt-0.5 font-display text-xl font-semibold tabular-nums" style={{ color: "#a9d18e" }}>
              {s.value}
            </div>
          </div>
        ))}
      </div>
    </VisualFrame>
  );
}

function CalibrationVisual() {
  const filled = 14;
  const total = 30;
  return (
    <VisualFrame label="Calibration · 7 Iron">
      <div className="p-6 sm:p-8">
        <div className="flex items-baseline justify-between">
          <div>
            <span
              className="font-display text-6xl font-semibold tabular-nums"
              style={accentStrong}
            >
              14
            </span>
            <span className="surface-muted ml-2 text-base">/ 30</span>
          </div>
          <span
            className="rounded-full px-3 py-1 font-mono text-[10px] uppercase tracking-[0.2em]"
            style={{ background: "var(--accent-tint)", color: "var(--accent)" }}
          >
            Good
          </span>
        </div>

        <div
          className="mt-5 grid grid-cols-[repeat(30,minmax(0,1fr))] gap-1"
          aria-hidden
        >
          {Array.from({ length: total }).map((_, i) => (
            <span
              key={i}
              className="h-2 rounded-full"
              style={{
                background:
                  i < filled ? "var(--accent)" : "var(--border)",
              }}
            />
          ))}
        </div>

        <div
          className="mt-6 flex flex-col gap-2 border-t pt-5"
          style={{ borderColor: "var(--border)" }}
        >
          <div className="flex items-baseline justify-between">
            <span className="font-mono text-[10px] uppercase tracking-[0.2em] surface-muted">
              Stored
            </span>
            <span className="font-mono text-sm" style={accentStrong}>
              σ↕ 6.5 &nbsp; σ↔ 9.5
            </span>
          </div>
          <div className="flex items-baseline justify-between">
            <span
              className="font-mono text-[10px] uppercase tracking-[0.2em]"
              style={{ color: "var(--accent)" }}
            >
              Measured
            </span>
            <span className="font-mono text-sm" style={accentStrong}>
              σ↕ 5.9 <span style={{ color: "var(--accent)" }}>↓0.6</span>
              &nbsp; σ↔ 8.7 <span style={{ color: "var(--accent)" }}>↓0.8</span>
            </span>
          </div>
        </div>
      </div>
    </VisualFrame>
  );
}

function InsightsVisual() {
  return (
    <div className="space-y-4">
      <PBBanner />
      <SessionStripCard />
      <ClubDeltaCard />
    </div>
  );
}

function PBBanner() {
  return (
    <div
      className="flex items-center gap-3 rounded-2xl px-5 py-4"
      style={{
        background: "var(--accent-tint)",
        boxShadow: "0 0 0 1px var(--accent)",
      }}
    >
      <svg viewBox="0 0 24 24" fill="none" className="h-5 w-5 flex-shrink-0" style={{ color: "var(--accent)" }}>
        <path
          d="M12 2l2.4 5 5.6.8-4 4 1 5.6L12 14.8 6.9 17.4l1-5.6-4-4 5.6-.8L12 2z"
          fill="currentColor"
        />
      </svg>
      <div className="flex-1">
        <div className="font-mono text-[10px] uppercase tracking-[0.2em]" style={{ color: "var(--accent)" }}>
          Personal best
        </div>
        <div className="mt-0.5 text-sm font-medium" style={accentStrong}>
          Tightest σ↕ this session
        </div>
      </div>
    </div>
  );
}

function SessionStripCard() {
  return (
    <div
      className="rounded-2xl px-2 py-1"
      style={{
        background: "var(--bg-elevated)",
        boxShadow: "0 0 0 1px var(--border)",
      }}
    >
      <div className="grid grid-cols-3 divide-x" style={{ color: "var(--border)" }}>
        {[
          { label: "shots", value: "14", delta: null },
          { label: "σ↕", value: "5.9", delta: "↓0.6" },
          { label: "σ↔", value: "8.7", delta: "↓0.8" },
        ].map((c) => (
          <div key={c.label} className="px-4 py-3 text-center">
            <div className="font-display text-2xl font-semibold tabular-nums" style={accentStrong}>
              {c.value}
            </div>
            <div className="mt-0.5 flex items-center justify-center gap-1.5 font-mono text-[10px] uppercase tracking-[0.15em] surface-muted">
              <span>{c.label}</span>
              {c.delta && <span style={{ color: "var(--accent)" }}>{c.delta}</span>}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

function ClubDeltaCard() {
  return (
    <div
      className="rounded-2xl p-5"
      style={{
        background: "var(--bg-elevated)",
        boxShadow: "0 0 0 1px var(--border)",
      }}
    >
      <div className="flex items-baseline justify-between">
        <span className="font-display text-lg font-semibold" style={accentStrong}>
          7 Iron
        </span>
        <span
          className="rounded-full px-2.5 py-0.5 font-mono text-[10px]"
          style={{ background: "var(--accent-tint)", color: "var(--accent)" }}
        >
          leans L 4y
        </span>
      </div>
      <div className="mt-4 grid grid-cols-2 gap-6">
        <div>
          <div className="flex items-baseline gap-1">
            <span className="font-display text-3xl font-semibold tabular-nums" style={accentStrong}>
              5.9
            </span>
            <span className="font-mono text-xs surface-muted">σ↕</span>
          </div>
          <div className="mt-1 flex flex-col font-mono text-[10px]" style={{ color: "var(--accent)" }}>
            <span>↓0.6 vs stored</span>
            <span className="surface-muted">↓0.8 vs prev</span>
          </div>
        </div>
        <div>
          <div className="flex items-baseline gap-1">
            <span className="font-display text-3xl font-semibold tabular-nums" style={accentStrong}>
              8.7
            </span>
            <span className="font-mono text-xs surface-muted">σ↔</span>
          </div>
          <div className="mt-1 flex flex-col font-mono text-[10px]" style={{ color: "var(--accent)" }}>
            <span>↓0.8 vs stored</span>
            <span className="surface-muted">↓1.1 vs prev</span>
          </div>
        </div>
      </div>
    </div>
  );
}

// ─── Page ─────────────────────────────────────────────────────────────

export default function RangePage() {
  return (
    <PageLayout
      eyebrow="Range mode"
      title={
        <>
          Calibrate your bag.{" "}
          <span className="italic" style={{ color: "var(--accent)" }}>
            Watch your sigma tighten.
          </span>
        </>
      }
      lede="Range mode is where the recommendations earn their accuracy. Pick a club, set a target, log shots — and the σ values for that club update live, shot by shot, until you've got a sample big enough to trust."
    >
      <section className="container-prose pt-16 pb-20 sm:pt-24">
        <FeatureWalkthroughList
          steps={[
            {
              eyebrow: "The radar",
              title: "Tap to log a shot. Drag for manual entry.",
              body: (
                <>
                  The center of the screen is a live radar showing where your
                  shots have landed relative to the target. Tap anywhere to
                  log the shot you just hit — the app records the carry and
                  lateral delta, computes σ across the session so far, and
                  pops a confirmation sheet for outcome tags + face strikes.
                  Manual entry is one toolbar tap away if you'd rather type
                  the numbers in.
                </>
              ),
              visual: <RadarVisual />,
            },
            {
              eyebrow: "Calibration confidence",
              title: "Save when the math says you're ready.",
              body: (
                <>
                  Range mode tracks how much sample you have on the active
                  club. Below 10 shots, calibration is gated — saving could
                  poison good stored σ with noise. From 10 to 30, you're at{" "}
                  <em>Good</em> confidence. Past 30, <em>High</em>. Each tier
                  is shown plainly, and the calibration sheet renders the
                  side-by-side stored vs measured ellipse before you commit.
                </>
              ),
              bullets: [
                "Sample-size dots show progress at a glance",
                "Stored vs measured ellipses overlay before you save",
                "Numeric diff (carry, σ↕, σ↔) with directional arrows",
              ],
              visual: <CalibrationVisual />,
            },
            {
              eyebrow: "Session insights",
              title: "Every shot gets a live verdict.",
              body: (
                <>
                  The shot-confirm drawer that pops up after every tap shows
                  this session's running stats — shot count, current σ↕,
                  σ↔ — plus arrows that tell you how the shot you just hit
                  moved each metric. When a shot crowns a session-best
                  (tightest σ↕, longest carry, etc.), a personal-best banner
                  fires.
                </>
              ),
              bullets: [
                "Live σ deltas with up/down arrows",
                "Personal-best detection per session",
                "Miss-direction summary tags (\"leans L 4y\")",
                "Swing-type chips (full / 3⁄4 / half)",
                "Outcome chips (in / short / long / left / right / penalty)",
              ],
              visual: <InsightsVisual />,
            },
          ]}
        />
      </section>

      <section className="surface-elev border-t py-16" style={{ borderColor: "var(--border)" }}>
        <div className="container-prose flex flex-col items-start gap-6 md:flex-row md:items-center md:justify-between">
          <div>
            <span className="eyebrow">Next</span>
            <h3
              className="mt-2 font-display text-2xl font-semibold tracking-tight"
              style={accentStrong}
            >
              Putting practice lives in its own lane.
            </h3>
          </div>
          <div className="flex flex-wrap gap-3">
            <Link
              href="/putter"
              className="inline-flex items-center gap-2 rounded-full px-5 py-2.5 text-base font-medium transition"
              style={{ background: "var(--accent-strong)", color: "var(--bg)" }}
            >
              Putter mode
              <svg viewBox="0 0 24 24" fill="none" strokeWidth="2" stroke="currentColor" className="h-4 w-4">
                <path d="M5 12h14M13 5l7 7-7 7" strokeLinecap="round" strokeLinejoin="round" />
              </svg>
            </Link>
            <Link
              href="/course-builder"
              className="inline-flex items-center gap-2 rounded-full border px-5 py-2.5 text-base font-medium transition"
              style={{ borderColor: "var(--border-strong)", color: "var(--fg)" }}
            >
              Course builder
            </Link>
          </div>
        </div>
      </section>
    </PageLayout>
  );
}
