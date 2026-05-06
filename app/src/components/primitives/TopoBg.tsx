type Props = {
    width?: number;
    height?: number;
    color?: string;
    accent?: string;
    seed?: number;
};

export function TopoBg({
    width = 400,
    height = 200,
    color = "rgba(34,80,55,0.18)",
    accent = "rgba(232,93,77,0.35)",
    seed = 1,
}: Props) {
    const rand = makeRand(seed);
    const layers: Array<{ d: string }> = [];
    const numContours = 6;
    for (let i = 0; i < numContours; i++) {
        const points: string[] = [];
        const cx = width * (0.3 + rand() * 0.4);
        const cy = height * (0.4 + rand() * 0.3);
        const baseR = Math.min(width, height) * (0.18 + i * 0.12);
        const verts = 14 + i * 2;
        for (let v = 0; v < verts; v++) {
            const theta = (v / verts) * Math.PI * 2;
            const wobble = 0.7 + rand() * 0.5;
            const x = cx + Math.cos(theta) * baseR * wobble;
            const y = cy + Math.sin(theta) * baseR * wobble * 0.55;
            points.push(`${x.toFixed(1)},${y.toFixed(1)}`);
        }
        layers.push({ d: "M" + points.join(" L") + " Z" });
    }

    return (
        <svg
            width={width}
            height={height}
            viewBox={`0 0 ${width} ${height}`}
            style={{ display: "block" }}
        >
            <g fill="none" stroke={color} strokeWidth="0.7">
                {layers.map((l, i) => (
                    <path key={i} d={l.d} opacity={0.4 + i * 0.08} />
                ))}
            </g>
            {layers[2] && (
                <path
                    d={layers[2].d}
                    fill="none"
                    stroke={accent}
                    strokeWidth="1"
                    opacity="0.7"
                />
            )}
        </svg>
    );
}

function makeRand(seed: number): () => number {
    let s = seed * 9301 + 49297;
    return () => {
        s = (s * 9301 + 49297) % 233280;
        return s / 233280;
    };
}
