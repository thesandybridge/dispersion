# Dispersion

iOS-native golf shot dispersion and club recommendation app.

- **`ios/`** — the SwiftUI app (iOS 17+, iPhone + iPad). This is the production build.
- **`_reference/tauri-app/`** — the original React + Tauri reference build. Math and design spec.
- **`_reference/`** — design handoff materials.

## Get the iOS project running

```bash
cd ios
brew install xcodegen   # one-time
xcodegen generate
open Dispersion.xcodeproj
```

Set a development team, hit Cmd+R. Cmd+U runs the test suite (Swift `Testing` framework).

## Tech stack

- Swift 5.10, iOS 17+, iPad-capable
- Pure SwiftUI (no UIKit bridges, no third-party deps)
- SwiftData for persistence
- `@Observable` (Observation framework) for stores
- Canvas + Path for visualizations
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

## Cross-references

- The pure math layer in `ios/Dispersion/Core/Math/` was ported from `_reference/tauri-app/src/lib/`.
- `ios/Dispersion/Core/Math/` files cite their TS counterparts in their headers.
