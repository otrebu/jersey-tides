# Native iOS target (phase 3)

A SwiftPM `TidesCore` package (Swift port of `packages/core/src/engine.ts`) +
SwiftUI app + WidgetKit extension. Lives at the repo root because a Swift
package is not a pnpm workspace member.

## Layout

- `project.yml` — XcodeGen spec. Regenerate after every edit with
  `xcodegen generate`; the `.xcodeproj` is gitignored — never hand-edit the
  `.pbxproj`. `ios/.derived/` (the `-derivedDataPath`) is gitignored too.
- `TidesCore/` — SwiftPM engine package (fixture-parity port, own gate:
  `swift test`). Linked into BOTH targets via the `packages:` block in
  `project.yml`. The app and widgets run on `TidesCoreEngine`
  (`Shared/Engine/TidesCoreEngine.swift`), the adapter behind the
  `TideEngine` protocol facade (`Shared/Engine/`); the composition point is
  `EngineProvider.engine`. Only the adapter may import TidesCore — all other
  UI code goes through the facade. The deterministic `SyntheticEngine` is
  kept for unit tests (`Tests/` instantiate it directly).
- `Shared/` — compiled into BOTH the app and widget targets (no framework):
  engine facade, theme tokens/typography, day-model assembly, curve renderer.
- `App/`, `Widget/` — app screens and WidgetKit extension (bundle id
  `je.ub.tides` / `je.ub.tides.widget`, min iOS 26.0). The widget computes
  in-process from the engine — no App Group, no network, free-team signable.
  `Widget/Families/` + `Widget/ErrorTileView.swift` are also compiled into the
  app so the DEBUG widget gallery can render every entry view.
- `Tests/` — app-hosted unit tests (`JerseyTidesTests`, Swift Testing).

## Build / test / screenshot loop

Requires full Xcode (verified: Xcode 26.6, iOS 26.5 simulator runtime,
xcodegen 2.46.0) — the old "Command Line Tools only" blocker is resolved.

```bash
# Engine gate
cd ios/TidesCore && swift test

# Generate the project (after any project.yml change)
cd ios && xcodegen generate

# Build
xcodebuild -project ios/JerseyTides.xcodeproj -scheme JerseyTides \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath ios/.derived build

# Unit tests
xcodebuild -project ios/JerseyTides.xcodeproj -scheme JerseyTides \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath ios/.derived test

# Screenshot loop
xcrun simctl boot "iPhone 17 Pro" 2>/dev/null || true
xcrun simctl install booted \
  ios/.derived/Build/Products/Debug-iphonesimulator/JerseyTides.app
xcrun simctl launch --terminate-running-process booted je.ub.tides \
  -harness widgets -frozen-now 2026-07-17T12:00:00Z
xcrun simctl io booted screenshot /tmp/shot.png
```

## DEBUG harness launch arguments

- `-frozen-now <ISO8601>` — pins the injectable clock
  (`EngineProvider.clock`), e.g. `-frozen-now 2026-07-17T12:00:00Z`.
- `-harness app|widgets|curve` — boot surface: the app (default), the widget
  gallery (`App/Debug/DebugWidgetGallery.swift`, every family at fixed frame),
  or the curve harness (every `CurveStyle` preset + ghost sparkline).
- App surface: `-harness-page <offset>` pre-pages the Today pager (e.g. `1` =
  tomorrow, clamped ±14); `-harness-sheet fortnight|settings` opens a sheet
  on launch.
- Widget gallery: `-harness-page 1|2|3|4|5` — one screen-sized section per
  launch (1 dials+medium, 2 large charts, 3 accessories, 4 system error
  tiles, 5 accessory error tiles + manual-gate note); `-harness-day <ISO>`;
  `-harness-mode standard|accented|vibrant` (env override only — real tint
  compositing is the manual gate on page 5).

## Engine port contract (TidesCore)

The committed golden fixtures are the contract: Swift tests read
`../packages/core/fixtures/*.json` (read-only) and must reproduce levels
within 1 mm and extreme times within 1 s. Port order: astro → nodal
corrections → catalog → predictor → extremes, gated by `swift test` at every
step.

Port traps: JS `%` vs Swift `truncatingRemainder` on negative angles
(`mod360`), ms vs seconds epoch, `Double` is IEEE-754 on both sides.

## Signing / device install

`DEVELOPMENT_TEAM` in `project.yml` is a placeholder — fill it from Xcode ▸
Settings ▸ Accounts before a device install (free personal team is enough;
7-day re-sign cycle; ~10 App-ID/week cap — do not churn bundle ids).
