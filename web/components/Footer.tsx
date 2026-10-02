import Link from "next/link";
import { BrandMark } from "./BrandMark";
import { ThemeToggle } from "./ThemeToggle";

export function Footer() {
  return (
    <footer
      className="border-t"
      style={{ borderColor: "var(--border)", background: "var(--bg-elevated)" }}
    >
      <div className="container-prose flex flex-col items-start justify-between gap-6 py-12 md:flex-row md:items-center">
        <div>
          <div className="flex items-center gap-2">
            <BrandMark className="h-11 w-11 text-[color:var(--accent-strong)]" />
            <span
              className="font-display text-base font-semibold tracking-tight"
              style={{ color: "var(--accent-strong)" }}
            >
              Dispersion
            </span>
          </div>
          <p className="surface-muted mt-2 max-w-md text-sm">
            Your bag is local. Your data is yours. No accounts, no cloud, no
            telemetry.
          </p>
        </div>
        <div className="flex flex-col items-start gap-4 md:items-end">
          <nav className="flex flex-wrap items-center gap-x-6 gap-y-2 text-sm surface-muted">
            <Link href="/math" className="transition hover:text-[color:var(--accent-strong)]">The math</Link>
            <Link href="/range" className="transition hover:text-[color:var(--accent-strong)]">Range</Link>
            <Link href="/putter" className="transition hover:text-[color:var(--accent-strong)]">Putter</Link>
            <Link href="/course-builder" className="transition hover:text-[color:var(--accent-strong)]">Course builder</Link>
            <Link href="/privacy" className="transition hover:text-[color:var(--accent-strong)]">Privacy</Link>
          </nav>
          <ThemeToggle />
        </div>
      </div>
    </footer>
  );
}
