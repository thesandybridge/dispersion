"use client";

// Number that counts up from 0 to a target value when it scrolls into
// view. Runs once. Uses requestAnimationFrame so it stays smooth.

import { useEffect, useRef, useState } from "react";

interface Props {
  value: number;
  /// Optional decimal places. 0 by default (integer).
  decimals?: number;
  /// Optional suffix appended to the displayed value, e.g. "%", "x", "+".
  suffix?: string;
  /// Animation duration, in ms.
  duration?: number;
  className?: string;
  style?: React.CSSProperties;
}

export function CountUp({
  value,
  decimals = 0,
  suffix = "",
  duration = 1200,
  className,
  style,
}: Props) {
  const [display, setDisplay] = useState(0);
  const ref = useRef<HTMLSpanElement>(null);
  const started = useRef(false);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting && !started.current) {
            started.current = true;
            const start = performance.now();
            const tick = (now: number) => {
              const t = Math.min(1, (now - start) / duration);
              const eased = 1 - Math.pow(1 - t, 3);
              setDisplay(value * eased);
              if (t < 1) requestAnimationFrame(tick);
              else setDisplay(value);
            };
            requestAnimationFrame(tick);
            observer.disconnect();
          }
        });
      },
      { threshold: 0.4 }
    );
    observer.observe(el);
    return () => observer.disconnect();
  }, [value, duration]);

  const formatted =
    decimals > 0
      ? display.toFixed(decimals)
      : Math.round(display).toString();

  return (
    <span ref={ref} className={className} style={style}>
      {formatted}
      {suffix}
    </span>
  );
}
