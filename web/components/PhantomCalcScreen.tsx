"use client";

// A faux iOS calculator screen that sits inside the PhoneFrame on the
// landing page. Cycles through 3 club recommendations with subtle
// motion, showing what the app produces without being interactive.

import { motion } from "framer-motion";
import { useEffect, useState } from "react";
import { LiveDispersionBackdrop } from "./LiveDispersionBackdrop";

const CYCLES = [
  { distance: 158, club: "7 Iron", carry: 158, prob: 0.74 },
  { distance: 142, club: "8 Iron", carry: 142, prob: 0.81 },
  { distance: 175, club: "6 Iron", carry: 175, prob: 0.69 },
];

export function PhantomCalcScreen() {
  const [idx, setIdx] = useState(0);

  useEffect(() => {
    const t = setInterval(() => setIdx((i) => (i + 1) % CYCLES.length), 4200);
    return () => clearInterval(t);
  }, []);

  const c = CYCLES[idx];
  const probColor =
    c.prob >= 0.75 ? "#62b375" : c.prob >= 0.55 ? "#a9d18e" : "#e6c068";

  return (
    <div className="flex h-full flex-col" style={{ background: "#0e1a13" }}>
      {/* Status bar */}
      <div
        className="flex items-center justify-between px-6 pt-12 pb-1 font-mono text-[10px]"
        style={{ color: "rgba(246, 241, 225, 0.55)" }}
      >
        <span>9:41</span>
        <span className="flex items-center gap-1">
          <svg viewBox="0 0 16 16" className="h-2.5 w-2.5" fill="currentColor">
            <path d="M2 11h2v3H2zM6 8h2v6H6zM10 5h2v9h-2zM14 2h2v12h-2z" />
          </svg>
          <svg viewBox="0 0 16 16" className="h-2.5 w-3.5" fill="currentColor">
            <rect x="1" y="5" width="11" height="6" rx="1.5" stroke="currentColor" fill="none" />
            <rect x="2" y="6" width="9" height="4" rx="0.5" />
            <rect x="13" y="7" width="1" height="2" />
          </svg>
        </span>
      </div>

      {/* Header */}
      <div className="px-5 pt-2 pb-3">
        <div className="flex items-center justify-between">
          <div>
            <span
              className="font-mono text-[9px] uppercase tracking-[0.18em]"
              style={{ color: "#62b375", opacity: 0.85 }}
            >
              Calculator
            </span>
            <h2
              className="font-display text-[22px] font-medium tracking-tight"
              style={{ color: "#f6f1e1", letterSpacing: "-0.4px" }}
            >
              Pick a club
            </h2>
          </div>
          <span
            className="rounded-full px-2 py-1 font-mono text-[9px] font-medium"
            style={{
              background: "rgba(98, 179, 117, 0.16)",
              color: "#a9d18e",
              boxShadow: "inset 0 0 0 1px rgba(98, 179, 117, 0.30)",
            }}
          >
            DECADE bias
          </span>
        </div>
      </div>

      {/* Distance pill row */}
      <div className="px-5">
        <motion.div
          key={`distance-${idx}`}
          initial={{ opacity: 0, y: 4 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.4 }}
          className="flex items-baseline gap-1"
        >
          <span
            className="font-display text-[44px] font-medium tabular-nums"
            style={{ color: "#f6f1e1", letterSpacing: "-1px", lineHeight: 1 }}
          >
            {c.distance}
          </span>
          <span
            className="font-mono text-[12px]"
            style={{ color: "rgba(246, 241, 225, 0.55)" }}
          >
            yards · pin
          </span>
        </motion.div>
      </div>

      {/* Dispersion canvas */}
      <div className="relative mx-5 mt-3 flex-1 overflow-hidden rounded-[18px]">
        <LiveDispersionBackdrop showZone intense />
        {/* Live probability badge */}
        <motion.div
          key={`prob-${idx}`}
          initial={{ opacity: 0, scale: 0.92 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ duration: 0.35 }}
          className="absolute left-1/2 top-3 -translate-x-1/2 rounded-full px-3 py-1.5 font-mono text-[11px] font-semibold"
          style={{
            background: "rgba(0, 0, 0, 0.55)",
            color: probColor,
            boxShadow: `inset 0 0 0 1px ${probColor}66`,
          }}
        >
          {Math.round(c.prob * 100)}% on green
        </motion.div>
      </div>

      {/* Recommended club card */}
      <motion.div
        key={`rec-${idx}`}
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4 }}
        className="mx-5 mb-5 mt-3 rounded-[14px] p-3"
        style={{
          background: "linear-gradient(135deg, rgba(98, 179, 117, 0.18), rgba(11, 61, 46, 0.30))",
          boxShadow: "inset 0 0 0 1px rgba(98, 179, 117, 0.35)",
        }}
      >
        <div className="flex items-center justify-between">
          <div>
            <span
              className="font-mono text-[8px] uppercase tracking-[0.2em]"
              style={{ color: "#a9d18e", opacity: 0.75 }}
            >
              Recommended
            </span>
            <div
              className="font-display text-[20px] font-semibold"
              style={{ color: "#f6f1e1", lineHeight: 1.1, marginTop: 2 }}
            >
              {c.club}
            </div>
          </div>
          <div className="text-right">
            <div
              className="font-mono text-[11px]"
              style={{ color: "rgba(246, 241, 225, 0.65)" }}
            >
              σ↕ 6.0 · σ↔ 8.7
            </div>
            <div
              className="font-mono text-[9px]"
              style={{ color: probColor }}
            >
              ↑ best of bag
            </div>
          </div>
        </div>
      </motion.div>
    </div>
  );
}
