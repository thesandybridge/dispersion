import Link from "next/link";

export function Footer() {
  return (
    <footer className="border-t border-canvas-200 bg-canvas-100">
      <div className="container-prose flex flex-col items-start justify-between gap-6 py-12 md:flex-row md:items-center">
        <div>
          <div className="flex items-center gap-2">
            <span className="grid h-7 w-7 place-items-center rounded-full bg-pine text-canvas-50">
              <svg viewBox="0 0 24 24" fill="none" className="h-3.5 w-3.5">
                <circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="2" />
                <circle cx="12" cy="12" r="4" stroke="currentColor" strokeWidth="2" />
                <circle cx="12" cy="12" r="1" fill="currentColor" />
              </svg>
            </span>
            <span className="font-display text-base font-semibold tracking-tight text-pine">
              Dispersion
            </span>
          </div>
          <p className="mt-2 max-w-md text-sm text-canvas-500">
            Your bag is local. Your data is yours. No accounts, no cloud, no
            telemetry.
          </p>
        </div>
        <nav className="flex flex-wrap items-center gap-x-6 gap-y-2 text-sm text-canvas-500">
          <Link href="/math" className="transition hover:text-pine">The math</Link>
          <Link href="/privacy" className="transition hover:text-pine">Privacy</Link>
          <Link
            href="https://github.com/thesandybridge/dispersion"
            className="transition hover:text-pine"
          >
            Source
          </Link>
        </nav>
      </div>
    </footer>
  );
}
