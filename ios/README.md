# Dispersion (iOS)

Native SwiftUI port of the Tauri/React app in `../app`. Targets iOS 17+ (iPhone & iPad).

## First-time setup

```bash
brew install xcodegen
cd ios
xcodegen generate
open Dispersion.xcodeproj
```

Re-run `xcodegen generate` whenever you add, rename, or move Swift files. XcodeGen rewrites the project file from `project.yml` and the on-disk source tree.

## Architecture

```
Dispersion/
├── App/                    DispersionApp.swift, app entry
├── Core/
│   ├── Models/             Plain value types (Club, Shot, Session, ...)
│   ├── Math/               Pure functions ported 1:1 from app/src/lib/*
│   ├── Persistence/        SwiftData schema + repositories
│   └── Stores/             @Observable state holders (Settings, Scenario, Session, Dial)
├── DesignSystem/           Theme, typography, primitive components
├── Visualizations/         Canvas-based equivalents of the SVG components
├── Features/               One folder per screen
│   ├── Calculator/
│   ├── Bag/
│   ├── Range/
│   ├── Settings/
│   └── Onboarding/
├── Shell/                  Root tab view, persistent RadialDial, route plumbing
└── Resources/              Assets, fonts, app icon
```

## Tech choices

- **iOS 17+** to use the `Observation` framework (`@Observable`), modern SwiftUI animations, Inspector modifier (iPad), and refined `ScrollView` APIs.
- **SwiftData** for local persistence (replaces drizzle + sqlite in the Tauri build).
- **Pure SwiftUI** — no UIKit bridges, no third-party UI deps, no Storyboards.
- **Canvas + Path** for the DispersionViz/RangeRadar/BagGapping equivalents (the original was SVG; SwiftUI Canvas is the natural translation).
- **Charts** (Apple's framework) for trend lines and gapping charts where it fits; bespoke Canvas where it doesn't.
- **CoreHaptics** for the radial dial / drag feedback.

## Status

| Layer            | Status                                                                            |
| ---------------- | --------------------------------------------------------------------------------- |
| Project skeleton | Done                                                                              |
| Core models      | Done                                                                              |
| Math layer       | Done — probability, sigma, units, insights, club category, presets, outcomes      |
| Persistence      | Done — SwiftData schema + repositories                                            |
| Stores           | Done — Settings, Scenario, Session, Dial                                          |
| Design tokens    | Done — colors, type, radii                                                        |
| Components       | Done — DButton, DBadge, DCard, DSheet, DSlider, DToggleGroup, DSwitch, DSeparator |
| Visualizations   | Done — DispersionViz, ProbabilityDial, DispersionGlyph, RangeRadarField, BagGappingChart, CarryTickRule |
| Calculator       | Done — full-bleed dispersion, hero distance, recommended dial, alts rail, zone sheet |
| Bag              | Done — editorial hero, sorted club rows, insights, edit/create sheet              |
| Range            | Done — radar field, floating cards, dial-driven actions, switch/target sheets    |
| Settings         | Done — units, data ops, dev tools                                                 |
| Onboarding       | Done (lean) — single-screen, sample-bag or build-yourself paths                   |
| Root shell       | Done — TabView + persistent RadialDial overlay + EmptyBagGuard                    |

## Reference

The original implementation lives in `../app/src/`. When in doubt, that's authoritative. Math and probability ports include line-level comments pointing at the source file.
