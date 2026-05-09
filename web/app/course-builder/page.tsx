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

// ─── Stylized inline mockups ──────────────────────────────────────────

function HoleMockup() {
  return (
    <div
      className="aspect-[4/3] w-full overflow-hidden rounded-3xl shadow-2xl ring-1"
      style={{
        background:
          "radial-gradient(ellipse at 50% 100%, #1a3a26, #0e1a13 70%)",
        boxShadow: "0 24px 48px -16px rgba(0,0,0,0.35)",
      }}
    >
      <svg
        viewBox="0 0 400 300"
        className="h-full w-full"
        aria-hidden="true"
      >
        {/* "satellite" subtle grid */}
        <defs>
          <pattern id="grid" width="20" height="20" patternUnits="userSpaceOnUse">
            <path d="M 20 0 L 0 0 0 20" fill="none" stroke="rgba(255,255,255,0.04)" strokeWidth="0.5" />
          </pattern>
          <radialGradient id="green" cx="50%" cy="50%" r="50%">
            <stop offset="0%" stopColor="#62b375" stopOpacity="0.55" />
            <stop offset="100%" stopColor="#2c8a5e" stopOpacity="0.30" />
          </radialGradient>
        </defs>
        <rect width="400" height="300" fill="url(#grid)" />

        {/* Fairway corridor */}
        <path
          d="M180 280 C 175 230, 150 180, 160 130 C 170 95, 200 70, 235 60"
          stroke="#2c8a5e"
          strokeWidth="50"
          strokeLinecap="round"
          fill="none"
          opacity="0.45"
        />
        <path
          d="M180 280 C 175 230, 150 180, 160 130 C 170 95, 200 70, 235 60"
          stroke="#62b375"
          strokeWidth="50"
          strokeLinecap="round"
          fill="none"
          opacity="0.18"
        />

        {/* Bunkers */}
        <ellipse cx="135" cy="180" rx="22" ry="14" fill="#f0e7b8" opacity="0.75" />
        <ellipse cx="218" cy="80" rx="14" ry="9" fill="#f0e7b8" opacity="0.75" />

        {/* Green polygon */}
        <ellipse cx="245" cy="55" rx="32" ry="22" fill="url(#green)" stroke="#62b375" strokeWidth="1" />

        {/* Tee box */}
        <rect x="170" y="265" width="20" height="10" rx="2" fill="#0072b2" stroke="#f6f1e1" strokeWidth="1" opacity="0.85" />

        {/* Pin (flag) */}
        <line x1="245" y1="55" x2="245" y2="35" stroke="#f6f1e1" strokeWidth="1.4" />
        <polygon points="245,35 257,38 245,42" fill="#e85d4d" />
        <circle cx="245" cy="55" r="2.5" fill="#0e1a13" stroke="#f6f1e1" strokeWidth="0.8" />

        {/* Distance arc */}
        <path
          d="M180 270 L 245 55"
          stroke="#62b375"
          strokeWidth="0.8"
          strokeDasharray="3 3"
          opacity="0.5"
        />
        <text
          x="220"
          y="170"
          fill="#a9d18e"
          fontFamily="ui-monospace, SFMono-Regular, monospace"
          fontSize="10"
          opacity="0.85"
        >
          312y
        </text>
      </svg>
    </div>
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
      <div className="rounded-full p-1.5 ring-1" style={{ background: "rgba(0,0,0,0.55)", boxShadow: "0 0 0 1px rgba(246,241,225,0.08)" }}>
        <div className="flex gap-1">
          {steps.map((s) => (
            <span
              key={s.label}
              className="rounded-full px-3.5 py-1.5 font-mono text-[11px] font-medium"
              style={
                s.active
                  ? { background: "var(--accent)", color: "#0b3d2e" }
                  : s.done
                    ? { background: "rgba(246,241,225,0.10)", color: "#a9d18e" }
                    : { color: "rgba(246,241,225,0.55)" }
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
    <div
      className="aspect-[4/3] w-full overflow-hidden rounded-3xl shadow-2xl"
      style={{
        background:
          "radial-gradient(ellipse at 30% 70%, #1a3a26, #0e1a13 70%)",
        boxShadow: "0 24px 48px -16px rgba(0,0,0,0.35)",
      }}
    >
      <div className="flex h-full flex-col p-6">
        <div className="flex items-center justify-between">
          <span className="rounded-full bg-black/55 px-3 py-1.5 text-[11px] font-medium" style={{ color: "var(--accent)", boxShadow: "0 0 0 1px rgba(246,241,225,0.08)" }}>
            <span className="inline-flex items-center gap-1">
              <svg viewBox="0 0 24 24" fill="none" strokeWidth="2" stroke="currentColor" className="h-3 w-3">
                <path d="M5 16l4-8 6 14 4-12" strokeLinecap="round" />
              </svg>
              Auto fill
            </span>
          </span>
          <span className="rounded-full bg-black/40 px-3 py-1.5 font-mono text-[11px]" style={{ color: "rgba(246,241,225,0.55)" }}>
            ✏︎ Manual
          </span>
        </div>

        <div className="relative mt-auto">
          <svg viewBox="0 0 400 200" className="h-full w-full">
            {/* Drawn polygon — vertices visible */}
            <polygon
              points="80,160 170,90 280,75 350,140 290,180 160,185"
              fill="rgba(98, 179, 117, 0.30)"
              stroke="#62b375"
              strokeWidth="1.6"
            />
            {/* Vertex handles */}
            {[
              [80, 160], [170, 90], [280, 75], [350, 140], [290, 180], [160, 185],
            ].map(([x, y], i) => (
              <circle
                key={i}
                cx={x}
                cy={y}
                r={i === 1 ? 8 : 5}
                fill={i === 1 ? "#f6f1e1" : "#62b375"}
                stroke={i === 1 ? "#62b375" : "#f6f1e1"}
                strokeWidth={i === 1 ? 2 : 1}
              />
            ))}
            {/* Crosshair */}
            <line x1="200" y1="60" x2="200" y2="200" stroke="rgba(246,241,225,0.5)" strokeWidth="0.6" />
            <line x1="100" y1="130" x2="350" y2="130" stroke="rgba(246,241,225,0.5)" strokeWidth="0.6" />
            <circle cx="200" cy="130" r="6" fill="none" stroke="#f6f1e1" strokeWidth="1.2" />
          </svg>
        </div>
      </div>
    </div>
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
    <div className="rounded-3xl surface-elev p-6 shadow-lg">
      <div className="flex items-center justify-between">
        <span className="font-mono text-xs uppercase tracking-widest surface-muted">
          Scorecard editor
        </span>
        <div className="flex gap-1">
          {["Blue", "White", "Red"].map((t, i) => (
            <span
              key={t}
              className="rounded-full px-2 py-0.5 font-mono text-[10px]"
              style={
                i === 1
                  ? { background: "var(--accent)", color: "var(--bg)" }
                  : { background: "var(--border)", color: "var(--fg-muted)" }
              }
            >
              {t}
            </span>
          ))}
        </div>
      </div>
      <table className="mt-4 w-full border-collapse text-sm">
        <thead>
          <tr className="surface-muted text-left font-mono text-[10px] uppercase tracking-widest">
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
              className="border-t"
              style={{ borderColor: "var(--border)" }}
            >
              <td className="py-2 pr-2 font-mono text-base" style={accentStrong}>
                {h.hole}
              </td>
              <td className="py-2">
                <span
                  className="grid h-6 w-6 place-items-center rounded-full font-mono text-xs"
                  style={{ background: "var(--accent)", color: "var(--bg)" }}
                >
                  {h.par}
                </span>
              </td>
              <td className="py-2 font-mono text-sm surface-soft">{h.yards}</td>
              <td className="py-2 text-right font-mono text-sm surface-muted">{h.hcp}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
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
      <section className="container-prose pb-20">
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
