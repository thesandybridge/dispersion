import type { Config } from "tailwindcss";

// Marketing-first palette: lighter and glossier than the iOS app, but with
// the same brand DNA. The "fairway" greens are pulled directly from
// DesignTokens.swift (bentgrass, fairwayShadow, pine) so the visual link
// reads. The "neutrals" are warmer than pure gray to keep the agronomic feel.

const config: Config = {
  content: [
    "./app/**/*.{ts,tsx}",
    "./components/**/*.{ts,tsx}",
    "./lib/**/*.{ts,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        // App brand greens — kept identical to iOS DesignTokens
        bentgrass: "#62b375",
        fairway: "#2c8a5e",
        pine: "#0b3d2e",
        rough: "#16624a",
        ink: "#0e1a13",
        sand: "#f0e7b8",
        flag: "#e85d4d",
        cream: "#f6f1e1",
        // Marketing neutrals (warm)
        canvas: {
          50: "#fbfaf6",
          100: "#f4f2eb",
          200: "#e8e4dc",
          300: "#cfcabc",
          400: "#9c9683",
          500: "#6a6555",
          600: "#4a4639",
          700: "#2d2a22",
        },
      },
      fontFamily: {
        display: [
          "var(--font-display)",
          "ui-serif",
          "Georgia",
          "serif",
        ],
        sans: [
          "var(--font-sans)",
          "ui-sans-serif",
          "system-ui",
          "-apple-system",
          "Segoe UI",
          "Roboto",
          "sans-serif",
        ],
        mono: [
          "ui-monospace",
          "SFMono-Regular",
          "Menlo",
          "monospace",
        ],
      },
      letterSpacing: {
        "display-tight": "-0.04em",
      },
      fontSize: {
        // Editorial display scale
        "display-xs": ["2rem", { lineHeight: "1.05", letterSpacing: "-0.02em" }],
        "display-sm": ["2.75rem", { lineHeight: "1.05", letterSpacing: "-0.025em" }],
        "display": ["3.75rem", { lineHeight: "1.02", letterSpacing: "-0.03em" }],
        "display-lg": ["5rem", { lineHeight: "1.0", letterSpacing: "-0.035em" }],
        "display-xl": ["6.5rem", { lineHeight: "0.98", letterSpacing: "-0.04em" }],
      },
      animation: {
        "shimmer": "shimmer 8s ease-in-out infinite",
        "drift": "drift 30s linear infinite",
      },
      keyframes: {
        shimmer: {
          "0%, 100%": { transform: "translate(0, 0) scale(1)", opacity: "0.5" },
          "50%": { transform: "translate(-2%, -2%) scale(1.05)", opacity: "0.7" },
        },
        drift: {
          "0%": { transform: "translateY(0)" },
          "100%": { transform: "translateY(-100%)" },
        },
      },
    },
  },
  plugins: [],
};

export default config;
