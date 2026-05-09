"use client";

// Live interactive demo. Drag distance + zone, see the recommended club
// update via the actual TS port of the iOS probability math. The moneyshot
// of the marketing site — readers can prove to themselves that the math
// works before opening the App Store.

import { useMemo, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { DispersionCanvas } from "./DispersionCanvas";
import {
  SAMPLE_BAG,
  rankClubs,
  probLabel,
  type ShotScenario,
} from "@/lib/dispersion";

const PRESETS: { id: string; label: string; w: number; d: number; kind: "green" | "fairway" }[] = [
  { id: "fairway",       label: "Fairway",       w: 30, d: 60, kind: "fairway" },
  { id: "tight-fairway", label: "Tight fairway", w: 22, d: 50, kind: "fairway" },
  { id: "green",         label: "Green",         w: 25, d: 25, kind: "green" },
  { id: "lay-up",        label: "Lay-up",        w: 40, d: 30, kind: "fairway" },
  { id: "tight-pin",     label: "Tight pin",     w: 14, d: 14, kind: "green" },
];

export function InteractiveDemo() {
  const [distance, setDistance] = useState(150);
  const [presetId, setPresetId] = useState("green");
  const preset = PRESETS.find((p) => p.id === presetId) ?? PRESETS[0];

  const scenario: ShotScenario = useMemo(
    () => ({
      distanceToTargetYards: distance,
      safeZoneWidthYards: preset.w,
      safeZoneDepthYards: preset.d,
    }),
    [distance, preset]
  );

  const ranked = useMemo(() => rankClubs(SAMPLE_BAG, scenario), [scenario]);
  const recommended = ranked[0];
  const recClub = SAMPLE_BAG.find((c) => c.id === recommended?.clubId);
  const lbl = probLabel(recommended?.probabilityInZone ?? 0);

  return (
    <div className="grid grid-cols-1 gap-6 md:grid-cols-2 md:gap-10 lg:gap-16">
      {/* Visualization */}
      <div className="relative">
        <div className="aspect-square w-full overflow-hidden rounded-3xl bg-pine ring-1 ring-pine/20 shadow-2xl shadow-pine/20">
          {recClub && (
            <DispersionCanvas
              carry={recClub.carryYards}
              carrySd={recClub.carrySd}
              lateralSd={recClub.lateralSd}
              distanceToTarget={distance}
              zoneWidth={preset.w}
              zoneDepth={preset.d}
              zoneKind={preset.kind}
            />
          )}
        </div>

        {/* Live probability badge */}
        <AnimatePresence mode="wait">
          {recommended && (
            <motion.div
              key={`${recommended.clubId}-${Math.round(recommended.probabilityInZone * 100)}`}
              initial={{ opacity: 0, y: 8, scale: 0.95 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              exit={{ opacity: 0, y: -4 }}
              transition={{ duration: 0.18 }}
              className="absolute right-4 top-4 flex items-baseline gap-1 rounded-full bg-canvas-50/95 px-4 py-2 text-pine shadow-xl ring-1 ring-pine/15 backdrop-blur"
            >
              <span className="font-display text-2xl font-semibold tabular-nums">
                {Math.round(recommended.probabilityInZone * 100)}
              </span>
              <span className="font-mono text-xs text-canvas-500">%</span>
            </motion.div>
          )}
        </AnimatePresence>
      </div>

      {/* Controls + recommendation card */}
      <div className="flex flex-col justify-between gap-6">
        <div className="space-y-6">
          {/* Distance */}
          <div className="space-y-2">
            <div className="flex items-baseline justify-between">
              <span className="eyebrow">Distance to target</span>
              <span className="font-display text-3xl font-semibold tabular-nums text-pine">
                {distance}
                <span className="ml-1 text-base font-normal text-canvas-400">y</span>
              </span>
            </div>
            <input
              type="range"
              min={50}
              max={260}
              step={1}
              value={distance}
              onChange={(e) => setDistance(parseInt(e.target.value))}
              className="w-full accent-bentgrass"
              aria-label="Distance to target in yards"
            />
            <div className="flex justify-between font-mono text-xs text-canvas-400">
              <span>50y</span>
              <span>260y</span>
            </div>
          </div>

          {/* Zone preset */}
          <div className="space-y-2">
            <span className="eyebrow">Target type</span>
            <div className="flex flex-wrap gap-2">
              {PRESETS.map((p) => (
                <button
                  key={p.id}
                  type="button"
                  onClick={() => setPresetId(p.id)}
                  className={
                    "rounded-full px-4 py-1.5 text-sm font-medium transition " +
                    (presetId === p.id
                      ? "bg-pine text-canvas-50"
                      : "bg-canvas-100 text-canvas-600 hover:bg-canvas-200")
                  }
                >
                  {p.label}
                </button>
              ))}
            </div>
            <div className="font-mono text-xs text-canvas-400">
              {preset.w}y wide · {preset.d}y deep
            </div>
          </div>
        </div>

        {/* Recommendation card */}
        {recommended && recClub && (
          <motion.div
            key={recommended.clubId}
            initial={{ opacity: 0, y: 6 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.22 }}
            className="rounded-2xl border border-canvas-200 bg-white p-5 shadow-sm"
          >
            <div className="eyebrow flex items-center gap-2">
              <span
                className="h-1.5 w-1.5 rounded-full"
                style={{ backgroundColor: lbl.color }}
              />
              <span>Recommended · {lbl.label.toLowerCase()}</span>
            </div>
            <div className="mt-1 font-display text-display-xs font-semibold tracking-display-tight text-pine">
              {recClub.name}
            </div>
            <div className="mt-3 flex flex-wrap gap-x-5 gap-y-1 font-mono text-xs text-canvas-500">
              <span>EXP {Math.round(recClub.carryYards)}y</span>
              <span>σ↕ {recClub.carrySd.toFixed(1)}</span>
              <span>σ↔ {recClub.lateralSd.toFixed(1)}</span>
            </div>

            {/* Top 3 alternates */}
            <div className="mt-5 space-y-2">
              <div className="eyebrow">Other options</div>
              <div className="flex flex-col gap-1.5">
                {ranked.slice(1, 4).map((r) => {
                  const c = SAMPLE_BAG.find((x) => x.id === r.clubId);
                  if (!c) return null;
                  const altLbl = probLabel(r.probabilityInZone);
                  return (
                    <div
                      key={r.clubId}
                      className="flex items-center gap-3 text-sm"
                    >
                      <span className="text-canvas-700 w-16">{c.name}</span>
                      <div className="h-1.5 flex-1 overflow-hidden rounded-full bg-canvas-100">
                        <div
                          className="h-full rounded-full transition-[width]"
                          style={{
                            width: `${Math.round(r.probabilityInZone * 100)}%`,
                            backgroundColor: altLbl.color,
                          }}
                        />
                      </div>
                      <span
                        className="font-mono text-xs tabular-nums"
                        style={{ color: altLbl.color }}
                      >
                        {Math.round(r.probabilityInZone * 100)}%
                      </span>
                    </div>
                  );
                })}
              </div>
            </div>
          </motion.div>
        )}
      </div>
    </div>
  );
}
