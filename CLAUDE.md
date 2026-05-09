# Dispersion

Probability-first golf shot dispersion + club recommendation, with an
iOS app and a marketing site.

- **`ios/`** — the SwiftUI app (iOS 18+, iPhone + iPad).
- **`web/`** — Next.js marketing/SEO site with a live TS port of the
  iOS probability math. Deploys to Vercel as `dispersion.app`.

## Get the iOS project running

```bash
cd ios
brew install xcodegen   # one-time
xcodegen generate
open Dispersion.xcodeproj
```

## Get the web project running

```bash
cd web
npm install
npm run dev
```

The web project's `lib/dispersion/` is a 1:1 TS port of the iOS math
(`Probability.swift` + `Sigma.swift`). When the iOS math changes the TS
port must follow so the marketing demo matches reality.

Set a development team, hit Cmd+R. Cmd+U runs the test suite (Swift `Testing` framework).

## Tech stack

- Swift 5.10, iOS 18+, iPad-capable
- Pure SwiftUI (no UIKit bridges, no third-party deps)
- SwiftData for persistence
- `@Observable` (Observation framework) for stores
- Canvas + Path for visualizations
- RealityKit + RealityView for 3D bag tag
- CoreHaptics via `UIImpactFeedbackGenerator`
- XcodeGen for project file (re-run after adding/renaming files)
- Swift `Testing` framework for tests

## Architecture

```
ios/Dispersion/
  App/                       Entry + ModelContainer
  Core/
    Models/                  Plain value types (Club, Shot, Session, SwingType, etc.)
    Math/                    Probability, sigma, insights, backup, shot stats, presets
    Persistence/             SwiftData @Model classes + repositories
    Stores/                  @Observable singletons (Settings, Scenario, Session, Profile, Dial)
  DesignSystem/
    Theme.swift              Tokens, themed card fill, accent environment
    Typography.swift         Font modifiers
    Components/              DButton, DBadge, DCard, DSheet, DSlider, DToggleGroup, DSwitch, DConfirmDialog
  Visualizations/            DispersionViz, ProbabilityDial, TrendChart, ClubFaceViz, BagGappingChart, etc.
  Features/
    Calculator/              Full-bleed dispersion + recommended club + swing type variants
    Bag/                     Club list, detail view, edit sheet, gapping chart, bag tag
    Range/                   Live radar, shot log history, session detail, manual entry
    Settings/                Units, theme accent, backup/restore, debug overlay
    Onboarding/              4-step wizard (hello, math primer, first club, ready)
  Shell/
    RootShell.swift          TabView + RadialDial overlay + onboarding gate
    RadialDial.swift         Persistent FAB — tap for actions, drag for navigation
    DebugOverlay.swift       Live state inspector
  Resources/                 App icon, asset catalog
```

## Conventions

- **4 spaces, never tabs.**
- **Conventional commits** (`feat:`, `fix:`, `chore:`, `docs:`, `build:`, `perf:`).
- **Never auto-commit, never auto-push.** Wait for explicit ask.
- **No unnecessary comments / docstrings on obvious code.** Comment the *why*, not the *what*.
- **Avoid over-engineering.** Direct implementations over premature abstractions.
- **Theme accent flows via `@Environment(\.themeAccent)`** — set at root, read anywhere.
- **Sheets use `.dispersionSheet` modifier** — frosted glass, drag indicator, `DSheetContainer` layout.
- **DECADE bias in probability** — zone evaluation shifts toward short side to favor "take more club."

