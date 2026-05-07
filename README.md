# Dispersion

A probability-first golf club selector for iOS. You teach it your dispersion, it does the math.

## Quick start

```bash
cd ios
brew install xcodegen   # one-time
xcodegen generate
open Dispersion.xcodeproj
```

Set a development team in **Signing & Capabilities**, pick your device, hit **⌘R**.

## Architecture

```
ios/                         SwiftUI app (iOS 17+)
  Dispersion/
    App/                     Entry point + ModelContainer
    Core/
      Models/                Value types (Club, Shot, Session, etc.)
      Math/                  Probability, sigma, insights, backup
      Persistence/           SwiftData @Model classes + repositories
      Stores/                @Observable singletons (Settings, Scenario, Session, Profile)
    DesignSystem/            Theme tokens, typography, reusable components
    Visualizations/          DispersionViz, TrendChart, ClubFaceViz, etc.
    Features/
      Calculator/            Main screen — dispersion + club recommendation
      Bag/                   Club management, detail, gapping, bag tag
      Range/                 Shot logging, radar field, session history
      Settings/              Preferences, backup/restore, theme
      Onboarding/            4-step wizard
    Shell/                   TabView, RadialDial, DebugOverlay
    Resources/               App icon, asset catalog
  DispersionTests/           Swift Testing framework tests
  project.yml                XcodeGen spec
_reference/tauri-app/        Original React + Tauri reference build (math spec)
```

## Tech stack

- Swift 5.10, iOS 17+, pure SwiftUI
- SwiftData for persistence
- `@Observable` for state management
- Canvas + Path for visualizations
- XcodeGen for project generation
- Swift Testing framework for tests

## Reference build

The original React/Tauri app lives in `_reference/tauri-app/`. It's the design spec and math reference. The iOS port is the production target.
