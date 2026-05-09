# Dispersion — marketing site

Next.js 15 marketing/SEO site for the [Dispersion iOS app](../ios). Live
interactive demo of the probability calc, long-form math explainer, and
App Store CTA.

## Stack

- Next.js 15 App Router · React 19
- Tailwind CSS 3.4 (custom palette in `tailwind.config.ts`)
- Framer Motion for entrance + transition animations
- TypeScript end-to-end
- TS port of the iOS dispersion math under `lib/dispersion/`

## Getting started

```bash
cd web
npm install
npm run dev
```

Then open http://localhost:3000.

## Scripts

- `dev` — Next.js dev server with hot reload
- `build` — production build
- `start` — production server (run after `build`)
- `lint` — ESLint
- `typecheck` — `tsc --noEmit`

## Project layout

```
web/
├── app/
│   ├── layout.tsx          ← root layout, fonts, JSON-LD, metadata
│   ├── page.tsx            ← landing
│   ├── math/page.tsx       ← long-form math explainer + inline demo
│   ├── opengraph-image.tsx ← auto-generated OG image
│   ├── sitemap.ts
│   ├── robots.ts
│   └── globals.css
├── components/
│   ├── Header.tsx
│   ├── Footer.tsx
│   ├── Hero.tsx
│   ├── FeatureGrid.tsx
│   ├── DemoSection.tsx
│   ├── CallToAction.tsx
│   ├── DispersionCanvas.tsx ← Canvas port of iOS DispersionViz
│   └── InteractiveDemo.tsx  ← live probability demo
├── lib/dispersion/         ← TS port of Probability + Sigma + sample bag
└── tailwind.config.ts      ← marketing palette + display type scale
```

## Deployment

Designed for **Vercel** (zero-config). Set the `dispersion.app` domain in
the Vercel dashboard and add a CNAME at the registrar.

The `apps.apple.com` link in `Header.tsx`, `Hero.tsx`, and
`CallToAction.tsx` currently points at a placeholder
(`apps.apple.com/app/id000000000`) — replace once the app has a real App
Store listing.

## Math port — keep it in sync

`lib/dispersion/probability.ts` and `lib/dispersion/sigma.ts` are 1:1
ports of the same-named Swift files in `ios/Dispersion/Core/Math/`.
When the iOS math changes (e.g., the DECADE bias coefficient default,
new probability curves), the TS port must follow so the marketing demo
matches reality.
