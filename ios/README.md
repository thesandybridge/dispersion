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


## Apple Watch companion

The `DispersionWatch` target requires watchOS 11+. Install the watchOS platform
in Xcode Settings → Components, then run the iPhone app and its companion on a
paired iPhone and Watch. Both targets must use the same development team.

1. Start or resume a round in Course on iPhone. Set a mapped pin and add your clubs.
2. Open Dispersion on Watch for distance to that pin, using the Watch's current GPS.
3. At your ball, choose the club and tap **Mark shot**. The next mark finishes the
   previous shot and begins the next one.
4. Tap **Reached green** at your ball to finish the approach. After putting, tap
   **Finish hole**, confirm total strokes (including putts and penalties), and save.
   The phone saves the score and advances the hole; the last hole saves the round.
5. Sync all saved shots before finishing or discarding the round on iPhone.

Unfinished marks and completed shots survive Watch app restarts. Completed shots
remain queued until the phone acknowledges their IDs; retries do not duplicate
shots. Change the marked club on Watch before completing the shot. Further corrections
and undo remain available in Course on iPhone. An unfinished
mark can be cancelled on Watch without deleting completed shots.

Watch GPS distances are stored as `CourseShot` records. They do not update carry
calibration or the existing approximate strokes-gained aggregates. Club suggestions
use nearest carry distance, not a hazard-aware strategy model. Location is sampled
while the Watch app is active; marking requires a fix no older than 3 seconds
with reported accuracy of 15 meters or better. A mark waits up to 15 seconds
for that fix, then reports failure without creating a shot. Yardage displays accept
fixes up to 30 seconds old and 20 meters reported accuracy. There is no automatic swing
recognition or Arccos sensor decoding in this version.

Physical paired-device checks are required for background WatchConnectivity delivery,
GPS accuracy, haptics, wrist-down behavior, and battery use. In particular, test losing
connectivity between marks, restarting both apps, reconnecting, and confirming that
each shot appears exactly once. The simulator cannot validate background user-info
transfers or real GPS reception.

Hole completion is also persisted on Watch and sent only after its shots have been
acknowledged. Keep the iPhone nearby: advancement waits for the phone to confirm
saving. Retried completion messages cannot skip another hole. A stale scoring
sheet cannot apply a score to a different hole. Putts are stored as scorecard
counts; no putter is added to the Club domain.


## Personal round tracking

- Watch: mark each shot at the ball, change the club before or after marking, and review or undo the last completed shot. The next mark measures the previous shot's total distance.
- Penalties: add one or two strokes. For a lost ball, use “End mark + penalty” to retain an unmeasured stroke without counting the walk to the drop as club distance. Hole totals include putts and penalties.
- Round summary → Your tracked round: review the map, add missing shots, correct clubs and locations, exclude unusual shots, and edit hole scores. Map edits leave the score unchanged.
- Bag → club: on-course median and typical range use eligible full shots with acceptable GPS accuracy. These are total distances, separate from range carry calibration.
- Mapped green polygons provide approximate front/middle/back yardages on Watch. Unmapped greens retain pin yardage.
- Add the Dispersion launcher complication to a supported Watch face for quick access.
- Optional missed-shot reminders and experimental swing prompts operate while the Watch app is active. Swing prompts require confirmation; they do not automatically record shots. Real-device accuracy and battery use need on-course testing.
- Backup version 4 includes saved rounds and course shots, including exclusions and penalties. Older backups remain readable.
