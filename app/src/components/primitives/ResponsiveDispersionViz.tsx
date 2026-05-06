import { useElementSize } from "../../lib/useElementSize";
import { DispersionViz } from "./DispersionViz";

type Props = Omit<
    Parameters<typeof DispersionViz>[0],
    "width" | "height" | "style"
> & {
    minWidth?: number;
    minHeight?: number;
    style?: React.CSSProperties;
};

export function ResponsiveDispersionViz({
    minWidth = 200,
    minHeight = 200,
    style,
    ...rest
}: Props) {
    const [ref, size] = useElementSize<HTMLDivElement>();
    const w = Math.max(size.width || minWidth, minWidth);
    const h = Math.max(size.height || minHeight, minHeight);
    return (
        <div ref={ref} style={{ width: "100%", height: "100%", ...style }}>
            {size.width > 0 && size.height > 0 && (
                <DispersionViz
                    {...rest}
                    width={w}
                    height={h}
                    style={{ width: "100%", height: "100%" }}
                />
            )}
        </div>
    );
}
