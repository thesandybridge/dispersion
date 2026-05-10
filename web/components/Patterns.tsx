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

// MARK: - Topographic contour pattern. Suggests a course map without being
// literal. Sized so it tiles at any container width.
export function TopoPattern({
  className = "",
  color = "currentColor",
  weight = 0.6,
  size = 220,
  opacity = 0.10,
}: CommonProps) {
  const id = `topo-${size}-${weight}`;
  return (
    <svg
      aria-hidden
      className={`pointer-events-none absolute inset-0 h-full w-full ${className}`}
      style={{ color, opacity }}
    >
      <defs>
        <pattern id={id} width={size} height={size} patternUnits="userSpaceOnUse">
          <path
            d={[
              `M -10 ${size * 0.18} Q ${size * 0.25} ${size * 0.08}, ${size * 0.5} ${size * 0.20} T ${size + 10} ${size * 0.18}`,
              `M -10 ${size * 0.34} Q ${size * 0.30} ${size * 0.24}, ${size * 0.55} ${size * 0.36} T ${size + 10} ${size * 0.34}`,
              `M -10 ${size * 0.52} Q ${size * 0.20} ${size * 0.42}, ${size * 0.45} ${size * 0.54} T ${size + 10} ${size * 0.52}`,
              `M -10 ${size * 0.68} Q ${size * 0.35} ${size * 0.58}, ${size * 0.60} ${size * 0.70} T ${size + 10} ${size * 0.68}`,
              `M -10 ${size * 0.84} Q ${size * 0.25} ${size * 0.74}, ${size * 0.50} ${size * 0.86} T ${size + 10} ${size * 0.84}`,
            ].join(" ")}
            stroke="currentColor"
            strokeWidth={weight}
            fill="none"
          />
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
