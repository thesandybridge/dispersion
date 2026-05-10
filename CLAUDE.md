# Dispersion

Probability-first golf shot dispersion + club recommendation, with an
iOS app and a marketing site.

- **`ios/`** — the SwiftUI app (iOS 18+, iPhone + iPad).
- **`web/`** — Next.js marketing/SEO site with a live TS port of the
  iOS probability math. Deploys to Vercel as `dispersion.app`.

## Get the iOS project running

```bash
cd ios
brew install xcodegen        # one-time
xcodegen generate            # re-run after adding/renaming files
open Dispersion.xcodeproj
```

Set a development team, hit Cmd+R. Cmd+U runs the test suite (Swift `Testing` framework).

## Get the web project running

```bash
cd web
npm install
npm run dev
```

The web project's `lib/dispersion/` is a 1:1 TS port of the iOS math
(`Probability.swift` + `Sigma.swift`). When the iOS math changes the TS
port must follow so the marketing demo matches reality.

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
- ImageMagick (`brew install imagemagick`) for the app icon build script

Web stack: Next.js 15.1 App Router, React 19, TypeScript 5.7, Tailwind
3.4, Framer Motion 11, next-themes. No third-party UI kit — every
component is custom in `web/components/`.

## Architecture

```
ios/Dispersion/
  App/
    DispersionApp.swift        Entry point + ModelContainer + one-time legacy putter wipe
    SplashScreen.swift         Cold-launch animated splash
  Core/
    Models/
      Models.swift             Club, Shot, Session, SwingType, ShotOutcomeTag, FaceStrike
      CourseModels.swift       Course, Hole, TeeBox, Polygon, Round, RoundShot
      Putter.swift             Putter, Putt, PutterHeadType, PuttContext, PutterStats
    Math/                      Probability, Sigma, Insights, ShotStats, MissPattern,
                               StrokesGained, Outcomes, Presets, AppConfig, Backup,
                               LieAndConditions, ClubCategory, ClubPreferences, Units
    Persistence/
      Schema.swift             ClubModel, SessionModel, ShotModel, FaceStrikeModel
      CourseSchema.swift       CourseModel, PolygonModel, CourseShotModel, HoleInfoModel, RoundModel
      PutterSchema.swift       PutterModel, PuttModel
      ClubsRepo / SessionsRepo / ShotsRepo / FaceStrikesRepo / CoursesRepo / PuttersRepo / PuttsRepo
      Validation.swift         Shared ValidationError type
    Stores/                    @Observable singletons
      SettingsStore            Units, theme accent, palette mode, appearance
      AppIconStore             Alternate icon picker (pine / sand / sunset / slate)
      ScenarioStore            Calculator scenario (target, conditions, lie, pin)
      SessionStore             Active session (range or round)
      ProfileStore             User profile (handicap, grip type, tee preference)
      DialStore                RadialDial registered actions
      LieMultiplierStore       User-tunable lie σ multipliers
      CalculatorTuningStore    Wind/elevation/bias coefficients
      CustomPaletteStore       User-custom theme palette
  DesignSystem/
    Theme.swift                DesignTokens (adaptive light/dark), ThemedCardFill, themeAccent env
    Typography.swift           DispersionType (display / ui / mono fonts)
    Palette.swift              Color-blind safe palettes (standard / redGreenSafe / blueYellowSafe)
    Components/                DButton, DBadge, DCard, DSheet, DSlider, DToggleGroup, DSwitch,
                               DConfirmDialog, DInlineError, DSeparator, FloatingPill, NumericField,
                               ShareSheet
  Visualizations/              DispersionViz (calculator), RangeRadarField (range live),
                               PuttingGreenField (linear putt lane), ProbabilityDial, TrendChart,
                               ClubFaceViz, BagGappingChart, DispersionGlyph, HoleMapView,
                               CarryTickRule
  Features/
    Calculator/                Full-bleed dispersion + recommended club + lateral aim + conditions
    Bag/
      BagScreen + heroCard + clubRow
      ClubDetailView / ClubEditSheet
      PutterDetailView / PutterEditSheet         (separate domain — no carry/σ leakage)
      BagTagView / BagTagMesh                    3D RealityKit tag
      BagStats                                   Aggregate bag analytics
    Range/
      RangeScreen                                Tab container (Live / Putt / History)
      LiveRangeView                              Inside RangeScreen, the live radar mode
      PutterRangeView                            Linear putting lane practice mode
      ShotLogView                                History tab — sessions list + per-club perf
      SessionDetailView / SessionInsights*       Per-session breakdown
      AddShotSheet / CalibrationSheet            Manual entry + save measured σ
      ScorecardView
    Course/
      CourseScreen / CourseSearchSheet           Course browser
      MapBuilderView                             Trace tees, pins, polygons over satellite
      CoursePlayView                             Live round tracking
      RoundHistoryView / RoundSummaryView / RoundScorecardView / RoundTracker
      ScorecardEditorSheet
      MapAutoFill                                Apple place-recognition flood fill
    Settings/
      SettingsScreen                             Units, theme, app icon picker, lie multipliers,
                                                 palette mode (incl. custom), conditions tuning,
                                                 outlier threshold, backup/import, dev overlay
    Help/
      HelpScreen / HelpTopicView / HelpContent   In-app guided tutorials
    Onboarding/
      OnboardingScreen                           4-step wizard (hello, math primer, theme, ready)
  Shell/
    RootShell.swift            TabView + RadialDial overlay + onboarding gate
    RadialDial.swift           Persistent FAB — tap for actions, drag for navigation
    DebugOverlay.swift         Live state inspector (7-tap activator on Settings)
  Resources/
    Assets.xcassets/
      AppIcon.appiconset       Pine (primary) — light / dark / tinted variants
      AppIcon-Sand.appiconset  Alternate
      AppIcon-Sunset.appiconset
      AppIcon-Slate.appiconset
      IconPreview-*.imageset   180x180 thumbnails for the in-app icon picker
      LaunchBackground.colorset
    AppIconSource/
      build_icon.sh            ImageMagick draw-command pipeline for all 4 palettes ×
                               3 luminosity variants × preview imagesets
```

```
web/
  app/
    layout.tsx                 Root layout, fonts, ThemeProvider, NoiseTexture overlay
    page.tsx                   Hero → Marquee → Bento → HowItWorks → Demo → CTA → Footer
    math/                      Long-form probability explainer page
    range/                     Range mode marketing page
    putter/                    Putter mode marketing page
    course-builder/            Course builder marketing page
    privacy/                   Privacy policy
    opengraph-image.tsx        Edge-rendered OG image
    sitemap.ts / robots.ts
  components/
    Header / Footer            Site chrome
    Hero                       Parallax split layout — copy + phone with PhantomCalcScreen
    PhoneFrame / PhantomCalcScreen   Pure-CSS iOS chrome + faux calc screen
    LiveDispersionBackdrop     Continuously animating dispersion contours (Canvas)
    BentoGrid                  Asymmetric feature mosaic with mini-interactive cards
    HowItWorks                 3-step animated flow with vertical accent rule
    DemoSection                Dark pine surface with InteractiveDemo
    InteractiveDemo            Live probability demo (drag to set distance, see ranking)
    DispersionCanvas           HTML Canvas port of DispersionViz
    MarqueeStrip               Slow-scrolling clubs + σ marquee
    CallToAction               Final CTA with topo-pattern gradient card
    FeatureWalkthrough         Two-column step layout used by /range, /putter, /course-builder
    PageLayout                 Header + hero + content + footer wrapper for non-landing pages
    Patterns                   TopoPattern (sin-wave contours), DotPattern, HatchPattern
    NoiseTexture               Site-wide grain overlay
    CountUp                    Scroll-triggered animated number
    ThemeToggle / ThemeProvider   System / light / dark
  lib/
    dispersion/                1:1 TS port of Probability.swift + Sigma.swift + helpers
```

## Putter is a separate domain

The putter does **not** live on the `Club` model. It has its own value
type (`Putter`), its own SwiftData class (`PutterModel`), its own repo
(`PuttersRepo`), and its own practice surface (`PutterRangeView` →
`PuttingGreenField`). Individual putts are `Putt` / `PuttModel`, not
`Shot`. Putter sessions use a local-only sessionId, not `SessionStore`.

When working on putter-related code, do not touch the Club domain — and
do not extend the Club domain to "support" putters. They were
deliberately split.

## App icons

Four palettes (Pine, Sand, Sunset, Slate), each with three appearance
variants (light, dark, tinted) for iOS 18 Home Screen customization.
All assets come out of `Resources/AppIconSource/build_icon.sh` —
ImageMagick draws the icon via gradient + heat ellipses + pin glyph,
then writes it directly into `Assets.xcassets`.

`project.yml` registers alternates via
`ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`. Runtime switching is
handled by `AppIconStore` calling `UIApplication.setAlternateIconName`.

## Conventions

- **4 spaces, never tabs.**
- **Conventional commits** (`feat:`, `fix:`, `chore:`, `docs:`, `build:`, `perf:`).
- **Never auto-commit, never auto-push.** Wait for explicit ask.
- **No unnecessary comments / docstrings on obvious code.** Comment the
  *why*, not the *what*.
- **Avoid over-engineering.** Direct implementations over premature
  abstractions.
- **Theme accent flows via `@Environment(\.themeAccent)`** — set at
  root, read anywhere.
- **Color-blind palette flows via `@Environment(\.palette)`** — read by
  any view that paints status-significant color (probability labels,
  contour heat, score deltas).
- **Sheets use `.dispersionSheet` modifier** — frosted glass, drag
  indicator, `DSheetContainer` layout.
- **Float-on-map UI uses `.floatingPillStyle()` capsules** — discrete
  pill clusters (course editor, range toolbar). Not a single big card
  with buttons inside.
- **Numeric input uses `NumericField`**, not
  `TextField(value:format:)`. The latter parses + reformats per
  keystroke and is perceptibly laggy in card-heavy sheets.
- **DECADE bias in probability** — zone evaluation shifts toward short
  side to favor "take more club."
- **iOS 18 dark/tinted icons** — every shipped icon set must include
  light, dark, and tinted variants so Home Screen customization works.
- **Putter ≠ Club.** Don't bridge them; don't share storage; don't
  reuse the Club edit sheet for putters.
