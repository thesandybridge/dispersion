// Topographic background — low-poly contour decoration. Used as ambient
// texture on hero areas; not interactive.

function TopoBg({ width = 400, height = 200, color = 'rgba(34,80,55,0.18)', accent = 'rgba(232,93,77,0.35)', seed = 1 }) {
    // Deterministic pseudo-random
    const rand = (() => {
        let s = seed * 9301 + 49297;
        return () => {
            s = (s * 9301 + 49297) % 233280;
            return s / 233280;
        };
    })();

    const layers = [];
    const numContours = 6;
    for (let i = 0; i < numContours; i++) {
        const points = [];
        const cx = width * (0.3 + rand() * 0.4);
        const cy = height * (0.4 + rand() * 0.3);
        const baseR = (Math.min(width, height) * (0.18 + i * 0.12));
        const verts = 14 + i * 2;
        for (let v = 0; v < verts; v++) {
            const theta = (v / verts) * Math.PI * 2;
            const wobble = 0.7 + rand() * 0.5;
            const x = cx + Math.cos(theta) * baseR * wobble;
            const y = cy + Math.sin(theta) * baseR * wobble * 0.55;
            points.push(`${x.toFixed(1)},${y.toFixed(1)}`);
        }
        layers.push({ d: 'M' + points.join(' L') + ' Z', i });
    }

    return (
        <svg width={width} height={height} viewBox={`0 0 ${width} ${height}`} style={{ display: 'block' }}>
            <g fill="none" stroke={color} strokeWidth="0.7">
                {layers.map((l, i) => (
                    <path key={i} d={l.d} opacity={0.4 + i * 0.08} />
                ))}
            </g>
            {/* a single accent contour */}
            <path d={layers[2]?.d} fill="none" stroke={accent} strokeWidth="1" opacity="0.7" />
        </svg>
    );
}

// Icon set — minimal stroke icons. Use sparingly.
const Icon = {
    Flag: ({ size = 16, color = 'currentColor' }) => (
        <svg width={size} height={size} viewBox="0 0 16 16" fill="none" stroke={color} strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round">
            <line x1="4" y1="2" x2="4" y2="14" />
            <path d="M4 3 L13 5 L4 7" fill={color} fillOpacity="0.2" />
            <circle cx="4" cy="14" r="0.8" fill={color} />
        </svg>
    ),
    Target: ({ size = 16, color = 'currentColor' }) => (
        <svg width={size} height={size} viewBox="0 0 16 16" fill="none" stroke={color} strokeWidth="1.3">
            <circle cx="8" cy="8" r="6" />
            <circle cx="8" cy="8" r="3" />
            <circle cx="8" cy="8" r="0.8" fill={color} />
        </svg>
    ),
    Bag: ({ size = 16, color = 'currentColor' }) => (
        <svg width={size} height={size} viewBox="0 0 16 16" fill="none" stroke={color} strokeWidth="1.3" strokeLinejoin="round">
            <rect x="3" y="4" width="10" height="10" rx="2" />
            <line x1="6" y1="2" x2="6" y2="6" />
            <line x1="10" y1="2" x2="10" y2="6" />
        </svg>
    ),
    Settings: ({ size = 16, color = 'currentColor' }) => (
        <svg width={size} height={size} viewBox="0 0 16 16" fill="none" stroke={color} strokeWidth="1.3" strokeLinecap="round">
            <circle cx="8" cy="8" r="2" />
            <path d="M8 1 L8 3 M8 13 L8 15 M1 8 L3 8 M13 8 L15 8 M3.5 3.5 L4.9 4.9 M11.1 11.1 L12.5 12.5 M3.5 12.5 L4.9 11.1 M11.1 4.9 L12.5 3.5" />
        </svg>
    ),
    ChevronRight: ({ size = 14, color = 'currentColor' }) => (
        <svg width={size} height={size} viewBox="0 0 16 16" fill="none" stroke={color} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
            <polyline points="6,3 11,8 6,13" />
        </svg>
    ),
    Plus: ({ size = 14, color = 'currentColor' }) => (
        <svg width={size} height={size} viewBox="0 0 16 16" fill="none" stroke={color} strokeWidth="1.6" strokeLinecap="round">
            <line x1="8" y1="3" x2="8" y2="13" />
            <line x1="3" y1="8" x2="13" y2="8" />
        </svg>
    ),
    Sliders: ({ size = 16, color = 'currentColor' }) => (
        <svg width={size} height={size} viewBox="0 0 16 16" fill="none" stroke={color} strokeWidth="1.3" strokeLinecap="round">
            <line x1="3" y1="4" x2="13" y2="4" />
            <circle cx="9" cy="4" r="1.4" fill={color} />
            <line x1="3" y1="12" x2="13" y2="12" />
            <circle cx="6" cy="12" r="1.4" fill={color} />
        </svg>
    ),
    Wind: ({ size = 16, color = 'currentColor' }) => (
        <svg width={size} height={size} viewBox="0 0 16 16" fill="none" stroke={color} strokeWidth="1.2" strokeLinecap="round">
            <path d="M2 5 L9 5 A1.5 1.5 0 1 0 7.5 3.5" />
            <path d="M2 8 L12 8 A2 2 0 1 0 10 6" />
            <path d="M2 11 L7 11" />
        </svg>
    ),
};

window.TopoBg = TopoBg;
window.Icon = Icon;
