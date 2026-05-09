// Three-up feature grid below the hero. Each card has an inline glyph,
// a punchy heading, and a one-paragraph explanation. Avoid bullet-point
// lists — readers don't read those on marketing pages.

const FEATURES = [
  {
    title: "Probability, not yardage",
    body:
      "Every recommendation is grounded in the math: integrate your dispersion over the safe zone, rank by who's most likely to land in it.",
    glyph: (
      <svg viewBox="0 0 24 24" fill="none" className="h-6 w-6">
        <circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="1.5" />
        <circle cx="12" cy="12" r="5.5" stroke="currentColor" strokeWidth="1.5" />
        <circle cx="12" cy="12" r="2" fill="currentColor" />
      </svg>
    ),
  },
  {
    title: "Calibrate at the range",
    body:
      "Range mode logs shots against a club's expected carry. Your σ↕ and σ↔ tighten in real time. Save calibration when you're confident — never before.",
    glyph: (
      <svg viewBox="0 0 24 24" fill="none" className="h-6 w-6">
        <circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="1.5" />
        <path d="M12 3v18M3 12h18" stroke="currentColor" strokeWidth="1.5" />
      </svg>
    ),
  },
  {
    title: "Build any course",
    body:
      "Trace tees, pins, fairways and greens onto satellite imagery. Auto-fill known surfaces or hand-shape every polygon. The map is yours.",
    glyph: (
      <svg viewBox="0 0 24 24" fill="none" className="h-6 w-6">
        <path
          d="M4 6.5l5-2 6 2 5-2v13l-5 2-6-2-5 2v-13z"
          stroke="currentColor"
          strokeWidth="1.5"
          strokeLinejoin="round"
        />
        <path d="M9 4.5v13M15 6.5v13" stroke="currentColor" strokeWidth="1.5" />
      </svg>
    ),
  },
  {
    title: "Local-first, period",
    body:
      "Every shot, club, and round lives on your phone. No accounts. No cloud. No telemetry. Export to JSON if you want a backup; otherwise it's yours and only yours.",
    glyph: (
      <svg viewBox="0 0 24 24" fill="none" className="h-6 w-6">
        <rect x="4" y="4" width="16" height="16" rx="3" stroke="currentColor" strokeWidth="1.5" />
        <path d="M9 12l2 2 4-4" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
    ),
  },
  {
    title: "Conditions that matter",
    body:
      "Wind, elevation, lie, pin position, and your own lateral aim bias all flow through the recommendation engine. Tune the math to match your game.",
    glyph: (
      <svg viewBox="0 0 24 24" fill="none" className="h-6 w-6">
        <path
          d="M3 8h13a3 3 0 100-6M3 12h17a3 3 0 110 6M3 16h10"
          stroke="currentColor"
          strokeWidth="1.5"
          strokeLinecap="round"
        />
      </svg>
    ),
  },
  {
    title: "Color-blind safe",
    body:
      "Three palette modes plus a fully custom theme. The probability gradient and dispersion contours stay readable for deuteranopia, protanopia, and tritanopia.",
    glyph: (
      <svg viewBox="0 0 24 24" fill="none" className="h-6 w-6">
        <circle cx="9" cy="12" r="6" stroke="currentColor" strokeWidth="1.5" />
        <circle cx="15" cy="12" r="6" stroke="currentColor" strokeWidth="1.5" />
      </svg>
    ),
  },
];

export function FeatureGrid() {
  return (
    <section id="how" className="section surface-bg py-24 sm:py-32">
      <div className="container-prose">
        <div className="max-w-2xl">
          <span className="eyebrow">Built for serious amateurs</span>
          <h2
            className="mt-3 font-display text-display-xs font-semibold tracking-display-tight sm:text-display-sm"
            style={{ color: "var(--accent-strong)" }}
          >
            A tool, not a toy.
          </h2>
          <p className="surface-muted mt-4 text-lg leading-relaxed">
            Most golf apps measure yardage. Dispersion models the
            probability that you'll land where you want. Every feature
            in the app exists to make that recommendation sharper.
          </p>
        </div>

        <div className="mt-14 grid grid-cols-1 gap-x-10 gap-y-12 md:grid-cols-2 lg:grid-cols-3">
          {FEATURES.map((f) => (
            <div key={f.title} className="space-y-3">
              <span
                className="inline-flex h-12 w-12 items-center justify-center rounded-2xl"
                style={{ background: "var(--accent-tint)", color: "var(--accent)" }}
                aria-hidden="true"
              >
                {f.glyph}
              </span>
              <h3
                className="font-display text-xl font-semibold"
                style={{ color: "var(--accent-strong)" }}
              >
                {f.title}
              </h3>
              <p className="surface-muted leading-relaxed">{f.body}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
