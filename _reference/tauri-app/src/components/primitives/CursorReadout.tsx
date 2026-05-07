import { useEffect, useRef, useState } from "react";
import { useElementSize } from "../../lib/useElementSize";

type Props = {
    carry: number;
    carrySd: number;
    lateralSd: number;
    distanceToTarget: number;
    tailFactor?: number;
};

export function CursorReadout({
    carry,
    carrySd,
    lateralSd,
    distanceToTarget,
    tailFactor = 1.4,
}: Props) {
    const [ref, size] = useElementSize<HTMLDivElement>();
    const svgRef = useRef<SVGSVGElement>(null);
    const [cursor, setCursor] = useState<{ x: number; y: number } | null>(null);

    const longSpan = Math.max(
        carrySd * 3.0 * tailFactor,
        Math.abs(distanceToTarget - carry) + carrySd * 2,
    );
    const latSpan = Math.max(lateralSd * 3.0, lateralSd * 2.4);
    const worldW = latSpan * 2;
    const worldH = longSpan * 2;
    const w = size.width || 1;
    const h = size.height || 1;
    const scale = Math.max(w / worldW, h / worldH);

    const sx = (lat: number) => w / 2 + lat * scale;
    const sy = (lng: number) => h / 2 - (lng - carry) * scale;

    function clientToWorld(
        clientX: number,
        clientY: number,
    ): { lat: number; long: number } | null {
        const svg = svgRef.current;
        if (!svg) return null;
        const pt = svg.createSVGPoint();
        pt.x = clientX;
        pt.y = clientY;
        const ctm = svg.getScreenCTM();
        if (!ctm) return null;
        const local = pt.matrixTransform(ctm.inverse());
        const lat = (local.x - w / 2) / scale;
        const long = carry - (local.y - h / 2) / scale;
        return { lat, long };
    }

    useEffect(() => {
        const el = ref.current;
        if (!el) return;
        function onMove(e: PointerEvent) {
            setCursor({ x: e.clientX, y: e.clientY });
        }
        function onLeave() {
            setCursor(null);
        }
        el.addEventListener("pointermove", onMove);
        el.addEventListener("pointerleave", onLeave);
        return () => {
            el.removeEventListener("pointermove", onMove);
            el.removeEventListener("pointerleave", onLeave);
        };
    }, [ref]);

    let cursorWorld: { lat: number; long: number } | null = null;
    if (cursor) cursorWorld = clientToWorld(cursor.x, cursor.y);

    let distance: number | null = null;
    let cx = 0;
    let cy = 0;
    if (cursorWorld) {
        const dlat = cursorWorld.lat;
        const dlong = cursorWorld.long - distanceToTarget;
        distance = Math.sqrt(dlat * dlat + dlong * dlong);
        cx = sx(cursorWorld.lat);
        cy = sy(cursorWorld.long);
    }

    return (
        <div
            ref={ref}
            className="absolute inset-0 pointer-events-auto cursor-readout"
            style={{ cursor: "default" }}
        >
            <svg
                ref={svgRef}
                width="100%"
                height="100%"
                viewBox={`0 0 ${w} ${h}`}
                preserveAspectRatio="none"
                style={{ display: "block" }}
            >
                {distance !== null && cursorWorld && (
                    <g pointerEvents="none">
                        <line
                            x1={sx(0)}
                            y1={sy(distanceToTarget)}
                            x2={cx}
                            y2={cy}
                            stroke="rgba(246,241,225,0.45)"
                            strokeWidth="1"
                            strokeDasharray="3 4"
                        />
                        <circle
                            cx={cx}
                            cy={cy}
                            r="14"
                            fill="rgba(246,241,225,0.06)"
                            stroke="rgba(246,241,225,0.7)"
                            strokeWidth="1"
                        />
                        <circle cx={cx} cy={cy} r="2" fill="#f6f1e1" />
                        <CursorLabel
                            x={cx}
                            y={cy}
                            distance={distance}
                            cursorWorld={cursorWorld}
                            target={{ lat: 0, long: distanceToTarget }}
                            canvasW={w}
                            canvasH={h}
                        />
                    </g>
                )}
            </svg>
        </div>
    );
}

function CursorLabel({
    x,
    y,
    distance,
    cursorWorld,
    target,
    canvasW,
    canvasH,
}: {
    x: number;
    y: number;
    distance: number;
    cursorWorld: { lat: number; long: number };
    target: { lat: number; long: number };
    canvasW: number;
    canvasH: number;
}) {
    const padding = 10;
    const labelOffsetX = 18;
    const labelOffsetY = -22;
    const labelW = 132;
    const labelH = 50;

    let lx = x + labelOffsetX;
    let ly = y + labelOffsetY;
    if (lx + labelW > canvasW - padding) lx = x - labelW - labelOffsetX;
    if (ly < padding) ly = y + 14;
    if (ly + labelH > canvasH - padding)
        ly = canvasH - labelH - padding;

    const dlong = cursorWorld.long - target.long;
    const dlat = cursorWorld.lat - target.lat;

    return (
        <g transform={`translate(${lx}, ${ly})`}>
            <rect
                x="0"
                y="0"
                width={labelW}
                height={labelH}
                rx="6"
                fill="rgba(10,20,16,0.85)"
                stroke="rgba(246,241,225,0.18)"
                strokeWidth="0.75"
            />
            <text
                x="9"
                y="16"
                fill="#f6f1e1"
                fontFamily="ui-monospace, monospace"
                fontSize="11"
                fontWeight="500"
            >
                {distance.toFixed(1)}y to target
            </text>
            <text
                x="9"
                y="32"
                fill="rgba(246,241,225,0.55)"
                fontFamily="ui-monospace, monospace"
                fontSize="9.5"
            >
                {dlong >= 0 ? "+" : ""}
                {dlong.toFixed(1)} long
            </text>
            <text
                x="9"
                y="44"
                fill="rgba(246,241,225,0.55)"
                fontFamily="ui-monospace, monospace"
                fontSize="9.5"
            >
                {dlat >= 0 ? "+" : ""}
                {dlat.toFixed(1)} lat
            </text>
        </g>
    );
}
