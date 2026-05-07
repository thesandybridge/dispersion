import { useEffect, useRef, useState } from "react";

export function useElementSize<T extends HTMLElement>(): [
    React.RefObject<T | null>,
    { width: number; height: number },
] {
    const ref = useRef<T | null>(null);
    const [size, setSize] = useState({ width: 0, height: 0 });

    useEffect(() => {
        const el = ref.current;
        if (!el) return;
        const ro = new ResizeObserver((entries) => {
            for (const entry of entries) {
                const cr = entry.contentRect;
                setSize({ width: cr.width, height: cr.height });
            }
        });
        ro.observe(el);
        return () => ro.disconnect();
    }, []);

    return [ref, size];
}
