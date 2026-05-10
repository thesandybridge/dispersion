"use client";

// Slow-scrolling marquee of clubs and σ values. Reads as "this app
// thinks about your whole bag" without listing them as a static row.
// Pure CSS animation — no Framer.

const ITEMS = [
  ["Driver", "σ↕ 9.8 · σ↔ 14.2"],
  ["3 Wood", "σ↕ 8.4 · σ↔ 12.0"],
  ["5 Wood", "σ↕ 7.6 · σ↔ 11.0"],
  ["4 Iron", "σ↕ 7.2 · σ↔ 10.5"],
  ["5 Iron", "σ↕ 6.8 · σ↔ 9.8"],
  ["6 Iron", "σ↕ 6.4 · σ↔ 9.2"],
  ["7 Iron", "σ↕ 6.0 · σ↔ 8.7"],
  ["8 Iron", "σ↕ 5.7 · σ↔ 8.2"],
  ["9 Iron", "σ↕ 5.4 · σ↔ 7.6"],
  ["PW", "σ↕ 5.1 · σ↔ 7.2"],
  ["GW", "σ↕ 4.8 · σ↔ 6.7"],
  ["SW", "σ↕ 4.5 · σ↔ 6.2"],
  ["LW", "σ↕ 4.2 · σ↔ 5.8"],
];

export function MarqueeStrip() {
  return (
    <section
      className="relative overflow-hidden border-y py-5"
      style={{
        borderColor: "var(--border)",
        background: "var(--bg-elevated)",
      }}
      aria-hidden
    >
      <div className="marquee-track flex w-max items-center gap-8">
        {[...ITEMS, ...ITEMS, ...ITEMS].map((it, i) => (
          <div key={i} className="flex shrink-0 items-baseline gap-3">
            <span
              className="font-display text-base font-medium"
              style={{ color: "var(--accent-strong)" }}
            >
              {it[0]}
            </span>
            <span
              className="font-mono text-xs"
              style={{ color: "var(--fg-muted)" }}
            >
              {it[1]}
            </span>
            <span
              className="font-mono text-xs opacity-50"
              style={{ color: "var(--accent)" }}
            >
              ·
            </span>
          </div>
        ))}
      </div>

      <style>{`
        .marquee-track {
          animation: marquee 90s linear infinite;
        }
        @keyframes marquee {
          0%   { transform: translateX(0); }
          100% { transform: translateX(-33.333%); }
        }
        @media (prefers-reduced-motion: reduce) {
          .marquee-track { animation: none; }
        }
      `}</style>
    </section>
  );
}
