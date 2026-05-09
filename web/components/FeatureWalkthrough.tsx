// Reusable two-column walkthrough section. Left column = prose
// (eyebrow/heading/body/optional bullets); right column = an illustrative
// visual passed in. Used by /range and /course-builder so each feature
// step shares the same shape.

import type { ReactNode } from "react";

interface WalkthroughStep {
  eyebrow?: string;
  title: string;
  body: ReactNode;
  bullets?: string[];
  visual: ReactNode;
  /// "left" places the visual on the left, prose on the right (default
  /// alternates by even/odd index when used in a list — let the parent
  /// pass this in).
  reverse?: boolean;
}

export function FeatureWalkthroughList({ steps }: { steps: WalkthroughStep[] }) {
  return (
    <div className="space-y-24">
      {steps.map((step, i) => (
        <Walkthrough key={i} {...step} reverse={i % 2 === 1} />
      ))}
    </div>
  );
}

export function Walkthrough(step: WalkthroughStep) {
  const proseFirst = !step.reverse;
  return (
    <section className="grid grid-cols-1 items-center gap-10 lg:grid-cols-2 lg:gap-20">
      <div className={"space-y-4 " + (proseFirst ? "lg:order-1" : "lg:order-2")}>
        {step.eyebrow && <span className="eyebrow">{step.eyebrow}</span>}
        <h2
          className="font-display text-display-xs font-semibold tracking-display-tight"
          style={{ color: "var(--accent-strong)" }}
        >
          {step.title}
        </h2>
        <div className="surface-soft text-lg leading-relaxed">{step.body}</div>
        {step.bullets && (
          <ul className="surface-muted mt-4 space-y-2 text-base">
            {step.bullets.map((b) => (
              <li key={b} className="flex gap-3">
                <span
                  className="mt-2 inline-block h-1 w-1 flex-shrink-0 rounded-full"
                  style={{ background: "var(--accent)" }}
                  aria-hidden
                />
                <span>{b}</span>
              </li>
            ))}
          </ul>
        )}
      </div>
      <div className={proseFirst ? "lg:order-2" : "lg:order-1"}>
        {step.visual}
      </div>
    </section>
  );
}
