"use client";

import Link from "next/link";
import { motion } from "framer-motion";

export function Hero() {
  return (
    <section className="section gradient-hero pt-32 pb-24 sm:pt-40 sm:pb-32">
      <div className="container-prose">
        <motion.div
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, ease: "easeOut" }}
        >
          <span className="eyebrow">Probability-first golf</span>
          <h1
            className="mt-3 max-w-4xl font-display text-display-sm font-semibold tracking-display-tight text-balance sm:text-display lg:text-display-lg"
            style={{ color: "var(--accent-strong)" }}
          >
            Hit the club{" "}
            <span style={{ color: "var(--accent)" }} className="italic">
              most likely
            </span>{" "}
            to land where you want it.
          </h1>
          <p className="surface-muted mt-6 max-w-2xl text-lg leading-relaxed">
            Dispersion models every club in your bag as a 2D probability
            distribution. Tell it your target. It tells you the club with
            the highest chance of getting there. The math is honest, the
            data stays on your phone, and the recommendation is always one
            tap away.
          </p>
          <div className="mt-10 flex flex-wrap items-center gap-4">
            <Link
              href="https://apps.apple.com/app/id000000000"
              className="inline-flex items-center gap-2 rounded-full px-6 py-3 text-base font-medium shadow-lg transition"
              style={{
                background: "var(--accent-strong)",
                color: "var(--bg)",
                boxShadow: "0 12px 32px -8px rgba(var(--shadow-rgb), 0.25)",
              }}
            >
              <svg viewBox="0 0 24 24" fill="currentColor" className="h-5 w-5">
                <path d="M17.05 20.28c-.98.95-2.05.8-3.08.35-1.09-.46-2.09-.48-3.24 0-1.44.62-2.2.44-3.06-.35C2.79 15.25 3.51 7.59 9.05 7.31c1.35.07 2.29.74 3.08.8 1.18-.24 2.31-.93 3.57-.84 1.51.12 2.65.72 3.4 1.8-3.12 1.87-2.38 5.98.48 7.13-.57 1.5-1.31 2.99-2.54 4.09zM12.03 7.25c-.15-2.23 1.66-4.07 3.74-4.25.29 2.58-2.34 4.5-3.74 4.25z" />
              </svg>
              Get on the App Store
            </Link>
            <Link
              href="#demo"
              className="inline-flex items-center gap-2 rounded-full border px-6 py-3 text-base font-medium transition"
              style={{
                borderColor: "var(--border-strong)",
                color: "var(--fg)",
              }}
            >
              Try the math
              <svg
                viewBox="0 0 24 24"
                fill="none"
                strokeWidth="2"
                stroke="currentColor"
                className="h-4 w-4"
              >
                <path
                  d="M5 12h14M13 5l7 7-7 7"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
              </svg>
            </Link>
          </div>
          <p className="surface-muted mt-6 font-mono text-xs uppercase tracking-widest">
            Local-first · iOS 18+
          </p>
        </motion.div>
      </div>
    </section>
  );
}
