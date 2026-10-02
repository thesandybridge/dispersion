import Link from "next/link";
import { BrandMark } from "./BrandMark";
import { ThemeToggle } from "./ThemeToggle";

export function Header() {
  return (
    <header className="absolute inset-x-0 top-0 z-20 py-6">
      <div className="container-prose flex items-center justify-between">
        <Link href="/" className="flex items-center gap-2.5">
          <BrandMark className="h-11 w-11 text-[color:var(--accent-strong)]" />
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
