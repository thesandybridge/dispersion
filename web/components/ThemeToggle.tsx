"use client";

// Three-state toggle: System / Light / Dark. Picks up the OS preference
// when set to System. Persisted by next-themes via localStorage.

import { useEffect, useState } from "react";
import { useTheme } from "next-themes";

const OPTIONS = [
  {
    value: "system",
    label: "System",
    icon: (
      <svg viewBox="0 0 24 24" fill="none" className="h-3.5 w-3.5">
        <circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="1.6" />
        <path d="M12 3v18" stroke="currentColor" strokeWidth="1.6" />
      </svg>
    ),
  },
  {
    value: "light",
    label: "Light",
    icon: (
      <svg viewBox="0 0 24 24" fill="none" className="h-3.5 w-3.5">
        <circle cx="12" cy="12" r="4" stroke="currentColor" strokeWidth="1.6" />
        <path
          d="M12 2v2M12 20v2M2 12h2M20 12h2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41"
          stroke="currentColor"
          strokeWidth="1.6"
          strokeLinecap="round"
        />
      </svg>
    ),
  },
  {
    value: "dark",
    label: "Dark",
    icon: (
      <svg viewBox="0 0 24 24" fill="none" className="h-3.5 w-3.5">
        <path
          d="M21 13.4A8.5 8.5 0 1110.6 3a7 7 0 0010.4 10.4z"
          stroke="currentColor"
          strokeWidth="1.6"
          strokeLinejoin="round"
        />
      </svg>
    ),
  },
] as const;

export function ThemeToggle({
  className = "",
  compact = false,
}: {
  className?: string;
  compact?: boolean;
}) {
  const { theme, setTheme, resolvedTheme } = useTheme();
  const [mounted, setMounted] = useState(false);

  // next-themes only knows what to render after the first mount (SSR can't
  // know the user's preference). Render a stable placeholder until then to
  // avoid hydration mismatches.
  useEffect(() => setMounted(true), []);

  if (!mounted) {
    return (
      <div
        className={
          "h-7 w-[120px] rounded-full bg-[color:var(--bg-elevated)]/50 " +
          className
        }
        aria-hidden
      />
    );
  }

  // Compact = single icon button cycling system → light → dark.
  if (compact) {
    const next =
      theme === "system" ? "light" : theme === "light" ? "dark" : "system";
    const icon =
      OPTIONS.find((o) => o.value === (theme ?? "system"))?.icon ??
      OPTIONS[0].icon;
    return (
      <button
        type="button"
        onClick={() => setTheme(next)}
        className={
          "grid h-9 w-9 place-items-center rounded-full border border-[color:var(--border)] " +
          "text-[color:var(--fg-soft)] transition hover:text-[color:var(--accent-strong)] " +
          className
        }
        aria-label={`Theme: ${theme ?? "system"} (resolved: ${resolvedTheme}). Tap to change.`}
      >
        {icon}
      </button>
    );
  }

  // Full segmented control.
  return (
    <div
      role="radiogroup"
      aria-label="Color theme"
      className={
        "inline-flex items-center rounded-full border border-[color:var(--border)] " +
        "bg-[color:var(--bg-elevated)] p-0.5 " +
        className
      }
    >
      {OPTIONS.map((opt) => {
        const isActive = (theme ?? "system") === opt.value;
        return (
          <button
            key={opt.value}
            type="button"
            role="radio"
            aria-checked={isActive}
            onClick={() => setTheme(opt.value)}
            className={
              "inline-flex items-center gap-1.5 rounded-full px-3 py-1 text-xs font-medium transition " +
              (isActive
                ? "bg-[color:var(--accent-strong)] text-[color:var(--bg)]"
                : "text-[color:var(--fg-muted)] hover:text-[color:var(--fg)]")
            }
            aria-label={opt.label}
          >
            <span aria-hidden>{opt.icon}</span>
            <span>{opt.label}</span>
          </button>
        );
      })}
    </div>
  );
}
