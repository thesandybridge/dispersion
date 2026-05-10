"use client";

// Three-step "how it works" flow. Side-by-side numbered steps with a
// vertical accent rule that animates in on scroll. Designed to anchor
// the messaging between the bento grid and the live demo.

import { motion } from "framer-motion";

const STEPS = [
  {
    n: "01",
    title: "Build your bag",
    body:
      "Start from a sample bag or add clubs one at a time. Each club gets a carry distance and the σ values that define its dispersion. You can ballpark them to start — calibration tightens them as you log shots.",
  },
  {
    n: "02",
    title: "Calibrate at the range",
    body:
      "Tap to log every shot. The radar shows where the ball landed; σ↕ and σ↔ update live. Save calibration once the sample passes the confidence threshold — never before.",
  },
  {
    n: "03",
    title: "Get the recommendation",
    body:
      "On the calculator: set distance, pin, and conditions. The app integrates each club's dispersion over the safe zone and ranks them. The probability you'll land where you want, in numbers.",
  },
];

export function HowItWorks() {
  return (
    <section
      className="section py-24 sm:py-32"
      style={{ background: "var(--bg-elevated)" }}
    >
      <div className="container-prose">
        <div className="grid grid-cols-1 gap-12 lg:grid-cols-[1fr_2fr] lg:gap-20">
          <div>
            <motion.div
              initial={{ opacity: 0, y: 16 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, amount: 0.4 }}
              transition={{ duration: 0.6 }}
            >
              <span
                className="font-mono text-[10px] uppercase tracking-[0.18em]"
                style={{ color: "var(--accent)" }}
              >
                How it works
              </span>
              <h2
                className="mt-3 font-display text-display-xs font-semibold tracking-display-tight sm:text-display-sm"
                style={{ color: "var(--accent-strong)" }}
              >
                Three steps. No magic.
              </h2>
              <p
                className="mt-4 text-lg leading-relaxed"
                style={{ color: "var(--fg-soft)" }}
              >
                Build your bag, calibrate at the range, then let the math
                pick the club. The whole loop is local — nothing leaves
                your phone.
              </p>
            </motion.div>
          </div>

          <ol className="relative space-y-12">
            {/* Vertical rule that grows in on scroll */}
            <motion.span
              aria-hidden
              initial={{ scaleY: 0 }}
              whileInView={{ scaleY: 1 }}
              viewport={{ once: true, amount: 0.3 }}
              transition={{ duration: 1.0, ease: [0.22, 1, 0.36, 1] }}
              className="absolute left-[36px] top-2 bottom-2 w-px origin-top"
              style={{ background: "var(--accent)" }}
            />

            {STEPS.map((s, i) => (
              <motion.li
                key={s.n}
                initial={{ opacity: 0, x: 14 }}
                whileInView={{ opacity: 1, x: 0 }}
                viewport={{ once: true, amount: 0.3 }}
                transition={{
                  duration: 0.6,
                  delay: 0.1 * i,
                  ease: [0.22, 1, 0.36, 1],
                }}
                className="relative flex gap-6"
              >
                <span
                  className="relative z-10 grid h-[72px] w-[72px] flex-shrink-0 place-items-center rounded-full font-mono text-base font-medium tracking-wider"
                  style={{
                    background: "var(--bg)",
                    boxShadow: "0 0 0 1px var(--accent)",
                    color: "var(--accent-strong)",
                  }}
                >
                  {s.n}
                </span>
                <div className="pt-2">
                  <h3
                    className="font-display text-2xl font-semibold tracking-tight sm:text-3xl"
                    style={{ color: "var(--accent-strong)" }}
                  >
                    {s.title}
                  </h3>
                  <p
                    className="mt-3 max-w-xl text-base leading-relaxed"
                    style={{ color: "var(--fg-soft)" }}
                  >
                    {s.body}
                  </p>
                </div>
              </motion.li>
            ))}
          </ol>
        </div>
      </div>
    </section>
  );
}
