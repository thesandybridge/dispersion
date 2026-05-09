import type { Metadata } from "next";
import Link from "next/link";
import { Header } from "@/components/Header";
import { Footer } from "@/components/Footer";
import { InteractiveDemo } from "@/components/InteractiveDemo";

export const metadata: Metadata = {
  title: "The math — sigma, gaussian bands, and the DECADE short-side bias",
  description:
    "Every shot is a 2D probability distribution. Dispersion integrates that distribution over your safe zone and ranks clubs by who lands in it. Here's the math, the assumptions, and why it matters.",
  alternates: { canonical: "/math" },
  openGraph: {
    title: "The math behind probability-first golf",
    description:
      "Sigma, gaussian band integration, and the DECADE short-side bias — explained without hand-waving.",
    url: "/math",
  },
};

export default function MathPage() {
  return (
    <main className="relative bg-canvas-50">
      <Header />

      {/* Hero */}
      <section className="section gradient-hero pt-32 pb-16 sm:pt-40 sm:pb-20">
        <div className="container-prose">
          <span className="eyebrow">The math</span>
          <h1 className="mt-3 max-w-4xl font-display text-display-sm font-semibold tracking-display-tight text-pine text-balance sm:text-display">
            Every shot is a distribution.{" "}
            <span className="italic text-fairway">Not a number.</span>
          </h1>
          <p className="mt-6 max-w-2xl text-lg leading-relaxed text-canvas-600">
            This page explains the actual algorithm Dispersion runs to pick a
            club. There's no hand-waving — the formulas are short, the
            assumptions are explicit, and the math is honest about what it
            doesn't know.
          </p>
        </div>
      </section>

      {/* TOC */}
      <section className="border-y border-canvas-200 bg-canvas-100 py-6">
        <div className="container-prose">
          <nav className="flex flex-wrap gap-x-6 gap-y-2 font-mono text-xs uppercase tracking-widest text-canvas-500">
            <a href="#sigma" className="transition hover:text-pine">σ — what it means</a>
            <a href="#bands" className="transition hover:text-pine">Gaussian band integration</a>
            <a href="#decade" className="transition hover:text-pine">DECADE short-side bias</a>
            <a href="#try" className="transition hover:text-pine">Try it</a>
            <a href="#caveats" className="transition hover:text-pine">What this doesn't model</a>
          </nav>
        </div>
      </section>

      {/* Long-form prose */}
      <article className="container-prose py-16 sm:py-20">
        <div className="prose prose-lg max-w-3xl">
          {/* Sigma */}
          <section id="sigma" className="mb-16">
            <h2 className="font-display text-display-xs font-semibold tracking-display-tight text-pine">
              σ — what it means
            </h2>
            <p className="mt-4 text-lg leading-relaxed text-canvas-700">
              Every club has two numbers that describe how predictable it is:{" "}
              <strong className="text-pine">σ↕ (sigma long)</strong>, the
              standard deviation of carry distance, and{" "}
              <strong className="text-pine">σ↔ (sigma lateral)</strong>, the
              standard deviation of left-right miss. These are not hit-or-miss
              ratings. They're the parameters of a normal distribution.
            </p>
            <p className="mt-4 text-lg leading-relaxed text-canvas-700">
              If your 7 iron has σ↕ = 6 yards, that means roughly 68% of your
              7 iron shots fall within ±6 yards of your average carry, and
              ~95% within ±12 yards. The math doesn't care whether you call
              that "good" or "bad" — it just integrates over the curve.
            </p>
            <div className="mt-6 rounded-2xl bg-canvas-100 p-6">
              <div className="font-mono text-xs uppercase tracking-widest text-canvas-500">
                Reasonable σ to start with
              </div>
              <ul className="mt-3 space-y-1 font-mono text-sm text-canvas-700">
                <li>Driver — σ↕ 8–14, σ↔ 12–18</li>
                <li>Mid iron — σ↕ 4–8, σ↔ 5–10</li>
                <li>Wedge — σ↕ 3–6, σ↔ 4–7</li>
              </ul>
              <p className="mt-3 text-sm text-canvas-500">
                These are educated guesses. The app's Range mode dials them in
                from your actual shots over time.
              </p>
            </div>
          </section>

          {/* Gaussian band */}
          <section id="bands" className="mb-16">
            <h2 className="font-display text-display-xs font-semibold tracking-display-tight text-pine">
              Gaussian band integration
            </h2>
            <p className="mt-4 text-lg leading-relaxed text-canvas-700">
              The probability your shot lands in a safe zone is a 2D
              integral. We model carry and lateral as independent normals,
              so the integrals separate:
            </p>
            <pre className="mt-6 overflow-x-auto rounded-2xl bg-pine p-6 font-mono text-sm leading-relaxed text-canvas-50">
{`P(in zone) =
  P(carry ∈ [target − depth/2, target + depth/2])
× P(lateral ∈ [aim − width/2, aim + width/2])`}
            </pre>
            <p className="mt-4 text-lg leading-relaxed text-canvas-700">
              Each term is just a difference of normal CDFs:{" "}
              <code className="rounded bg-canvas-100 px-1.5 py-0.5 font-mono text-base text-pine">
                Φ(z₂) − Φ(z₁)
              </code>
              {" "}where{" "}
              <code className="rounded bg-canvas-100 px-1.5 py-0.5 font-mono text-base text-pine">
                z = (bound − mean) / σ
              </code>
              . Standard probability — every stats textbook has this. The CDF
              uses the Abramowitz & Stegun rational approximation (max
              error ~7.5×10⁻⁸). Same in the iOS app and the demo below.
            </p>
          </section>

          {/* DECADE bias */}
          <section id="decade" className="mb-16">
            <h2 className="font-display text-display-xs font-semibold tracking-display-tight text-pine">
              DECADE short-side bias
            </h2>
            <p className="mt-4 text-lg leading-relaxed text-canvas-700">
              The raw probability isn't quite enough. Two clubs can have
              identical P(in zone) — say both 60% — but if one of them
              gets that 60% by being expected to land 5 yards short of the
              pin, while the other gets it by being right on number, you
              should take the second one every time. Coming up short is
              almost always worse than coming up long, especially around
              greens.
            </p>
            <p className="mt-4 text-lg leading-relaxed text-canvas-700">
              Following the DECADE methodology, we apply a multiplicative
              penalty when the club's expected carry is short of the target:
            </p>
            <pre className="mt-6 overflow-x-auto rounded-2xl bg-pine p-6 font-mono text-sm leading-relaxed text-canvas-50">
{`if expectedCarry < target:
  penalty = exp(−bias × shortness)
  P *= penalty`}
            </pre>
            <p className="mt-4 text-lg leading-relaxed text-canvas-700">
              With the default bias coefficient of 0.08, a club expected to
              come up 5 yards short loses about 25% of its raw score; 10
              yards short loses ~45%. The coefficient is tunable in
              Settings — players who really hate short-siding themselves
              can dial it up; players who think the bias is too aggressive
              can dial it down.
            </p>
          </section>

          {/* Demo */}
          <section id="try" className="mb-16">
            <h2 className="font-display text-display-xs font-semibold tracking-display-tight text-pine">
              Try it
            </h2>
            <p className="mt-4 text-lg leading-relaxed text-canvas-700">
              Below is the actual probability calc running on a sample mid-
              handicap bag. Drag the distance, switch the target type, watch
              which club leads.
            </p>
          </section>
        </div>
      </article>

      {/* Inline interactive demo */}
      <section className="bg-pine py-16 sm:py-20">
        <div className="container-prose">
          <InteractiveDemo />
        </div>
      </section>

      {/* Caveats */}
      <article className="container-prose py-16 sm:py-20">
        <div className="prose prose-lg max-w-3xl">
          <section id="caveats">
            <h2 className="font-display text-display-xs font-semibold tracking-display-tight text-pine">
              What this doesn't model
            </h2>
            <p className="mt-4 text-lg leading-relaxed text-canvas-700">
              Honesty section. The model assumes carry and lateral are
              independent — in reality they're weakly correlated for most
              players (fades tend to come up shorter than draws of the same
              clubhead speed). The lie multipliers, wind-per-mph, and
              elevation-per-foot rules are hand-tuned defaults you can
              override in Settings, but they're never going to be as
              accurate as a real ball-flight simulator. And we don't model
              spin, launch angle, or roll-out at all — only the carry
              landing point.
            </p>
            <p className="mt-4 text-lg leading-relaxed text-canvas-700">
              That said: an honest model with reasonable defaults beats no
              model. The point is to make the tradeoff between two clubs
              explicit. Whether you take the 7 iron or the 8 iron is a
              probability question, not a feel question.
            </p>
          </section>

          <section className="mt-16 border-t border-canvas-200 pt-10">
            <Link
              href="/"
              className="inline-flex items-center gap-2 text-base font-medium text-pine transition hover:text-fairway"
            >
              <svg viewBox="0 0 24 24" fill="none" strokeWidth="2" stroke="currentColor" className="h-4 w-4">
                <path d="M19 12H5M12 5l-7 7 7 7" strokeLinecap="round" strokeLinejoin="round" />
              </svg>
              Back to the app
            </Link>
          </section>
        </div>
      </article>

      <Footer />
    </main>
  );
}
