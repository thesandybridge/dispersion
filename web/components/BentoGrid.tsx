"use client";

// Asymmetric "bento" feature grid. Replaces the flat 2x3 list with a
// 3x4 mosaic where one big card holds a live dispersion demo, two
// medium cards animate small visual cues, and the rest are typographic.
// Borders + soft accent fills give the grid material; hover lifts the
// card a hair.

import { motion } from "framer-motion";
import { LiveDispersionBackdrop } from "./LiveDispersionBackdrop";
import { TopoPattern, DotPattern, HatchPattern } from "./Patterns";

interface CardProps {
  className?: string;
  children: React.ReactNode;
  variant?: "default" | "tinted" | "dark";
}

function Card({ className = "", children, variant = "default" }: CardProps) {
  const styles: Record<string, React.CSSProperties> = {
    default: {
      background: "var(--bg-elevated)",
      boxShadow: "0 0 0 1px var(--border)",
    },
    tinted: {
      background: "var(--accent-tint)",
      boxShadow: "0 0 0 1px var(--accent)",
    },
    dark: {
      background: "linear-gradient(160deg, #0e1a13 0%, #082819 100%)",
      color: "#f6f1e1",
      boxShadow: "0 0 0 1px rgba(98, 179, 117, 0.20)",
    },
  };
  return (
    <motion.div
      initial={{ opacity: 0, y: 18 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, amount: 0.2 }}
      transition={{ duration: 0.6, ease: [0.22, 1, 0.36, 1] }}
      whileHover={{ y: -3 }}
      className={`group relative overflow-hidden rounded-3xl ${className}`}
      style={styles[variant]}
    >
      {children}
    </motion.div>
  );
}

function Eyebrow({ children }: { children: React.ReactNode }) {
  return (
    <span
      className="font-mono text-[10px] uppercase tracking-[0.18em]"
      style={{ color: "var(--accent)" }}
    >
      {children}
    </span>
  );
}

export function BentoGrid() {
  return (
    <section className="section relative py-24 sm:py-32">
      {/* Topo pattern peeking through behind the section */}
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0"
        style={{ color: "var(--accent-strong)" }}
      >
        <TopoPattern opacity={0.04} size={280} />
      </div>
      <div className="container-prose relative">
        <div className="max-w-2xl">
          <Eyebrow>Built for serious amateurs</Eyebrow>
          <h2
            className="mt-3 font-display text-display-xs font-semibold tracking-display-tight sm:text-display-sm"
            style={{ color: "var(--accent-strong)" }}
          >
            A tool, not a toy.
          </h2>
          <p
            className="mt-4 text-lg leading-relaxed"
            style={{ color: "var(--fg-soft)" }}
          >
            Every feature exists to sharpen one decision: which club gives
            you the best chance of landing where you want.
          </p>
        </div>

        <div className="mt-16 grid grid-cols-1 gap-5 md:grid-cols-3 md:grid-rows-[auto_auto_auto]">
          {/* Big — live dispersion demo */}
          <Card variant="dark" className="md:col-span-2 md:row-span-2">
            <div className="relative h-full">
              <div className="absolute inset-0">
                <LiveDispersionBackdrop showZone intense={false} />
              </div>
              {/* Diagonal hatch over the dispersion gives the dark surface
                  tactile depth without competing with the contours. */}
              <div
                aria-hidden
                className="pointer-events-none absolute inset-0"
                style={{ color: "#a9d18e" }}
              >
                <HatchPattern opacity={0.05} size={14} />
              </div>
              <div className="relative z-10 flex h-full flex-col justify-between p-8">
                <div>
                  <Eyebrow>Probability, not yardage</Eyebrow>
                  <h3
                    className="mt-2 font-display text-3xl font-semibold tracking-tight sm:text-4xl"
                    style={{ color: "#f6f1e1" }}
                  >
                    Integrate your dispersion over the safe zone.
                  </h3>
                </div>
                <div
                  className="mt-8 max-w-md text-base leading-relaxed"
                  style={{ color: "rgba(246, 241, 225, 0.75)" }}
                >
                  Every club's σ↕ and σ↔ defines a 2D Gaussian. The app
                  evaluates P(landing inside the green) for every option in
                  your bag and ranks them. The math is in the open — no
                  black box.
                </div>
              </div>
            </div>
          </Card>

          {/* Calibrate */}
          <Card>
            <div className="relative h-full p-7">
              <Eyebrow>Calibrate at the range</Eyebrow>
              <h3
                className="mt-2 font-display text-xl font-semibold"
                style={{ color: "var(--accent-strong)" }}
              >
                Watch your sigma tighten.
              </h3>
              <p
                className="mt-3 text-sm leading-relaxed"
                style={{ color: "var(--fg-soft)" }}
              >
                Range mode logs shots live. σ updates with every tap. Save
                only when the sample's big enough to trust.
              </p>

              {/* Sample size dots viz */}
              <div className="mt-5 grid grid-cols-15 gap-1" style={{ gridTemplateColumns: "repeat(15, minmax(0, 1fr))" }}>
                {Array.from({ length: 15 }).map((_, i) => (
                  <span
                    key={i}
                    className="h-2 rounded-full"
                    style={{
                      background:
                        i < 11 ? "var(--accent)" : "var(--border)",
                    }}
                  />
                ))}
              </div>
              <div className="mt-2 flex items-baseline justify-between">
                <span
                  className="font-display text-2xl font-semibold tabular-nums"
                  style={{ color: "var(--accent-strong)" }}
                >
                  11
                  <span
                    className="ml-1 font-mono text-xs font-normal"
                    style={{ color: "var(--fg-muted)" }}
                  >
                    / 15 shots
                  </span>
                </span>
                <span
                  className="rounded-full px-2 py-0.5 font-mono text-[10px] uppercase tracking-wider"
                  style={{
                    background: "var(--accent-tint)",
                    color: "var(--accent)",
                  }}
                >
                  Good
                </span>
              </div>
            </div>
          </Card>

          {/* Lateral aim */}
          <Card variant="tinted">
            <div className="relative h-full p-7">
              <Eyebrow>Aim with the bias</Eyebrow>
              <h3
                className="mt-2 font-display text-xl font-semibold"
                style={{ color: "var(--accent-strong)" }}
              >
                Drag the dispersion to favor your miss.
              </h3>
              <p
                className="mt-3 text-sm leading-relaxed"
                style={{ color: "var(--fg-soft)" }}
              >
                Wind, pin position, and your own lateral bias all flow
                through the recommendation. The math respects them.
              </p>
            </div>
          </Card>

          {/* Local first */}
          <Card>
            <div className="p-7">
              <Eyebrow>Local-first, period</Eyebrow>
              <h3
                className="mt-2 font-display text-xl font-semibold"
                style={{ color: "var(--accent-strong)" }}
              >
                Your data never leaves the device.
              </h3>
              <p
                className="mt-3 text-sm leading-relaxed"
                style={{ color: "var(--fg-soft)" }}
              >
                No accounts. No cloud. No telemetry. Export to JSON if you
                want a backup; otherwise it's yours and only yours.
              </p>
            </div>
          </Card>

          {/* Course builder */}
          <Card variant="tinted">
            <div className="p-7">
              <Eyebrow>Build any course</Eyebrow>
              <h3
                className="mt-2 font-display text-xl font-semibold"
                style={{ color: "var(--accent-strong)" }}
              >
                Trace the green, drop the pin.
              </h3>
              <p
                className="mt-3 text-sm leading-relaxed"
                style={{ color: "var(--fg-soft)" }}
              >
                Apple satellite + your own polygons. Auto-fill known
                surfaces; hand-shape the tricky ones.
              </p>
            </div>
          </Card>

          {/* Putter */}
          <Card>
            <div className="relative h-full p-7">
              <Eyebrow>Putter, separated</Eyebrow>
              <h3
                className="mt-2 font-display text-xl font-semibold"
                style={{ color: "var(--accent-strong)" }}
              >
                Distance brackets, lag stats, its own lane.
              </h3>
              <p
                className="mt-3 text-sm leading-relaxed"
                style={{ color: "var(--fg-soft)" }}
              >
                The putter is its own model — no carry, no σ. A linear
                practice lane, make rate from 0–3 ft to 30+ ft, lag-putt
                proximity tracked over time.
              </p>

              {/* Mini bracket preview */}
              <div className="mt-4 space-y-1.5">
                {[
                  { l: "0–3", pct: 0.96 },
                  { l: "3–6", pct: 0.74 },
                  { l: "6–15", pct: 0.43 },
                ].map((b) => (
                  <div key={b.l} className="flex items-center gap-2">
                    <span
                      className="w-9 font-mono text-[10px]"
                      style={{ color: "var(--fg-muted)" }}
                    >
                      {b.l} ft
                    </span>
                    <div
                      className="relative h-1.5 flex-1 overflow-hidden rounded-full"
                      style={{ background: "var(--border)" }}
                    >
                      <span
                        className="absolute inset-y-0 left-0 rounded-full"
                        style={{
                          width: `${b.pct * 100}%`,
                          background:
                            b.pct >= 0.7
                              ? "var(--accent)"
                              : b.pct >= 0.45
                                ? "var(--accent-soft)"
                                : "#e6c068",
                        }}
                      />
                    </div>
                    <span
                      className="w-8 text-right font-mono text-[10px] font-semibold tabular-nums"
                      style={{ color: "var(--accent-strong)" }}
                    >
                      {Math.round(b.pct * 100)}%
                    </span>
                  </div>
                ))}
              </div>

              <a
                href="/putter"
                className="mt-4 inline-flex items-center gap-1 font-mono text-[11px] font-medium transition"
                style={{ color: "var(--accent-strong)" }}
              >
                Putter mode
                <svg viewBox="0 0 24 24" fill="none" strokeWidth="2" stroke="currentColor" className="h-3 w-3">
                  <path d="M5 12h14M13 5l7 7-7 7" strokeLinecap="round" strokeLinejoin="round" />
                </svg>
              </a>
            </div>
          </Card>
        </div>
      </div>
    </section>
  );
}
