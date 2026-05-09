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

// ─── Illustrative visuals ─────────────────────────────────────────────

function RadarVisual() {
  return (
    <div
      className="relative aspect-square w-full overflow-hidden rounded-3xl shadow-2xl ring-1"
      style={{
        background: "#0b3d2e",
        boxShadow: "0 24px 48px -16px rgba(0,0,0,0.35)",
      }}
    >
      <DispersionCanvas
        carry={158}
        carrySd={6}
        lateralSd={9}
        distanceToTarget={158}
        zoneWidth={25}
        zoneDepth={25}
        zoneKind="green"
      />
      <div className="absolute right-4 top-4 rounded-full bg-black/55 px-4 py-2 backdrop-blur" style={{ boxShadow: "0 0 0 1px #62b37566" }}>
        <span className="font-mono text-xs text-[#a9d18e]">σ↕ 6.0  σ↔ 9.0  · n=14</span>
      </div>
    </div>
  );
}

function CalibrationVisual() {
  const filled = 14;
  const total = 30;
  return (
    <div
      className="rounded-3xl surface-elev p-8 shadow-lg"
      style={{ boxShadow: "0 0 0 1px var(--border), 0 12px 24px -8px rgba(0,0,0,0.1)" }}
    >
      <div className="font-mono text-xs uppercase tracking-widest surface-muted">
        Calibration confidence
      </div>
      <div className="mt-3 flex items-baseline gap-2">
        <span
          className="font-display text-5xl font-semibold tabular-nums"
          style={accentStrong}
        >
          14
        </span>
        <span className="surface-muted text-base">of 30 shots</span>
      </div>
      <div className="mt-1 text-sm" style={{ color: "var(--accent)" }}>
        Good — reliable enough to save.
      </div>
      <div className="mt-5 flex flex-wrap gap-1.5">
        {Array.from({ length: total }).map((_, i) => (
          <span
            key={i}
            className="h-2.5 w-2.5 rounded-full"
            style={{
              background:
                i < filled ? "var(--accent)" : "var(--border-strong)",
            }}
          />
        ))}
      </div>

      <div className="mt-6 grid grid-cols-2 gap-3">
        <div className="rounded-xl surface-bg p-3">
          <div className="font-mono text-[10px] uppercase tracking-widest surface-muted">Stored</div>
          <div className="mt-1 font-mono text-sm" style={accentStrong}>σ↕ 6.5  σ↔ 9.5</div>
        </div>
        <div className="rounded-xl surface-bg p-3 ring-1" style={{ boxShadow: "0 0 0 1px var(--accent)" }}>
          <div className="font-mono text-[10px] uppercase tracking-widest" style={{ color: "var(--accent)" }}>Measured</div>
          <div className="mt-1 font-mono text-sm" style={accentStrong}>σ↕ 5.9 ↓0.6  σ↔ 8.7 ↓0.8</div>
        </div>
      </div>
    </div>
  );
}

function InsightsVisual() {
  return (
    <div className="space-y-3">
      <PBBanner />
      <SessionStripCard />
      <div className="rounded-2xl surface-elev p-5">
        <div className="flex items-baseline justify-between">
          <span
            className="font-display text-xl font-semibold"
            style={accentStrong}
          >
            7 Iron · 14 shots
          </span>
          <span className="rounded-full px-2 py-0.5 font-mono text-[11px]" style={{ background: "var(--accent-tint)", color: "var(--accent)" }}>
            leans L 4y
          </span>
        </div>
        <div className="mt-4 grid grid-cols-2 gap-4">
          <div>
            <div className="flex items-baseline gap-1">
              <span className="font-display text-3xl font-semibold tabular-nums" style={accentStrong}>
                5.9
              </span>
              <span className="font-mono text-xs surface-muted">σ↕</span>
            </div>
            <div className="mt-1 flex gap-2 font-mono text-[10px]" style={{ color: "var(--accent)" }}>
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
            <div className="mt-1 flex gap-2 font-mono text-[10px]" style={{ color: "var(--accent)" }}>
              <span>↓0.8 vs stored</span>
              <span className="surface-muted">↓1.1 vs prev</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function PBBanner() {
  return (
    <div
      className="flex items-center gap-3 rounded-2xl px-4 py-3"
      style={{
        background: "var(--accent-tint)",
        border: "1px solid var(--accent)",
      }}
    >
      <svg viewBox="0 0 24 24" fill="none" className="h-5 w-5" style={{ color: "var(--accent)" }}>
        <path
          d="M12 2l2.4 5 5.6.8-4 4 1 5.6L12 14.8 6.9 17.4l1-5.6-4-4 5.6-.8L12 2z"
          fill="currentColor"
        />
      </svg>
      <div>
        <div className="font-mono text-[10px] uppercase tracking-widest" style={{ color: "var(--accent)" }}>
          Personal best
        </div>
        <div className="text-sm" style={accentStrong}>
          Tightest σ↕ this session
        </div>
      </div>
    </div>
  );
}

function SessionStripCard() {
  return (
    <div className="rounded-2xl surface-elev px-4 py-3 ring-1" style={{ boxShadow: "0 0 0 1px var(--border)" }}>
      <div className="grid grid-cols-3 gap-4 text-center">
        {[
          { label: "shots", value: "14", delta: null },
          { label: "σ↕", value: "5.9", delta: "↓0.6" },
          { label: "σ↔", value: "8.7", delta: "↓0.8" },
        ].map((c) => (
          <div key={c.label}>
            <div
              className="font-display text-2xl font-semibold tabular-nums"
              style={accentStrong}
            >
              {c.value}
            </div>
            <div className="flex items-center justify-center gap-1.5 font-mono text-[10px] surface-muted">
              <span>{c.label}</span>
              {c.delta && <span style={{ color: "var(--accent)" }}>{c.delta}</span>}
            </div>
          </div>
        ))}
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
      <section className="container-prose pb-20">
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
              Build your home course in the satellite map.
            </h3>
          </div>
          <Link
            href="/course-builder"
            className="inline-flex items-center gap-2 rounded-full px-5 py-2.5 text-base font-medium transition"
            style={{ background: "var(--accent-strong)", color: "var(--bg)" }}
          >
            Course builder
            <svg viewBox="0 0 24 24" fill="none" strokeWidth="2" stroke="currentColor" className="h-4 w-4">
              <path d="M5 12h14M13 5l7 7-7 7" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
          </Link>
        </div>
      </section>
    </PageLayout>
  );
}
