"use client";

import Link from "next/link";
import { motion } from "framer-motion";
import { PhoneFrame } from "./PhoneFrame";
import { PhantomCalcScreen } from "./PhantomCalcScreen";

export function Hero() {
  return (
    <section className="relative overflow-hidden pt-32 pb-16 sm:pt-40 sm:pb-20">
      {/* Ambient backdrop — soft mesh of accent gradients. Sits behind
          everything; doesn't compete with the phone or the typography. */}
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0 -z-10 gradient-hero"
      />
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0 -z-10 opacity-70"
        style={{
          background:
            "radial-gradient(ellipse 60% 40% at 80% 0%, var(--accent-tint), transparent 60%), radial-gradient(ellipse 60% 40% at 0% 80%, var(--accent-tint), transparent 65%)",
        }}
      />

      <div className="container-prose">
        <div className="grid grid-cols-1 items-center gap-14 lg:grid-cols-[1fr_auto] lg:gap-20">
          {/* Copy column */}
          <motion.div
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.7, ease: [0.22, 1, 0.36, 1] }}
          >
            <div className="inline-flex items-center gap-2 rounded-full border px-3 py-1 font-mono text-[10px] uppercase tracking-[0.2em]"
              style={{
                borderColor: "var(--border)",
                background: "var(--accent-tint)",
                color: "var(--accent)",
              }}
            >
              <span className="relative flex h-1.5 w-1.5">
                <span
                  className="absolute inline-flex h-full w-full animate-ping rounded-full opacity-75"
                  style={{ background: "var(--accent)" }}
                />
                <span
                  className="relative inline-flex h-1.5 w-1.5 rounded-full"
                  style={{ background: "var(--accent)" }}
                />
              </span>
              Probability-first golf · iOS 18+
            </div>

            <h1
              className="mt-6 font-display font-semibold tracking-display-tight text-balance"
              style={{
                color: "var(--accent-strong)",
                fontSize: "clamp(2.6rem, 6.5vw, 5.4rem)",
                lineHeight: 1.02,
                letterSpacing: "-0.02em",
              }}
            >
              Hit the club{" "}
              <span className="italic" style={{ color: "var(--accent)" }}>
                most likely
              </span>{" "}
              <span className="block sm:inline">to land where you want.</span>
            </h1>

            <p
              className="mt-7 max-w-xl text-lg leading-relaxed"
              style={{ color: "var(--fg-soft)" }}
            >
              Dispersion models every club in your bag as a 2D probability
              distribution. Tell it your target. It tells you the club with
              the highest chance of getting there. The math is honest, the
              data stays on your phone, and the recommendation is always one
              tap away.
            </p>

            <div className="mt-9 flex flex-wrap items-center gap-3">
              <Link
                href="https://apps.apple.com/app/id000000000"
                className="group inline-flex items-center gap-2 rounded-full px-6 py-3 text-base font-medium shadow-lg transition hover:scale-[1.02]"
                style={{
                  background: "var(--accent-strong)",
                  color: "var(--bg)",
                  boxShadow:
                    "0 16px 36px -10px rgba(var(--shadow-rgb), 0.30)",
                }}
              >
                <svg viewBox="0 0 24 24" fill="currentColor" className="h-5 w-5">
                  <path d="M17.05 20.28c-.98.95-2.05.8-3.08.35-1.09-.46-2.09-.48-3.24 0-1.44.62-2.2.44-3.06-.35C2.79 15.25 3.51 7.59 9.05 7.31c1.35.07 2.29.74 3.08.8 1.18-.24 2.31-.93 3.57-.84 1.51.12 2.65.72 3.4 1.8-3.12 1.87-2.38 5.98.48 7.13-.57 1.5-1.31 2.99-2.54 4.09zM12.03 7.25c-.15-2.23 1.66-4.07 3.74-4.25.29 2.58-2.34 4.5-3.74 4.25z" />
                </svg>
                Get on the App Store
                <svg
                  viewBox="0 0 24 24"
                  fill="none"
                  strokeWidth="2"
                  stroke="currentColor"
                  className="h-4 w-4 transition group-hover:translate-x-1"
                >
                  <path d="M5 12h14M13 5l7 7-7 7" strokeLinecap="round" strokeLinejoin="round" />
                </svg>
              </Link>
              <Link
                href="#demo"
                className="inline-flex items-center gap-2 rounded-full border px-6 py-3 text-base font-medium transition hover:bg-[color:var(--accent-tint)]"
                style={{
                  borderColor: "var(--border-strong)",
                  color: "var(--fg)",
                }}
              >
                Try the math
              </Link>
            </div>

            {/* Trust strip */}
            <div
              className="mt-10 grid grid-cols-2 gap-5 border-t pt-6 font-mono text-[11px] sm:grid-cols-4"
              style={{ borderColor: "var(--border)" }}
            >
              {[
                ["100%", "on-device"],
                ["0", "accounts"],
                ["3", "color-blind palettes"],
                ["1:1", "iOS math port"],
              ].map(([n, l]) => (
                <div key={l}>
                  <div
                    className="font-display text-2xl font-semibold tabular-nums"
                    style={{ color: "var(--accent-strong)" }}
                  >
                    {n}
                  </div>
                  <div
                    className="mt-1 uppercase tracking-[0.18em]"
                    style={{ color: "var(--fg-muted)" }}
                  >
                    {l}
                  </div>
                </div>
              ))}
            </div>
          </motion.div>

          {/* Phone column */}
          <motion.div
            initial={{ opacity: 0, scale: 0.92, y: 24 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            transition={{ duration: 0.9, delay: 0.15, ease: [0.22, 1, 0.36, 1] }}
            className="mx-auto w-full max-w-[340px] lg:mx-0"
          >
            <PhoneFrame>
              <PhantomCalcScreen />
            </PhoneFrame>
          </motion.div>
        </div>
      </div>
    </section>
  );
}
