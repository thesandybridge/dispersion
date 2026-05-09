// Wraps content in the standard Header / hero shell / Footer used across
// non-landing pages. Variants for "long-form prose" and "feature walkthrough"
// share the same outer chrome.

import type { ReactNode } from "react";
import { Header } from "./Header";
import { Footer } from "./Footer";

interface PageLayoutProps {
  eyebrow: string;
  title: ReactNode;
  lede?: ReactNode;
  children: ReactNode;
}

export function PageLayout({ eyebrow, title, lede, children }: PageLayoutProps) {
  return (
    <main className="relative surface-bg">
      <Header />

      <section className="section gradient-hero pt-32 pb-16 sm:pt-40 sm:pb-20">
        <div className="container-prose">
          <span className="eyebrow">{eyebrow}</span>
          <h1
            className="mt-3 max-w-4xl font-display text-display-sm font-semibold tracking-display-tight text-balance sm:text-display"
            style={{ color: "var(--accent-strong)" }}
          >
            {title}
          </h1>
          {lede && (
            <p className="surface-muted mt-6 max-w-2xl text-lg leading-relaxed">
              {lede}
            </p>
          )}
        </div>
      </section>

      {children}

      <Footer />
    </main>
  );
}
