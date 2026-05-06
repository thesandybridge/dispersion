# Dispersion — agent handoff

This is a dual project. Two builds of the same golf shot-dispersion app.

- **`app/`** — the working Tauri + React + TypeScript reference build. Treat this as the spec.
- **`ios/`** — first-pass SwiftUI port for iOS 17+. Scaffolded, **never compiled**.
- **`_reference/`** — design handoff PDF/exports.

## Where the user left off

The iOS port was just scaffolded in three sessions on a Linux box (no Swift toolchain). Roughly **3,500 lines of Swift, zero compiles**. The first thing to do on Mac is generate the Xcode project, build, and fix what breaks. Expect 30–50 errors on first compile pass.

## Get the iOS project running

```bash
cd ios
brew install xcodegen   # one-time
xcodegen generate
open Dispersion.xcodeproj
```

Set a development team, hit ⌘R. ⌘U runs the test suite (uses Swift `Testing` framework — Xcode 16+).

## Get the Tauri reference running

```bash
cd app
pnpm install
pnpm dev          # vite dev server
pnpm tauri dev    # full Tauri shell
pnpm test         # vitest
pnpm build        # production bundle
```

`src/routeTree.gen.ts` is gitignored and regenerates on first build via the TanStack Router plugin.

## Tech stack

### Tauri build (`app/`)

- React 19 + TypeScript
- Tailwind CSS v4 with `@theme` tokens (no `tailwind.config.*`)
- shadcn-style primitives in `src/components/ui/` (Button, Sheet, Slider, ToggleGroup, Card, Badge, Switch, Dialog, Popover, Tooltip, ScrollArea, DropdownMenu, Label)
- Framer Motion for animation
- TanStack Router (file-based) + TanStack Query
- Zustand for stores (`src/lib/*Store.ts`)
- Drizzle ORM + tauri-plugin-sql (SQLite)
- oxlint for linting, vitest for tests

### iOS port (`ios/`)

- Swift 5.10, iOS 17+, iPad-capable
- Pure SwiftUI (no UIKit bridges, no third-party deps)
- SwiftData for persistence
- `@Observable` (Observation framework) for stores
- Canvas + Path for the SVG-equivalent visualizations
- CoreHaptics via `UIImpactFeedbackGenerator` helpers
- XcodeGen for project file (re-run after adding/renaming files)
- Swift `Testing` framework (`@Test` / `#expect`) — not XCTest

## Architecture map

```
ios/Dispersion/
├── App/                     entry + ModelContainer
├── Core/
│   ├── Models/              Plain value types (Club, Shot, Session, ShotScenario, ClubResult, ...)
│   ├── Math/                Pure functions ported from app/src/lib/*.
│   │                        These are the spec — keep in sync.
│   ├── Persistence/         SwiftData @Model classes + repositories.
│   │                        UI never touches SwiftData directly; it goes through repos.
│   └── Stores/              @Observable singletons (Settings, Scenario, Session, Dial)
├── DesignSystem/
│   ├── Theme.swift          Tokens (colors, radii, named hex helpers)
│   ├── Typography.swift     .eyebrow / .headline / .tabularNumbers modifiers
│   └── Components/          DButton, DBadge, DCard, DSheet, DSlider, DToggleGroup,
│                            DSwitch, DSeparator
├── Visualizations/          DispersionViz, ProbabilityDial, DispersionGlyph,
│                            RangeRadarField, BagGappingChart, CarryTickRule
├── Features/
│   ├── Calculator/          Anchor screen — full-bleed dispersion + hero distance
│   ├── Bag/                 Editorial hero + sorted club rows + insights + edit sheet
│   ├── Range/               Radar field + floating cards; actions in dial
│   ├── Settings/            Units / Data / Developer groups
│   └── Onboarding/          Single-screen — sample bag or DIY
└── Shell/
    ├── AppRoute.swift       The 4 routes
    ├── RadialDial.swift     Persistent FAB. Tap = action menu, drag = joystick nav
    └── RootShell.swift      TabView + RadialDial overlay + onboarding gate +
                             EmptyBagGuard
```

## Conventions to keep

- **4 spaces, never tabs.** Always semicolons in TS.
- **No emojis** in code, comments, or commits unless the user explicitly asks.
- **Conventional commits** (`feat:`, `fix:`, `chore:`, `docs:`, `build:`, `perf:`).
- **Never auto-commit, never auto-push.** Wait for explicit ask.
- **Never add `Co-Authored-By` to commits.**
- **No unnecessary comments / docstrings on obvious code.** Comment the *why*, not the *what*.
- **Avoid over-engineering.** Direct implementations over premature abstractions.
- **Match the Tauri build's design language.** Editorial hero numbers (Fraunces / serif design), tabular monospace eyebrows, restrained palette. The iOS port uses system serif as a Fraunces stand-in — if/when the team wants the real face, drop the .ttf into `ios/Dispersion/Resources/` and update `Typography.swift`.

## Likely first-compile failures (be ready)

I have not built this; these are educated guesses about what Xcode will complain about:

1. **`@State private var x = SomeStore.shared`** — SwiftUI's iOS 17 `@Observable` pattern can be finicky with singletons. If you see "Cannot use mutating member" or observation not firing, switch to:
   ```swift
   @Bindable var settings = SettingsStore.shared
   ```
   inside `body`, or thread the store through `@Environment` instead.

2. **`#Predicate` on `String == String`** in repos — generally fine, but `kindRaw == "range"` style comparisons can choke. Use the predicate macro form with explicit captured locals if needed.

3. **`try context.delete(model: ClubModel.self)`** — iOS 17+ shorthand for delete-all. Verify it's available.

4. **`ContentTransition.numericText(value:)`** — used in CalculatorScreen and RangeScreen. iOS 17 only; signature shifted across betas. If it complains, drop the `value:` and just use `.numericText`.

5. **`RangeRadarField` gesture composition** — uses both `TapGesture().sequenced(before: DragGesture)` and `.onTapGesture`. SwiftUI gesture composition is finicky. If taps don't register, delete the sequenced gesture and rely on `.onTapGesture { p in ... }` alone.

6. **Sheet detents clipping** — `.dispersionSheet` defaults to `[.medium, .large]`. Some content (zone sheet, edit sheet) is tall; medium will clip. Bump to `[.large]` per call.

7. **`Stepper` + `TextField` two-way binding** in `ClubEditSheet.NumberStepperField` — typing commits on every keystroke, which can cause re-render loops. If the keyboard feels jumpy, debounce.

8. **`Canvas` `ctx.draw(Text(...))`** — text styling inside Canvas is a subset of normal Text. If the σ labels in `RangeRadarField` look wrong or missing, that's why.

## What's deliberately deferred (TODO if user asks)

- **Calculator's Log shot action** is a TODO/no-op — needs a `QuickLogSheet` (port of the React `QuickLogSheet` with outcome tags + landing entry).
- **Range History tab** — only Live mode is built. The React version has a `/range#log` tab listing past sessions + a `SessionDetail` view.
- **Club detail view** — bag rows currently tap straight to the edit sheet; the React version has a separate detail view with shot history + face strikes + trend chart.
- **Bench / Bag tag sub-tabs** — bag screen only renders the main "Bag" pane.
- **Backup/restore JSON I/O** — Settings has Clear All and Seed but no export/import.
- **Trend charts** — could use Apple `Charts` framework when added.
- **Face strikes** — model + repo exist, no UI.
- **iPad-specific layouts** — basic adaptation only. No `NavigationSplitView`, no two-pane treatments. Easy wins on Bag (list + detail split).
- **App icon, launch screen, fonts, asset catalog** — all empty/default.

## Cross-references

- The pure math layer in `ios/Dispersion/Core/Math/` and `app/src/lib/` is supposed to stay in sync. If you fix a bug in one, fix it in the other.
- `ios/Dispersion/Core/Math/` files cite their TS counterparts in their headers — useful for diff'ing behaviour.
- The probability/sigma tests in `ios/DispersionTests/` use values I sanity-checked but did not cross-validate against the JS implementation. Worth running both side-by-side once the iOS app builds.

## When iterating

- Compile errors are likely the first 2-3 turns. Paste them in batches; fix lowest-level (Core) before higher-level (Features).
- Then run on simulator and hit each screen. The radial dial joystick is the highest-risk interaction — if it feels wrong, the constants to tweak live in `RadialDial.swift` (`radius`, `routeSlot`, `routeTrigger`).
- The Tauri build is always the visual-truth reference. Run it side-by-side (`pnpm tauri dev`) when polishing the iOS UI.
