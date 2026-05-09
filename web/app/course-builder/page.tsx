import type { Metadata } from "next";
import Link from "next/link";
import { PageLayout } from "@/components/PageLayout";
import { FeatureWalkthroughList } from "@/components/FeatureWalkthrough";

export const metadata: Metadata = {
  title: "Course builder — trace any course on satellite imagery",
  description:
    "Add a course by name. Place tee boxes and pin positions. Trace fairways, greens, bunkers, and water polygons over real satellite imagery. Auto-fill or hand-shape every surface.",
  alternates: { canonical: "/course-builder" },
  openGraph: {
    title: "Course builder — Dispersion",
    description:
      "Trace any course on satellite imagery. Tee boxes, pin positions, polygons.",
    url: "/course-builder",
  },
};

const accentStrong = { color: "var(--accent-strong)" };

// ─── Editorial visual frame ───────────────────────────────────────────

function VisualFrame({ children, label }: { children: React.ReactNode; label: string }) {
  return (
    <div
      className="overflow-hidden rounded-3xl"
      style={{
        background: "var(--bg-elevated)",
        boxShadow:
          "0 0 0 1px var(--border), 0 32px 64px -32px rgba(11, 61, 46, 0.20), 0 8px 16px -8px rgba(0,0,0,0.06)",
      }}
    >
      <div
        className="flex items-center justify-between border-b px-5 py-3 font-mono text-[10px] uppercase tracking-[0.2em]"
        style={{ borderColor: "var(--border)", color: "var(--fg-muted)" }}
      >
        <span>{label}</span>
        <span className="flex gap-1.5">
          <span className="h-1.5 w-1.5 rounded-full" style={{ background: "currentColor", opacity: 0.4 }} />
          <span className="h-1.5 w-1.5 rounded-full" style={{ background: "currentColor", opacity: 0.4 }} />
          <span className="h-1.5 w-1.5 rounded-full" style={{ background: "currentColor", opacity: 0.4 }} />
        </span>
      </div>
      {children}
    </div>
  );
}

// ─── Visuals ──────────────────────────────────────────────────────────

function HoleMockup() {
  return (
    <VisualFrame label="Course · Hole 7 · Par 4">
      <div className="relative aspect-[4/3] w-full">
        <svg
          viewBox="0 0 400 300"
          className="absolute inset-0 h-full w-full"
          aria-hidden="true"
        >
          <defs>
            <pattern id="topo" width="14" height="14" patternUnits="userSpaceOnUse">
              <circle cx="2" cy="2" r="0.5" fill="var(--fg-muted)" opacity="0.18" />
            </pattern>
            <linearGradient id="fairwayGrad" x1="0" y1="1" x2="0.4" y2="0">
              <stop offset="0%" stopColor="var(--accent)" stopOpacity="0.10" />
              <stop offset="100%" stopColor="var(--accent)" stopOpacity="0.32" />
            </linearGradient>
          </defs>

          <rect width="400" height="300" fill="url(#topo)" />

          {/* Fairway corridor — soft tint, no harsh outline */}
          <path
            d="M180 280 C 175 230, 150 180, 160 130 C 170 95, 200 70, 235 60"
            stroke="url(#fairwayGrad)"
            strokeWidth="58"
            strokeLinecap="round"
            fill="none"
          />
          <path
            d="M180 280 C 175 230, 150 180, 160 130 C 170 95, 200 70, 235 60"
            stroke="var(--accent)"
            strokeWidth="58"
            strokeLinecap="round"
            fill="none"
            opacity="0.06"
          />

          {/* Bunkers — subtle, theme-tinted */}
          <ellipse cx="135" cy="180" rx="20" ry="11" fill="var(--fg-soft)" opacity="0.30" />
          <ellipse cx="218" cy="80" rx="13" ry="8" fill="var(--fg-soft)" opacity="0.30" />

          {/* Green */}
          <ellipse
            cx="245"
            cy="55"
            rx="32"
            ry="22"
            fill="var(--accent)"
            opacity="0.28"
          />
          <ellipse
            cx="245"
            cy="55"
            rx="32"
            ry="22"
            fill="none"
            stroke="var(--accent-strong)"
            strokeWidth="1"
            strokeDasharray="2 2"
            opacity="0.55"
          />

          {/* Tee box marker */}
          <circle cx="180" cy="270" r="5" fill="var(--accent-strong)" />
          <circle cx="180" cy="270" r="9" fill="none" stroke="var(--accent-strong)" strokeWidth="0.8" opacity="0.5" />

          {/* Distance line */}
          <path
            d="M180 270 L 245 55"
            stroke="var(--accent-strong)"
            strokeWidth="0.8"
            strokeDasharray="4 4"
            opacity="0.45"
          />

          {/* Pin + flag */}
          <line x1="245" y1="55" x2="245" y2="34" stroke="var(--accent-strong)" strokeWidth="1.2" />
          <path d="M245 34 L 257 38 L 245 42 Z" fill="var(--accent-strong)" />
          <circle cx="245" cy="55" r="2" fill="var(--bg-elevated)" stroke="var(--accent-strong)" strokeWidth="1" />
        </svg>

        {/* Yardage callout (typographic) */}
        <div className="absolute right-5 top-5 text-right">
          <div
            className="font-mono text-[10px] uppercase tracking-[0.2em]"
            style={{ color: "var(--fg-muted)" }}
          >
            Pin · middle
          </div>
          <div
            className="mt-0.5 font-display text-2xl font-semibold tabular-nums"
            style={accentStrong}
          >
            312<span className="text-base font-normal surface-muted">y</span>
          </div>
        </div>

        {/* Tee marker label */}
        <div className="absolute bottom-5 left-5">
          <div
            className="font-mono text-[10px] uppercase tracking-[0.2em]"
            style={{ color: "var(--fg-muted)" }}
          >
            Tee · white
          </div>
        </div>
      </div>
    </VisualFrame>
  );
}

function StepPills() {
  const steps = [
    { label: "Tees", done: true, active: false },
    { label: "Pins", done: true, active: false },
    { label: "Draw", done: false, active: true },
  ];
  return (
    <div className="flex justify-center">
      <div
        className="rounded-full p-1.5"
        style={{ background: "var(--bg-elevated)", boxShadow: "0 0 0 1px var(--border)" }}
      >
        <div className="flex gap-1">
          {steps.map((s) => (
            <span
              key={s.label}
              className="rounded-full px-3.5 py-1.5 font-mono text-[11px] font-medium tracking-wide"
              style={
                s.active
                  ? { background: "var(--accent-strong)", color: "var(--bg)" }
                  : s.done
                    ? { color: "var(--accent)" }
                    : { color: "var(--fg-muted)" }
              }
            >
              {s.done && !s.active ? "✓ " : ""}
              {s.label}
            </span>
          ))}
        </div>
      </div>
    </div>
  );
}

function AutoManualToggleVisual() {
  return (
    <VisualFrame label="Course · draw mode">
      <div className="flex h-full flex-col">
        {/* Mode toggle row */}
        <div
          className="flex items-center justify-between border-b px-5 py-3"
          style={{ borderColor: "var(--border)" }}
        >
          <div
            className="flex rounded-full p-1"
            style={{ background: "var(--bg)", boxShadow: "0 0 0 1px var(--border)" }}
          >
            <span
              className="inline-flex items-center gap-1.5 rounded-full px-3 py-1 font-mono text-[10px] font-medium uppercase tracking-wider"
              style={{ background: "var(--accent-strong)", color: "var(--bg)" }}
            >
              <svg viewBox="0 0 24 24" fill="none" strokeWidth="2" stroke="currentColor" className="h-3 w-3">
                <path d="M5 16l4-8 6 14 4-12" strokeLinecap="round" />
              </svg>
              Auto
            </span>
            <span
              className="inline-flex items-center gap-1.5 rounded-full px-3 py-1 font-mono text-[10px] uppercase tracking-wider"
              style={{ color: "var(--fg-muted)" }}
            >
              ✏︎ Manual
            </span>
          </div>
          <span
            className="font-mono text-[10px] uppercase tracking-[0.2em]"
            style={{ color: "var(--fg-muted)" }}
          >
            Fairway · 1
          </span>
        </div>

        {/* Polygon canvas */}
        <div className="relative aspect-[4/2.5] w-full">
          <svg viewBox="0 0 400 250" className="absolute inset-0 h-full w-full">
            <defs>
              <pattern id="dots" width="14" height="14" patternUnits="userSpaceOnUse">
                <circle cx="2" cy="2" r="0.5" fill="var(--fg-muted)" opacity="0.18" />
              </pattern>
            </defs>
            <rect width="400" height="250" fill="url(#dots)" />

            {/* Drawn polygon */}
            <polygon
              points="80,180 170,90 280,75 350,140 290,210 160,205"
              fill="var(--accent)"
              fillOpacity="0.18"
              stroke="var(--accent-strong)"
              strokeWidth="1.5"
            />

            {/* Vertex handles */}
            {[
              [80, 180], [170, 90], [280, 75], [350, 140], [290, 210], [160, 205],
            ].map(([x, y], i) => {
              const active = i === 1;
              return (
                <g key={i}>
                  {active && (
                    <circle
                      cx={x}
                      cy={y}
                      r={14}
                      fill="var(--accent)"
                      opacity="0.20"
                    />
                  )}
                  <circle
                    cx={x}
                    cy={y}
                    r={active ? 6 : 4}
                    fill="var(--bg-elevated)"
                    stroke="var(--accent-strong)"
                    strokeWidth={active ? 2 : 1.5}
                  />
                </g>
              );
            })}

            {/* Crosshair on a guide */}
            <line x1="200" y1="40" x2="200" y2="230" stroke="var(--fg-muted)" strokeWidth="0.5" opacity="0.35" strokeDasharray="2 4" />
            <line x1="40" y1="140" x2="370" y2="140" stroke="var(--fg-muted)" strokeWidth="0.5" opacity="0.35" strokeDasharray="2 4" />
          </svg>
        </div>
      </div>
    </VisualFrame>
  );
}

function ScorecardEditorVisual() {
  const holes = [
    { hole: 1, par: 4, yards: 412, hcp: 7 },
    { hole: 2, par: 5, yards: 538, hcp: 1 },
    { hole: 3, par: 3, yards: 178, hcp: 13 },
    { hole: 4, par: 4, yards: 388, hcp: 11 },
    { hole: 5, par: 4, yards: 425, hcp: 5 },
  ];
  return (
    <VisualFrame label="Course · scorecard">
      <div className="p-6">
        <div className="flex items-center justify-between">
          <span className="font-display text-base font-semibold" style={accentStrong}>
            Front nine
          </span>
          <div className="flex gap-1">
            {["Blue", "White", "Red"].map((t, i) => (
              <span
                key={t}
                className="rounded-full px-2.5 py-0.5 font-mono text-[10px]"
                style={
                  i === 1
                    ? { background: "var(--accent-strong)", color: "var(--bg)" }
                    : { background: "var(--bg)", color: "var(--fg-muted)", boxShadow: "0 0 0 1px var(--border)" }
                }
              >
                {t}
              </span>
            ))}
          </div>
        </div>
        <table className="mt-5 w-full border-collapse text-sm">
          <thead>
            <tr
              className="border-b text-left font-mono text-[10px] uppercase tracking-[0.15em]"
              style={{ borderColor: "var(--border)", color: "var(--fg-muted)" }}
            >
              <th className="py-2 pr-2">Hole</th>
              <th className="py-2">Par</th>
              <th className="py-2">Yards</th>
              <th className="py-2 text-right">HCP</th>
            </tr>
          </thead>
          <tbody>
            {holes.map((h) => (
              <tr
                key={h.hole}
                className="border-b last:border-b-0"
                style={{ borderColor: "var(--border)" }}
              >
                <td className="py-2.5 pr-2 font-mono text-base" style={accentStrong}>
                  {h.hole}
                </td>
                <td className="py-2.5">
                  <span
                    className="grid h-6 w-6 place-items-center rounded-full font-mono text-xs font-semibold"
                    style={{ background: "var(--accent-tint)", color: "var(--accent)" }}
                  >
                    {h.par}
                  </span>
                </td>
                <td className="py-2.5 font-mono text-sm surface-soft">{h.yards}</td>
                <td className="py-2.5 text-right font-mono text-sm surface-muted">{h.hcp}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </VisualFrame>
  );
}

// ─── Page ─────────────────────────────────────────────────────────────

export default function CourseBuilderPage() {
  return (
    <PageLayout
      eyebrow="Course builder"
      title={
        <>
          Trace any course.{" "}
          <span className="italic" style={{ color: "var(--accent)" }}>
            One hole at a time.
          </span>
        </>
      }
      lede="Search for a course, drop your tee boxes, place pin positions, and trace the fairways, greens, bunkers, and water onto Apple's satellite imagery. The map you build is yours — exportable, shareable, and works completely offline once it's downloaded."
    >
      <section className="container-prose pt-16 pb-20 sm:pt-24">
        <FeatureWalkthroughList
          steps={[
            {
              eyebrow: "The setup",
              title: "Search, then walk through each hole.",
              body: (
                <>
                  Add a course by name through Apple Maps' built-in
                  geocoder. Dispersion creates default 18-hole records; you
                  walk through each hole stamping tees, pins, and drawing
                  the playable surfaces. Three steps — Tees, Pins, Draw —
                  shown as a pill cluster under the floating header so it's
                  always clear where you are.
                </>
              ),
              bullets: [
                "Apple Maps geocoder for course search",
                "Multiple tee colors per hole (Blue, White, Red, Gold)",
                "Per-hole front / middle / back pin coordinates",
                "Per-hole fairway, green, bunker, and water polygons",
              ],
              visual: (
                <div className="space-y-4">
                  <HoleMockup />
                  <StepPills />
                </div>
              ),
            },
            {
              eyebrow: "Auto vs manual",
              title: "Auto-fill known surfaces. Hand-shape the rest.",
              body: (
                <>
                  The Draw step has two modes that swap from a single pill.
                  In Auto, tap inside a region and Apple's place
                  recognition flood-fills the polygon for you — usually
                  best for clean fairways and large greens. Manual lets
                  you tap to drop polygon vertices yourself, drag a vertex
                  handle to reshape, undo to step back. Use whichever's
                  faster for the surface you're tracing.
                </>
              ),
              bullets: [
                "Auto fill via Apple's place recognition",
                "Manual vertex drag for hand-shaping",
                "Per-polygon undo + re-edit",
                "3D / 2D map toggle for tricky terrain",
              ],
              visual: <AutoManualToggleVisual />,
            },
            {
              eyebrow: "The scorecard",
              title: "Pars, yardages, and stroke index — all editable.",
              body: (
                <>
                  Each hole has a par, an array of tee-yardage entries (one
                  per tee color), and a handicap / stroke index. The
                  scorecard editor sheet shows everything at a glance and
                  lets you tap to fix what's wrong. The yardage column
                  switches between tee colors so you only see the numbers
                  you care about for the round you're about to play.
                </>
              ),
              bullets: [
                "Par stepper (3 / 4 / 5) per hole",
                "Per-tee yardage column",
                "Stroke-index numeric input",
                "Front / middle / back pin offsets within each green",
              ],
              visual: <ScorecardEditorVisual />,
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
              Now teach the app your dispersion.
            </h3>
          </div>
          <Link
            href="/range"
            className="inline-flex items-center gap-2 rounded-full px-5 py-2.5 text-base font-medium transition"
            style={{ background: "var(--accent-strong)", color: "var(--bg)" }}
          >
            Range mode
            <svg viewBox="0 0 24 24" fill="none" strokeWidth="2" stroke="currentColor" className="h-4 w-4">
              <path d="M5 12h14M13 5l7 7-7 7" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
          </Link>
        </div>
      </section>
    </PageLayout>
  );
}
