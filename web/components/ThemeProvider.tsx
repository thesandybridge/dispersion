"use client";

import { ThemeProvider as NextThemesProvider } from "next-themes";
import type { ReactNode } from "react";

/// SSR-safe wrapper around next-themes. `attribute="class"` adds a
/// `class="dark"` (or `"light"`) to the <html> element which our Tailwind
/// `darkMode: 'class'` and CSS variables both read from. `defaultTheme`
/// is "system" so we honour prefers-color-scheme on first load.
export function ThemeProvider({ children }: { children: ReactNode }) {
  return (
    <NextThemesProvider
      attribute="class"
      defaultTheme="system"
      enableSystem
      disableTransitionOnChange
    >
      {children}
    </NextThemesProvider>
  );
}
