"use client";

// Continuously animating dispersion contours used as a hero centerpiece.
// Renders the same heat-mapped ellipses the iOS app shows, but with σ
// values that drift on a slow easing loop so the surface feels alive
// without distracting. Fully responsive — hands the canvas as much
// space as the parent gives it.

import { useEffect, useRef } from "react";

const PALETTE = [
  "#0b3d2e", "#16624a", "#2c8a5e", "#62b375", "#a9d18e", "#f0e7b8",
];

interface Props {
  /// Whether to draw the safe-zone polygon on top. The hero uses this
  /// to anchor the visual; the section variant skips it for a softer
  /// background mood.
  showZone?: boolean;
  /// Whether to render at "demo" intensity (brighter contours, more
  /// visible). Background mode is more muted.
  intense?: boolean;
}

export function LiveDispersionBackdrop({
  showZone = true,
  intense = true,
}: Props) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const rafRef = useRef<number | null>(null);
  const startRef = useRef<number>(0);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    let stop = false;
    const dpr = window.devicePixelRatio || 1;

    function resize() {
      if (!canvas) return;
      const r = canvas.getBoundingClientRect();
      canvas.width = r.width * dpr;
      canvas.height = r.height * dpr;
      ctx?.setTransform(dpr, 0, 0, dpr, 0, 0);
    }

    function draw(t: number) {
      if (stop) return;
      if (!startRef.current) startRef.current = t;
      const elapsed = (t - startRef.current) / 1000;
      const r = canvas!.getBoundingClientRect();
      const W = r.width;
      const H = r.height;

      // Drift σ values on slow eased loops.
      const carrySd = 6 + Math.sin(elapsed * 0.35) * 1.6;
      const lateralSd = 8 + Math.cos(elapsed * 0.28) * 2.0;
      const aimX = Math.sin(elapsed * 0.22) * 4;

      ctx!.clearRect(0, 0, W, H);

      // Background gradient — radial, subtle, theme-independent so the
      // contours always pop on top.
      const bgGrad = ctx!.createRadialGradient(
        W / 2, H * 0.55, 0,
        W / 2, H * 0.55, Math.max(W, H) * 0.7
      );
      bgGrad.addColorStop(0, "rgba(11, 61, 46, 0.0)");
      bgGrad.addColorStop(1, "rgba(11, 61, 46, 0.0)");
      ctx!.fillStyle = bgGrad;
      ctx!.fillRect(0, 0, W, H);

      // Layout
      const pad = 24;
      const span = Math.max(carrySd * 3.5, lateralSd * 3.5, 28);
      const fitX = (W - pad * 2) / (span * 2);
      const fitY = (H - pad * 2) / (span * 2);
      const scale = Math.min(fitX, fitY);
      const cx = W / 2 + aimX * scale;
      const cy = H / 2;

      // Concentric heat ellipses — 6 rings, dim outer to bright inner.
      const contours = 6;
      const ks: number[] = [];
      for (let i = 0; i < contours; i++) {
        ks.push(0.6 + (i / (contours - 1)) * (2.6 - 0.6));
      }
      const baseAlpha = intense ? 0.65 : 0.36;
      for (let i = ks.length - 1; i >= 0; i--) {
        const k = ks[i];
        const rx = lateralSd * k * scale;
        const ry = carrySd * k * scale;
        const tNorm = i / (ks.length - 1);
        const alpha = 0.05 + tNorm * baseAlpha;
        ctx!.fillStyle = withAlpha(PALETTE[Math.min(i, PALETTE.length - 1)], alpha);
        ctx!.beginPath();
        ctx!.ellipse(cx, cy, Math.max(rx, 0.5), Math.max(ry, 0.5), 0, 0, Math.PI * 2);
        ctx!.fill();
      }

      if (showZone) {
        // Soft safe-zone bracket — square-ish shape at center.
        const zoneSize = 25 * scale;
        const zoneRect = [
          W / 2 - zoneSize / 2,
          H / 2 - zoneSize / 2,
          zoneSize,
          zoneSize,
        ] as const;
        const r = Math.min(zoneSize, zoneSize) * 0.32;
        ctx!.beginPath();
        roundRect(ctx!, zoneRect[0], zoneRect[1], zoneRect[2], zoneRect[3], r);
        ctx!.fillStyle = "rgba(98, 179, 117, 0.20)";
        ctx!.fill();
        ctx!.strokeStyle = "rgba(98, 179, 117, 0.55)";
        ctx!.lineWidth = 1.2;
        ctx!.stroke();
      }

      // Mean dot
      ctx!.fillStyle = "#62b375";
      ctx!.beginPath();
      ctx!.arc(cx, cy, 4, 0, Math.PI * 2);
      ctx!.fill();
      ctx!.strokeStyle = "rgba(98, 179, 117, 0.4)";
      ctx!.lineWidth = 1;
      ctx!.beginPath();
      ctx!.arc(cx, cy, 6, 0, Math.PI * 2);
      ctx!.stroke();

      // Pin in the center
      ctx!.strokeStyle = "rgba(255, 255, 255, 0.92)";
      ctx!.lineWidth = 1.5;
      ctx!.beginPath();
      ctx!.moveTo(W / 2, H / 2);
      ctx!.lineTo(W / 2, H / 2 - 22);
      ctx!.stroke();
      ctx!.fillStyle = "#e85d4d";
      ctx!.beginPath();
      ctx!.moveTo(W / 2, H / 2 - 22);
      ctx!.lineTo(W / 2 + 12, H / 2 - 18);
      ctx!.lineTo(W / 2, H / 2 - 14);
      ctx!.closePath();
      ctx!.fill();

      rafRef.current = requestAnimationFrame(draw);
    }

    resize();
    const ro = new ResizeObserver(resize);
    ro.observe(canvas);
    rafRef.current = requestAnimationFrame(draw);

    return () => {
      stop = true;
      ro.disconnect();
      if (rafRef.current) cancelAnimationFrame(rafRef.current);
    };
  }, [intense, showZone]);

  return (
    <canvas
      ref={canvasRef}
      className="h-full w-full"
      style={{ display: "block" }}
      aria-hidden
    />
  );
}

function withAlpha(hex: string, a: number): string {
  const m = hex.replace("#", "");
  const r = parseInt(m.substring(0, 2), 16);
  const g = parseInt(m.substring(2, 4), 16);
  const b = parseInt(m.substring(4, 6), 16);
  return `rgba(${r}, ${g}, ${b}, ${a})`;
}

function roundRect(ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, r: number) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.lineTo(x + w - r, y);
  ctx.quadraticCurveTo(x + w, y, x + w, y + r);
  ctx.lineTo(x + w, y + h - r);
  ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
  ctx.lineTo(x + r, y + h);
  ctx.quadraticCurveTo(x, y + h, x, y + h - r);
  ctx.lineTo(x, y + r);
  ctx.quadraticCurveTo(x, y, x + r, y);
  ctx.closePath();
}
