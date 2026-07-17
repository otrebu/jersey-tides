# Native iOS target (phase 3 — in progress)

A SwiftPM `TidesCore` package (Swift port of `packages/core/src/engine.ts`) +
SwiftUI app + WidgetKit extension. Lives at the repo root because a Swift
package is not a pnpm workspace member.

## Layout

- `project.yml` — XcodeGen spec. Regenerate after every edit with
  `xcodegen generate`; the `.xcodeproj` is gitignored — never hand-edit the
  `.pbxproj`. `ios/.derived/` (the `-derivedDataPath`) is gitignored too.
- `TidesCore/` — SwiftPM engine package (fixture-parity port, own gate:
  `swift test`). **Not yet linked into the app**: `project.yml` deliberately
  omits the package while the port lands in parallel; the integrator adds the
  `packages:` block + target dependencies. Until then the app runs entirely on
  the deterministic `SyntheticEngine` behind the `TideEngine` protocol facade
  (`Shared/Engine/`); the swap point is `EngineProvider.engine`. Nothing
  outside `TidesCore/` may import TidesCore.
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
- `-harness-day <ISO>`, `-harness-mode standard|accented|vibrant` — gallery
  selectors (chunk F).

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
