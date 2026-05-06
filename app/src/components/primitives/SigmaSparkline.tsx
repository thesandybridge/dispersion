type Props = {
    points: number[];
    width?: number;
    height?: number;
    stroke?: string;
    fill?: string;
};

export function SigmaSparkline({
    points,
    width = 86,
    height = 22,
    stroke = "#2c8a5e",
    fill = "#62b375",
}: Props) {
    if (points.length < 2) return null;
    const min = Math.min(...points);
    const max = Math.max(...points);
    const range = max - min || 1;
    const path = points
        .map((v, i) => {
            const x = (i / (points.length - 1)) * width;
            const y = height - ((v - min) / range) * height;
            return `${i === 0 ? "M" : "L"}${x.toFixed(1)},${y.toFixed(1)}`;
        })
        .join(" ");
    return (
        <svg
            width={width}
            height={height}
            viewBox={`0 0 ${width} ${height}`}
            style={{ display: "block", marginTop: 6 }}
        >
            <path
                d={`${path} L${width},${height} L0,${height} Z`}
                fill={fill}
                fillOpacity="0.12"
            />
            <path
                d={path}
                stroke={stroke}
                strokeWidth="1.4"
                fill="none"
                strokeLinecap="round"
            />
        </svg>
    );
}
