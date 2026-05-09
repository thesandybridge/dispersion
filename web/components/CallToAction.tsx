import Link from "next/link";

export function CallToAction() {
  return (
    <section className="section bg-canvas-50 py-24 sm:py-32">
      <div className="container-prose">
        <div className="overflow-hidden rounded-3xl bg-pine px-8 py-16 text-canvas-50 shadow-xl shadow-pine/20 sm:px-16 sm:py-20">
          <div className="max-w-2xl">
            <span className="eyebrow text-bentgrass">Stop guessing</span>
            <h2 className="mt-3 font-display text-display-xs font-semibold tracking-display-tight sm:text-display-sm">
              Take the shot the math says is most likely.
            </h2>
            <p className="mt-4 text-lg leading-relaxed text-canvas-200">
              Free on the App Store. iOS 18+. No accounts. Local-first.
              Built by someone who couldn't find an honest probability tool
              and got tired of waiting.
            </p>
            <div className="mt-8 flex flex-wrap gap-4">
              <Link
                href="https://apps.apple.com/app/id000000000"
                className="inline-flex items-center gap-2 rounded-full bg-bentgrass px-6 py-3 text-base font-semibold text-pine transition hover:bg-canvas-50"
              >
                <svg viewBox="0 0 24 24" fill="currentColor" className="h-5 w-5">
                  <path d="M17.05 20.28c-.98.95-2.05.8-3.08.35-1.09-.46-2.09-.48-3.24 0-1.44.62-2.2.44-3.06-.35C2.79 15.25 3.51 7.59 9.05 7.31c1.35.07 2.29.74 3.08.8 1.18-.24 2.31-.93 3.57-.84 1.51.12 2.65.72 3.4 1.8-3.12 1.87-2.38 5.98.48 7.13-.57 1.5-1.31 2.99-2.54 4.09zM12.03 7.25c-.15-2.23 1.66-4.07 3.74-4.25.29 2.58-2.34 4.5-3.74 4.25z" />
                </svg>
                Get on the App Store
              </Link>
              <Link
                href="/math"
                className="inline-flex items-center gap-2 rounded-full border border-canvas-50/30 px-6 py-3 text-base font-medium text-canvas-50 transition hover:border-canvas-50 hover:bg-canvas-50/5"
              >
                Read the math first
              </Link>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
