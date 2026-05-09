"use client";

// HTML Canvas port of the iOS DispersionViz. Same heat palette, same
// concentric probability contours, same flag pin glyph. Designed to scale
// fluidly inside any container — call site provides width/height via CSS.

import { useEffect, useRef } from "react";

interface DispersionCanvasProps {
  carry: number;          // expected carry of the active club (yards)
  carrySd: number;        // σ↕
  lateralSd: number;      // σ↔
  distanceToTarget: number;
  zoneWidth: number;
  zoneDepth: number;
  aimLateralYards?: number;
  zoneKind?: "green" | "fairway";
  contours?: number;
}

const PALETTE = {
  heat0: "#0b3d2e",
  heat1: "#16624a",
  heat2: "#2c8a5e",
  heat3: "#62b375",
  heat4: "#a9d18e",
  heat5: "#f0e7b8",
  primary: "#62b375",
  flag: "#e85d4d",
  greenFill: "#62b3754d",   // 0.30 alpha
  greenStroke: "#62b375a6", // 0.65 alpha
};

export function DispersionCanvas({
  carry,
  carrySd,
  lateralSd,
  distanceToTarget,
  zoneWidth,
  zoneDepth,
  aimLateralYards = 0,
  zoneKind = "green",
  contours = 6,
}: DispersionCanvasProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const dpr = window.devicePixelRatio || 1;
    const rect = canvas.getBoundingClientRect();
    canvas.width = rect.width * dpr;
    canvas.height = rect.height * dpr;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;
    ctx.scale(dpr, dpr);
    ctx.clearRect(0, 0, rect.width, rect.height);

    drawScene(ctx, rect.width, rect.height, {
      carry,
      carrySd,
      lateralSd,
      distanceToTarget,
      zoneWidth,
      zoneDepth,
      aimLateralYards,
      zoneKind,
      contours,
    });
  }, [
    carry,
    carrySd,
    lateralSd,
    distanceToTarget,
    zoneWidth,
    zoneDepth,
    aimLateralYards,
    zoneKind,
    contours,
  ]);

  return (
    <canvas
      ref={canvasRef}
      className="h-full w-full"
      style={{ touchAction: "none" }}
    />
  );
}

// MARK: - Drawing

interface SceneArgs {
  carry: number;
  carrySd: number;
  lateralSd: number;
  distanceToTarget: number;
  zoneWidth: number;
  zoneDepth: number;
  aimLateralYards: number;
  zoneKind: "green" | "fairway";
  contours: number;
}

function drawScene(
  ctx: CanvasRenderingContext2D,
  W: number,
  H: number,
  args: SceneArgs
) {
  const pad = 28;
  const zoneHalfW = args.zoneWidth / 2 + 5;
  const zoneHalfD = args.zoneDepth / 2 + 5;
  const longSpan = Math.max(args.carrySd * 3.5, zoneHalfD, 25);
  const latSpan = Math.max(
    args.lateralSd * 3.5 + Math.abs(args.aimLateralYards),
    zoneHalfW + Math.abs(args.aimLateralYards),
    18
  );
  const fitX = (W - pad * 2) / (latSpan * 2);
  const fitY = (H - pad * 2) / (longSpan * 2);
  const scale = Math.min(fitX, fitY);

  const targetX = W / 2;
  const targetY = H / 2;
  const meanLong = args.carry - args.distanceToTarget;
  const meanX = targetX + args.aimLateralYards * scale;
  const meanY = targetY - meanLong * scale;

  // 1. Heat-mapped probability contours (outermost faintest → innermost brightest).
  const ks: number[] = [];
  const stepCount = Math.max(args.contours - 1, 1);
  for (let i = 0; i < args.contours; i++) {
    ks.push(0.6 + (i / stepCount) * (2.6 - 0.6));
  }
  const ramp = [
    PALETTE.heat0, PALETTE.heat1, PALETTE.heat2,
    PALETTE.heat3, PALETTE.heat4, PALETTE.heat5,
  ];
  for (let i = ks.length - 1; i >= 0; i--) {
    const k = ks[i];
    const rx = args.lateralSd * k * scale;
    const ry = args.carrySd * k * scale;
    const t = i / Math.max(ks.length - 1, 1);
    const alpha = 0.05 + t * 0.55;
    ctx.fillStyle = withAlpha(ramp[Math.min(i, ramp.length - 1)], alpha);
    ellipse(ctx, meanX, meanY, rx, ry);
    ctx.fill();
  }

  // 2. Safe zone — green-shaped polygon for greens, neutral rect for fairway.
  const zoneRect = {
    x: targetX - (args.zoneWidth / 2) * scale,
    y: targetY - (args.zoneDepth / 2) * scale,
    w: args.zoneWidth * scale,
    h: args.zoneDepth * scale,
  };
  const r = Math.min(zoneRect.w, zoneRect.h) * 0.32;
  roundedRect(ctx, zoneRect.x, zoneRect.y, zoneRect.w, zoneRect.h, r);
  ctx.fillStyle = PALETTE.greenFill;
  ctx.fill();
  ctx.strokeStyle = PALETTE.greenStroke;
  ctx.lineWidth = 1.5;
  ctx.stroke();

  // 3. Mean → target dashed line if dispersion is offset.
  if (Math.abs(args.aimLateralYards) > 0.5 || Math.abs(meanLong) > 0.5) {
    ctx.save();
    ctx.setLineDash([3, 3]);
    ctx.strokeStyle = withAlpha(PALETTE.primary, 0.55);
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(targetX, targetY);
    ctx.lineTo(meanX, meanY);
    ctx.stroke();
    ctx.restore();
  }

  // 4. Mean dot.
  ctx.fillStyle = PALETTE.primary;
  ellipse(ctx, meanX, meanY, 4, 4);
  ctx.fill();
  ctx.strokeStyle = withAlpha(PALETTE.primary, 0.4);
  ctx.lineWidth = 1;
  ellipse(ctx, meanX, meanY, 6, 6);
  ctx.stroke();

  // 5. Target glyph.
  if (args.zoneKind === "green") {
    drawPin(ctx, targetX, targetY);
  } else {
    drawFairwayMarker(ctx, targetX, targetY);
  }
}

function drawPin(ctx: CanvasRenderingContext2D, x: number, y: number) {
  // Stick
  ctx.strokeStyle = "rgba(255,255,255,0.9)";
  ctx.lineWidth = 1.5;
  ctx.beginPath();
  ctx.moveTo(x, y);
  ctx.lineTo(x, y - 22);
  ctx.stroke();
  // Flag
  ctx.fillStyle = PALETTE.flag;
  ctx.beginPath();
  ctx.moveTo(x, y - 22);
  ctx.lineTo(x + 12, y - 18);
  ctx.lineTo(x, y - 14);
  ctx.closePath();
  ctx.fill();
  // Cup
  ctx.fillStyle = "rgba(0,0,0,0.55)";
  ellipse(ctx, x, y, 3, 1.5);
  ctx.fill();
  ctx.strokeStyle = "rgba(255,255,255,0.6)";
  ctx.lineWidth = 0.8;
  ellipse(ctx, x, y, 3, 1.5);
  ctx.stroke();
}

function drawFairwayMarker(ctx: CanvasRenderingContext2D, x: number, y: number) {
  ctx.strokeStyle = "rgba(255,255,255,0.85)";
  ctx.lineWidth = 1.2;
  ellipse(ctx, x, y, 11, 11);
  ctx.stroke();
  ctx.fillStyle = "rgba(255,255,255,0.95)";
  ellipse(ctx, x, y, 2.5, 2.5);
  ctx.fill();
  ctx.strokeStyle = "rgba(255,255,255,0.7)";
  ctx.lineWidth = 1;
  for (const [dx, dy] of [
    [-16, 0], [-4, 0],
    [4, 0], [16, 0],
    [0, -16], [0, -4],
    [0, 4], [0, 16],
  ]) {
    ctx.beginPath();
    ctx.moveTo(x + dx, y + dy);
    if (dx !== 0) ctx.lineTo(x + dx + Math.sign(dx) * (Math.abs(dx) === 16 ? 0 : -1), y + dy);
    if (dy !== 0) ctx.lineTo(x + dx, y + dy + Math.sign(dy) * (Math.abs(dy) === 16 ? 0 : -1));
    ctx.stroke();
  }
}

// MARK: - Canvas helpers

function ellipse(
  ctx: CanvasRenderingContext2D,
  cx: number, cy: number,
  rx: number, ry: number
) {
  ctx.beginPath();
  ctx.ellipse(cx, cy, Math.max(rx, 0.5), Math.max(ry, 0.5), 0, 0, Math.PI * 2);
  ctx.closePath();
}

function roundedRect(
  ctx: CanvasRenderingContext2D,
  x: number, y: number, w: number, h: number, r: number
) {
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

function withAlpha(hex: string, a: number): string {
  const m = hex.replace("#", "");
  const r = parseInt(m.substring(0, 2), 16);
  const g = parseInt(m.substring(2, 4), 16);
  const b = parseInt(m.substring(4, 6), 16);
  return `rgba(${r}, ${g}, ${b}, ${a})`;
}
