import Link from "next/link";
import { ThemeToggle } from "./ThemeToggle";

export function Header() {
  return (
    <header className="absolute inset-x-0 top-0 z-20 py-6">
      <div className="container-prose flex items-center justify-between">
        <Link href="/" className="flex items-center gap-2.5">
          <span
            className="grid h-8 w-8 place-items-center rounded-full"
            style={{ background: "var(--accent-strong)", color: "var(--bg)" }}
          >
            <svg
              viewBox="0 0 24 24"
              fill="none"
              className="h-4 w-4"
              aria-hidden="true"
            >
              <circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="2" />
              <circle cx="12" cy="12" r="4" stroke="currentColor" strokeWidth="2" />
              <circle cx="12" cy="12" r="1" fill="currentColor" />
            </svg>
          </span>
          <span
            className="font-display text-lg font-semibold tracking-tight"
            style={{ color: "var(--accent-strong)" }}
          >
            Dispersion
          </span>
        </Link>
        <nav className="hidden items-center gap-6 text-sm sm:flex">
          <Link
            href="/#how"
            className="surface-soft transition hover:text-[color:var(--accent-strong)]"
          >
            How it works
          </Link>
          <Link
            href="/math"
            className="surface-soft transition hover:text-[color:var(--accent-strong)]"
          >
            The math
          </Link>
          <ThemeToggle compact />
          <Link
            href="https://apps.apple.com/app/id000000000"
            className="rounded-full px-4 py-1.5 font-medium transition"
            style={{ background: "var(--accent-strong)", color: "var(--bg)" }}
          >
            Get the app
          </Link>
        </nav>
        <div className="sm:hidden">
          <ThemeToggle compact />
        </div>
      </div>
    </header>
  );
}
