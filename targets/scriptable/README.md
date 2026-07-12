# Scriptable widget target (reserved — phase 2)

An iOS [Scriptable](https://scriptable.app) home/lock-screen widget built from
`@u-b/tides-core`: one esbuild pass bundles the core source into a single-file
ES2020 IIFE with Scriptable's 3-line header comment, written straight into the
iCloud Scriptable folder for sync to the phone.

Verified plan (Jul 2026 research):

- Runtime: Scriptable's system JavaScriptCore — the core package runs
  unmodified (zero deps, no env globals). `Intl` with IANA time zones is
  expected to work (ships with iOS); **run the 5-line on-device probe first**
  — `core/src/time.ts` isolates the single `Intl` call site so a closed-form
  UK-DST fallback (~15 lines) can drop in if needed.
- UI: `ListWidget` + `DrawContext` (true sampled curve via `Path`), lock-screen
  accessories render as a single image + text.
- Refresh: show absolute event times; `refreshAfterDate =
  min(nextExtreme + 60s, now + 30min)`; `WidgetDate.applyTimerStyle()` ticks
  countdowns for free.
- Types: `@types/scriptable-ios`; type-check with `tsc --noEmit`, build with
  esbuild (unminified — no source maps in Scriptable).
