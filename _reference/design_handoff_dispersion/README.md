# Handoff: Dispersion — probability-first golf club selector

## Overview

**Dispersion** is a personal-use, local-first golf club selection tool for serious amateurs. The app holds a player's club bag with per-club dispersion stats (carry σ + lateral σ), and given a target distance and a "safe zone" geometry, ranks clubs by the probability the shot lands inside that zone — using the DECADE-style, statistics-driven approach.

Three tightly coupled loops feed each other:
1. **Range mode** — practice at Golf Galaxy: tap-log every shot, σ rebuilds live, save the session as the new club default.
2. **Calculator** — enter distance + zone, see the recommended club + ranked alternates with a heat-map polygon over the zone.
3. **On-course logging** — quick-log outcome (in zone / short / long / left / right / penalty) per shot. Premium tier brings real course geometry, GPS, and per-shot landing-spot tracking.

Data is local-only (localStorage), exportable/importable as JSON. No accounts, no backend in v1.

## About the Design Files

The files in this bundle are **design references created in HTML** — high-fidelity prototypes showing intended look, layout, copy, and interaction. They are **not production code to copy directly**.

The user's actual stack is already specified:

- **Vite + React + TypeScript (latest)**
- **Tailwind CSS**
- **localStorage** for persistence
- **Vitest** for tests
- **Zustand** if state needs to be lifted; otherwise local component state
- 4-space indent, semicolons in JS/TS
- No comments unless explicitly requested
- React functional components + hooks only
- Idiomatic, maintainable code — no quick-and-dirty

Recreate the HTML designs in that target environment.

## Fidelity

**High-fidelity.** Final colors, typography, spacing, copy, and interactions. Lift exact hex codes, font stacks, and copy strings from the HTML mocks and from the **Design Tokens** section below. Probability numbers shown in the mocks are illustrative — the real probability function is in the math spec.

## Build phases

The user explicitly requested phased delivery. Stop at the end of each phase for review.

### Phase 1 — Scaffold + types + math + tests (TODAY)

Set up Vite + React + TS + Tailwind + Vitest. Implement:

- `src/types.ts` — exact shapes from the **Data Model** section.
- `src/math/probability.ts` — `phi(z)` (normal CDF via erf approximation) and `probabilityInZone(club, scenario)`.
- `src/math/probability.test.ts` — Vitest cases listed in **Test Spec**.

**Show test output before touching UI.** Do not build past Phase 1 in this session.

### Phase 2 — Clubs page

CRUD over the bag. Validate σ > 0. Persist via Zustand + localStorage adapter.

### Phase 3 — Calculator page

Distance input + zone editor + ranked club list, dispersion heat-map viz.

### Phase 4 — Settings, export/import, onboarding, polish

JSON export/import, theme switcher (light/dark/course), 4-step onboarding for empty bag, Range mode and on-course shot logging.

(Premium course-API features are post-v1 — see the Premium screen mock for direction, but it does not ship in v1.)

## Data model (lift verbatim into types.ts)

```typescript
type Club = {
    id: string;
    name: string;
    carryYards: number;
    carrySd: number;       // standard deviation in distance, yards
    lateralSd: number;     // standard deviation lateral, yards
};

type Zone = {
    // Centered on the target. Positive depth = past the target. Positive width = right of target line.
    widthYards: number;
    depthYards: number;
    offsetLong: number;    // shift along target line, default 0
    offsetLat: number;     // shift lateral, default 0
};

type ShotScenario = {
    distanceToTargetYards: number;
    safeZone: Zone;
    penaltyZones: Zone[];  // stub for v1, used in v2 for expected-value math
};

type ClubResult = {
    clubId: string;
    probabilityInZone: number;  // 0 to 1
    expectedDistance: number;   // for display
};

type Shot = {
    id: string;
    timestamp: number;
    clubId: string;
    targetDistanceYards: number;
    // landing relative to expected: +long = past, +lat = right
    longDelta: number;
    latDelta: number;
    sessionId: string;
    outcome?: 'in' | 'short' | 'long' | 'left' | 'right' | 'penalty';
};

type Session = {
    id: string;
    timestamp: number;
    kind: 'range' | 'round';
    label: string;
};
```

## Math spec

For a given club + scenario:

1. Expected landing relative to tee: `(carryYards, 0)` in (long, lat).
2. Target position: `(distanceToTargetYards, 0)`.
3. Safe zone in absolute coords:
   - long range: `[distanceToTarget + offsetLong - depthYards/2, distanceToTarget + offsetLong + depthYards/2]`
   - lat range: `[offsetLat - widthYards/2, offsetLat + widthYards/2]`
4. Shot landing distribution (independent normals):
   - `X_long ~ N(carryYards, carrySd²)`
   - `X_lat  ~ N(0, lateralSd²)`
5. **P(in zone)** =
   `(Φ((longMax − carry)/carrySd) − Φ((longMin − carry)/carrySd))`
   `× (Φ((latMax)/lateralSd) − Φ((latMin)/lateralSd))`

Where `Φ(x) = 0.5 · (1 + erf(x / √2))`.

Implement `erf` via the Abramowitz & Stegun 7.1.26 polynomial approximation. **No stats library** — keep dependency-light.

```ts
function erf(x: number): number {
    const sign = x < 0 ? -1 : 1;
    const ax = Math.abs(x);
    const t = 1 / (1 + 0.3275911 * ax);
    const y = 1 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t * Math.exp(-ax * ax);
    return sign * y;
}
function phi(z: number): number {
    return 0.5 * (1 + erf(z / Math.SQRT2));
}
```

## Test spec (Vitest, before any UI)

1. **Tighter dispersion wins on small zones.** Two clubs, same carry. `clubA.carrySd < clubB.carrySd`, same lateralSd. Small zone centered on target == carry → `pA > pB`.
2. **Tighter dispersion loses on huge zones.** Same setup but with a `1000y × 1000y` zone → `pA < pB` (the bigger spread captures more of the zone the same way).
3. **Centered + huge zone → 1.** carry = target, zone of `10000 × 10000` → `p ≈ 1` (within 1e-6).
4. **Far-shifted zone → 0.** Zone offset 200 yards from expected landing, modest dimensions → `p < 1e-6`.
5. **Lateral sign-flip invariance.** `offsetLat = +d` and `offsetLat = -d` produce the same probability (lateral distribution is symmetric around 0).
6. **Hand-computed sanity case.** User will provide one. Reserve a `it.todo` slot.

## Screens / Views

All screens use the design tokens at the bottom. Mobile is the primary form factor; desktop adds breathing room and a side-by-side viz/list layout.

### 1. Onboarding (4 steps, mobile-first, full-bleed dark)

- Background: `--clr-ink` (`#0e1a13`) with a low-poly **TopoBg** decoration at ~50% opacity behind content.
- Top: 4-segment progress strip, completed segments `--clr-bentgrass` (`#62b375`), pending `rgba(246,241,225,0.12)`, `3px` tall, `6px` gap.
- Body uses `--display-font` for big headings (Fraunces, 32–44px, weight 400, letter-spacing -0.02em) and `--ui-font` (Inter, 13–14px) for body.
- Accent eyebrow: `10–11px` uppercase, letter-spacing `0.22–0.24em`, color `#62b375`, prefixed with `◆`.
- Bottom: "Continue" button (`#62b375` bg, `#0a1410` text, 14px weight 600, 14px padding, 10px radius), with a Back button when step > 1.

Steps:
1. **Hello** — "Hit the club most likely to land where you want it." Subhead explains the value prop.
2. **Math primer** — "Every shot is a distribution. Not a number." Embeds a `<DispersionViz width=260 height=220>` showing carry=150, σ↕=8, σ↔=6.
3. **First club** — "Start with your 7 iron." Single big number (168) over a range slider (`accentColor: #62b375`). One control only — keep friction minimal.
4. **Ready** — "Your bag is local. Your data is yours." Bullet list of feature promises (local-first, JSON export, themes). CTA flips to "Open the bag".

### 2. Calculator (mobile + desktop)

The marquee screen. **The dispersion heat-map is full-bleed background** — the polygon IS the figure, not a chart inside a card.

- **Background**: `<DispersionViz>` filling the whole viewport. Critical detail: the polygon must scale **uniformly** — its aspect ratio is set by `carrySd / lateralSd` only. Letterbox the polygon inside the canvas; do not stretch to fit. (Earlier iteration had `preserveAspectRatio="none"` + non-uniform scale — that was wrong; mobile and desktop must show the same shape.)
- **Top scrim**: linear gradient `rgba(10,20,16,0.85) → 0` over the top 200px so header stays readable.
- **Bottom scrim**: linear gradient `rgba(10,20,16,0.92) → 0` over the bottom 55%.
- **Header (over scrim)**:
  - Eyebrow row: "Hole 7 · Par 4" + wind chip (`Wind` icon · `6mph NE`), 11px uppercase, 0.16em tracking, `rgba(246,241,225,0.55)`.
  - Distance: `64px` (mobile) / `88px` (desktop) Fraunces, weight 400, `-0.03em` tracking, tabular-nums. Suffix "YDS" at 0.34em scale, `rgba(246,241,225,0.5)`.
  - Right: zone chip — glass card (`rgba(246,241,225,0.06)` + `backdrop-filter: blur(12px)` + `1px solid rgba(246,241,225,0.12)`, `10px` radius), shows zone name + "28w × 30d" in mono.
- **Recommendation card** (bottom-stacked glass): bigger glass blur, shows club name (Fraunces 42–52px) + probability (Fraunces 38–50px, color `#a9d18e`, suffix `%` at 0.5em & 0.7 opacity), with a stats row `EXP {carry}y · σ↕ {n} · σ↔ {n}` in mono.
- **Alts strip** (below recommendation): 4-col grid `24px 1fr auto auto`: rank `01`-zero-padded mono, club name + inline `"{carry}y · σ {n}×{n}"`, mini bar (44×4 with `lbl.color` fill), prob in Fraunces. Up to 4 alts on mobile, 6 on desktop, scroll if more.
- **Action row**: "Zone" secondary glass button + "Log shot · {recommended.name}" primary `#62b375` button with a circled `+` glyph.
- **Mobile only**: bottom tab bar (Calc / Clubs / Range / Settings).

### 3. Clubs (list + edit)

- Background: `--clr-fairway-50` (`#f4efe3`), text `--clr-soil-900` (`#1a2419`).
- **List view**: Each row is a 3-col grid `1fr auto auto` — name + σ↕/σ↔ subline (mono), a `<DispersionGlyph>` 44×28 inline SVG (faceted oval, `#62b375` 25% fill + `#2c8a5e` stroke + center dot), and the carry yardage in big Fraunces (24px). Header has "Add club" pill button (filled soil-900 bg, fairway-50 text) and "13 clubs · sorted by carry" eyebrow.
- **Edit view**: Top "Live preview" card — dark `#0e1a13` rounded-14 panel hosting a 140×170 `<DispersionViz>` next to live carry/σ readout. Form fields are 4 stacked `<Field>` rows: Name, Carry distance (yards), Distance σ (with hint "~68% of shots land within ±σ"), Lateral σ. Inputs are white cards `1px solid rgba(26,36,25,0.12)`, `10px` radius, the value typeset in Fraunces 16px tabular-nums. Bottom: dark "Save changes" full-width primary + outlined red "Delete" secondary.

### 4. Range mode (the practice loop)

- Dark background `#0a1410`. Header eyebrow shows a pulsing `#a9d18e` dot + "Range mode · live" + venue label "Bay 12 · Golf Galaxy" in mono.
- Title row: club name in Fraunces 32px + "Switch club" button.
- **Tap-grid** (`<RangeTapGrid>`): a `360×420` (mobile) target-centered SVG. Concentric ellipses for distance rings (5/10/15/20/25/30y), dashed cross axes, then the **live faceted dispersion polygon** built from the running σ at 4 contour levels. Logged shots are `r=3.5` cream dots with dark stroke; the most recent shot has a 9px dashed pulse ring. A faint dashed cursor hint at `(2, -3)` invites the next tap. Yard labels at axis edges in mono.
- **Stats strip**: 4-col grid — Avg carry, σ↕ (with delta vs. saved), σ↔ (with delta), 68% box `{2σ × 2σ}` in mono. "Save to club ◆" link button on the right of the eyebrow.

### 5. Shot log (history)

- Light theme. Top counter "203 shots · last 30 days" in big Fraunces.
- **Per-club summary row**: horizontally scrolling cards, each `min-width: 110px`, white bg, 10px radius. Per card: club name + total shots (mono), `<SigmaSparkline>` showing σ trending down over 8 sessions (1.4px stroke `#2c8a5e`, filled area `#62b375` 12% opacity), σ value + delta (`↓0.3` in green).
- **Sessions list**: 3-col grid `4px 1fr auto`: colored accent bar (range = `#a9d18e`, round = `#e6c068`), label + "{date} · {n} shots · {n} clubs" mono subline, chevron.

### 6. Settings

- Light theme. Header "Preferences" in Fraunces 28.
- Sectioned settings groups (white cards, 12px radius, 1px border `rgba(26,36,25,0.08)`), each preceded by a 10px uppercase eyebrow:
  - **Theme**: 3-up grid of mini theme swatches (light / dark / course-active), aspect 1.4, currently-active gets a `1.5px solid #62b375` ring.
  - **Units**: rows for Distance (Yards), Wind (mph).
  - **Data**: Export JSON, Import JSON, **Clear all data** (red text — `#a23939`).
  - **Developer**: Show debug overlay (toggle), Seed sample bag, Open math notebook.
- Footer: build info in mono, gray, centered (`Dispersion v1.0.0 · local-only build / sha 4a8c91d · stored in localStorage`).

### 7. On-course (Premium tier)

- Dark background. Header: green pulse dot + "Live · GPS locked" + "Pebble Hills · Hole 7" in Fraunces. Right: "Par 4 · 438y · HCP 5" in mono.
- **Hole map**: top-down stylized SVG. Tee at bottom, green at top. Fairway is a single coarse polygon `#3a6b3e` outlined `#2c4f30`; rough is `#1f3324` with a 35°-rotated topo pattern overlay. Bunkers are sand polygons `#e8d8a0` outlined `#c8b878`. Water hazard polygon `#1f3a5f` with a `~` glyph. Trees as dark green dots of varying radii. Green is a radial-gradient ellipse with concentric contour rings.
- **Recommended dispersion polygon** drawn over the green at the pin location, 5 nested faceted ellipses screen-blended (palette: pine → rough → fairway-shadow → bentgrass → sage).
- **Shot path**: dashed line connecting past shot dots. Each shot is a cream dot with a translucent halo + label in mono.
- **Top-right GPS chip**: glass blur card, "To pin" eyebrow, distance in Fraunces 36, F/C/B yardages in mono row.
- **Top-left**: Premium badge — pill `rgba(232,93,77,0.18)` bg, `#e85d4d` text + border, "◆ Premium" in 10px uppercase 0.18em tracking.
- **Bottom strip**: club + probability + "Avoid bunker R · Account for 6mph crosswind L→R · Adj +4y" hint, "See alts" + "Log shot · 7 Iron" buttons.

### 8. Premium upgrade prompt

- Dark, with topo decoration at `rgba(232,93,77,0.18)` (flag-color theme to differentiate from main app green).
- Eyebrow pill "◆ Dispersion Premium". Big Fraunces hero: "Bring your *course* into the math." (the *course* italic gets `#e85d4d` color).
- 4 feature rows with red bullet dots: 40k+ courses, Per-shot landing tracking, Wind & elevation adjusted, Round summary & strokes-gained.
- Pricing card: $6/mo Fraunces 32, "or $48/yr" in mono. "14-day free trial · cancel anytime" subline.
- CTA button `#e85d4d` bg, `#0a1410` text.
- Footer reaffirmation: "Free tier — your bag, your math, forever local. Always." (the moat — local-first stays free *forever*).

## Interactions & behavior

- **Tap-log at range**: tap on the dispersion grid → push a shot at `(latYards, longDelta)`, recompute σ↕ and σ↔ live, redraw polygon. "Save to club" overwrites the club's stored σ values (after a confirm).
- **Quick-log on course**: tap "Log shot · {club}" → bottom sheet slides up with 6 outcome buttons (In zone / Short / Long / Left / Right / Penalty) in a 3-col grid. Tapping any outcome creates a Shot record and dismisses the sheet. Optional: tap exact landing on the dispersion grid for precise delta tracking.
- **Calculator recompute**: any change to distance, zone width/depth, or zone offsets recomputes all `ClubResult`s and reorders the alts list. Use a memoized selector so this is cheap.
- **Theme switch**: applies CSS custom properties at the `:root` level. Persist to localStorage. Default is `course` (dark green).
- **Form validation**: Club edit — `carrySd > 0` and `lateralSd > 0`, `carryYards > 0`. Inline error text below the field, no toast.
- **Onboarding**: gated by "has at least one club." First launch with empty bag triggers it; user can skip from any step (skip = creates an empty bag and routes to Clubs).
- **Premium gate**: Course mode entry-point shows the upgrade screen for free users; entitled users skip straight to the live hole view. v1 stubs entitlement to `false`.

## State management

- **Zustand** for the bag, sessions, shots, and settings (theme, units, premium-entitled flag).
- **Local component state** for form inputs, modal open/close, scenario inputs in the Calculator.
- **localStorage adapter** with a versioned key (`dispersion:v1:bag`, etc.) and a single migration entry-point for future schema changes.
- **No data fetching** in v1. Premium tier (post-v1) will introduce a course-API client.

## Design Tokens (drop into Tailwind config / tokens.css)

### Color

```css
:root {
    /* Course palette */
    --clr-fairway-50: #f4efe3;
    --clr-bentgrass:  #62b375;
    --clr-fairway-shadow: #2c8a5e;
    --clr-rough: #16624a;
    --clr-pine:  #0b3d2e;
    --clr-soil-900: #1a2419;
    --clr-sand:  #f0e7b8;
    --clr-flag:  #e85d4d;
    --clr-water: #1f3a5f;
    --clr-ink:   #0e1a13;
    --clr-cream: #f6f1e1;

    /* Heat-map ramp (low → high probability density) */
    --heat-0: #0b3d2e;  /* pine */
    --heat-1: #16624a;
    --heat-2: #2c8a5e;
    --heat-3: #62b375;
    --heat-4: #a9d18e;
    --heat-5: #f0e7b8;  /* sand highlight */

    /* Status / probability labels */
    --p-strong:    #62b375;  /* ≥ 0.6 STRONGLY FAVORED */
    --p-favored:   #a9d18e;  /* ≥ 0.4 FAVORED */
    --p-marginal:  #e6c068;  /* ≥ 0.2 MARGINAL */
    --p-poor:      #c87060;  /* < 0.2 POOR */

    --danger:      #a23939;
}
```

Light theme inverts ink ↔ fairway-50. Course (default) keeps ink as bg.

### Type

```css
:root {
    --display-font: "Fraunces", ui-serif, Georgia, serif;
    --ui-font:      "Inter", system-ui, -apple-system, "Segoe UI", sans-serif;
    --mono-font:    "JetBrains Mono", ui-monospace, "SF Mono", monospace;
}
```

- Display: 22 / 28 / 32 / 44 / 56 / 64 / 88 px, weight 400 (occasionally 500), `letter-spacing: -0.02em` (-0.03em at 64+).
- UI body: 13 / 14 / 15 px, weight 400 / 500 / 600.
- Eyebrows: 10 / 11 px, weight 500–600, `letter-spacing: 0.16–0.24em`, `text-transform: uppercase`.
- Mono: 10 / 11 / 12 px for stats, deltas, system labels. **Always tabular-nums on numbers** (`font-feature-settings: "tnum"`).

### Spacing & radii

- Spacing scale: 4 / 6 / 8 / 10 / 12 / 14 / 18 / 22 / 28 px.
- Radii: 8 (buttons), 10 (inputs), 12 (cards), 14 (hero cards), 16 (recommendation), 28 (mobile artboard frames).
- Hit targets: ≥44px on mobile.

### Shadows / elevation

- Card on light: `0 0 0 1px rgba(0,0,0,0.06), 0 8px 30px rgba(0,0,0,0.06)`.
- Glass on dark: `background: rgba(246,241,225,0.06–0.07); backdrop-filter: blur(12–16px); border: 1px solid rgba(246,241,225,0.10–0.14)`.

## Components to extract

| Component | Notes |
|---|---|
| `<DispersionViz>` | Pure SVG. Props: `carry`, `carrySd`, `lateralSd`, `distanceToTarget`, `zoneWidth/Depth`, `palette[]`, `contours`, `facets`. **Uniform scale only** — never stretch. |
| `<DispersionGlyph>` | Tiny 44×28 inline SVG for club lists. |
| `<RangeTapGrid>` | Target-centered SVG that handles tap → record shot. |
| `<HoleMap>` | Premium course view. SVG-driven from course-API geometry. |
| `<ClubRow>` | Used in alts list + clubs list. |
| `<ZoneEditor>` | Width / depth sliders + presets row. |
| `<ProbabilityBadge>` | Maps prob → STRONGLY FAVORED / FAVORED / MARGINAL / POOR + color. |
| `<ThemePicker>` | 3-up theme swatch grid. |
| `<BottomTabs>` | Mobile-only nav. |

## Assets

No raster assets. All visuals are CSS + inline SVG. Two webfonts to load:

- **Fraunces** (400, 500) via Google Fonts
- **Inter** (400, 500, 600) via Google Fonts
- **JetBrains Mono** (400, 500) via Google Fonts (or fall back to system mono)

## Files in this bundle

- `Dispersion.html` — entry document, wires all React components into a `<DesignCanvas>` for side-by-side comparison.
- `dispersion-viz.jsx` — the heat-map polygon viz.
- `topo-bg.jsx` — low-poly topographic background + icon set.
- `mock-data.jsx` — sample bag + zone presets + probability-label helper.
- `screen-calc.jsx` — Calculator screen (full-bleed heat-map, glass cards, quick-log sheet).
- `screen-clubs.jsx` — Clubs list + edit form.
- `screen-misc.jsx` — Onboarding (4 steps) + Settings.
- `screen-range.jsx` — Range mode tap-grid + Shot log history.
- `screen-course.jsx` — Premium on-course hole view + upgrade prompt.
- `handoff-cards.jsx` — Token/type/math/anatomy/phases reference cards.
- `design-canvas.jsx`, `tweaks-panel.jsx` — supporting components for the design surface (not part of the app).

Recreate the screens in the React + TS + Tailwind target. Reference the JSX for layout, copy, and exact values; do not import the JSX into the production app.

## Stop points

- After Phase 1 (math + tests). Show `vitest` output. Do not start UI.
- After Phase 2 (Clubs page). Show empty + populated + edit states.
- After Phase 3 (Calculator). Show with seeded bag.
- After Phase 4 (Settings + onboarding + range/log). Final review.
