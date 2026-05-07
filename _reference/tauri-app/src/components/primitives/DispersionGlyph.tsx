type Props = {
    carrySd: number;
    lateralSd: number;
    width?: number;
    height?: number;
    fill?: string;
    stroke?: string;
};

export function DispersionGlyph({
    carrySd,
    lateralSd,
    width = 44,
    height = 28,
    fill = "#62b375",
    stroke = "#2c8a5e",
}: Props) {
    const facets = 12;
    const cx = width / 2;
    const cy = height / 2;
    const rx = Math.min(14, lateralSd * 0.7);
    const ry = Math.min(10, carrySd * 0.5);
    const pts: string[] = [];
    for (let i = 0; i < facets; i++) {
        const t = (i / facets) * Math.PI * 2;
        pts.push(
            `${(cx + Math.cos(t) * rx).toFixed(2)},${(cy + Math.sin(t) * ry).toFixed(2)}`,
        );
    }
    return (
        <svg width={width} height={height} viewBox={`0 0 ${width} ${height}`}>
            <polygon
                points={pts.join(" ")}
                fill={fill}
                fillOpacity="0.25"
                stroke={stroke}
                strokeWidth="0.8"
            />
            <circle cx={cx} cy={cy} r="1.4" fill={stroke} />
        </svg>
    );
}
