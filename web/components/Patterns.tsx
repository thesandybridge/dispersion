// Background pattern primitives. Inline SVG with `currentColor` so they
// inherit theme tones via the parent's color value. All are pointer-
// events-none so they never block interaction.

interface CommonProps {
  className?: string;
  /// Color override; defaults to currentColor so the parent's text-color
  /// drives the tint. Use rgba/hsla strings for translucency.
  color?: string;
  /// Stroke width / dot radius — scales with the pattern density.
  weight?: number;
  /// Density (smaller = denser).
  size?: number;
  /// Optional opacity multiplier on top of the color alpha.
  opacity?: number;
}

// MARK: - Topographic contour pattern. Each line is a true sine wave with
// period == tile width, so y(0) === y(width) and the lines flow seamlessly
// across tile boundaries. Five wavy contours per tile at different y
// offsets, amplitudes, and phases.
export function TopoPattern({
  className = "",
  color = "currentColor",
  weight = 0.6,
  size = 220,
  opacity = 0.10,
}: CommonProps) {
  const id = `topo-${size}-${weight}`;
  // Each contour: vertical anchor (fraction of tile), amplitude (px),
  // phase offset (radians). Phases are chosen so adjacent lines don't
  // crest at the same x — keeps the field lively rather than striped.
  const lines: { y: number; amp: number; phase: number }[] = [
    { y: size * 0.16, amp: 6, phase: 0.0 },
    { y: size * 0.34, amp: 5, phase: 1.2 },
    { y: size * 0.52, amp: 7, phase: 2.6 },
    { y: size * 0.68, amp: 5, phase: 0.7 },
    { y: size * 0.86, amp: 6, phase: 1.9 },
  ];
  const samples = 32; // smooth without bloating the path string
  const d = lines
    .map(({ y, amp, phase }) => {
      let path = "";
      for (let i = 0; i <= samples; i++) {
        const t = i / samples;
        const x = t * size;
        const yPos = y + amp * Math.sin(t * Math.PI * 2 + phase);
        path += `${i === 0 ? "M" : "L"} ${x.toFixed(2)} ${yPos.toFixed(2)} `;
      }
      return path.trim();
    })
    .join(" ");

  return (
    <svg
      aria-hidden
      className={`pointer-events-none absolute inset-0 h-full w-full ${className}`}
      style={{ color, opacity }}
    >
      <defs>
        <pattern id={id} width={size} height={size} patternUnits="userSpaceOnUse">
          <path d={d} stroke="currentColor" strokeWidth={weight} fill="none" />
        </pattern>
      </defs>
      <rect width="100%" height="100%" fill={`url(#${id})`} />
    </svg>
  );
}

// MARK: - Dot grid pattern. Reads as drafting paper / blueprint.
export function DotPattern({
  className = "",
  color = "currentColor",
  weight = 0.9,
  size = 22,
  opacity = 0.18,
}: CommonProps) {
  const id = `dots-${size}-${weight}`;
  return (
    <svg
      aria-hidden
      className={`pointer-events-none absolute inset-0 h-full w-full ${className}`}
      style={{ color, opacity }}
    >
      <defs>
        <pattern id={id} width={size} height={size} patternUnits="userSpaceOnUse">
          <circle cx={size / 2} cy={size / 2} r={weight} fill="currentColor" />
        </pattern>
      </defs>
      <rect width="100%" height="100%" fill={`url(#${id})`} />
    </svg>
  );
}

// MARK: - Diagonal hatch. Adds direction + motion energy to dark sections.
export function HatchPattern({
  className = "",
  color = "currentColor",
  weight = 0.5,
  size = 16,
  opacity = 0.08,
}: CommonProps) {
  const id = `hatch-${size}-${weight}`;
  return (
    <svg
      aria-hidden
      className={`pointer-events-none absolute inset-0 h-full w-full ${className}`}
      style={{ color, opacity }}
    >
      <defs>
        <pattern id={id} width={size} height={size} patternUnits="userSpaceOnUse" patternTransform="rotate(45)">
          <line x1="0" y1="0" x2="0" y2={size} stroke="currentColor" strokeWidth={weight} />
        </pattern>
      </defs>
      <rect width="100%" height="100%" fill={`url(#${id})`} />
    </svg>
  );
}
