# Scriptable widget target

An iOS [Scriptable](https://scriptable.app) home/lock-screen widget built from
`@u-b/tides-core`: one esbuild pass bundles the workspace core into a
single-file ES2020 IIFE with Scriptable's mandatory 3-line header, written to
`dist/Tides.js` and synced straight into the iCloud Scriptable folder for the
phone.

## Build

```bash
pnpm widget:build        # from the repo root, or `pnpm build` here
pnpm --filter scriptable typecheck
```

`build.mjs` bundles `src/widget.ts` (unminified — Scriptable has no source
maps) and copies the result to
`~/Library/Mobile Documents/iCloud~dk~simonbs~Scriptable/Documents/Tides.js`
when that folder exists (skipped in CI).

## Layout

- `src/data.ts` — view-model: one snapshot of now/height/next extremes/day
  curve/sun times, all timezone math through core (`Europe/Jersey` explicit).
- `src/chart.ts` — DrawContext day curve: true 10-min sampled line + area,
  HW/LW dots with absolute time/height labels, sunrise/sunset baseline ticks,
  now marker. The x axis is linear in UTC between `dayBoundsUtc` bounds, so
  23/25h DST days are exact by construction.
- `src/lock.ts` — lock-screen faces. iOS reduces accessories to 1 image +
  1 text, so rectangular/circular render into a single DrawContext image;
  inline is one text line.
- `src/widget.ts` — entry: family dispatch (`small`, `medium`/`large`,
  `accessoryRectangular`/`Circular`/`Inline`), error fallback tile, refresh.
- `probe/IntlProbe.js` — gate-1 on-device Intl probe. Result 2026-07-12:
  9/9 PASS (see the note in `packages/core/src/time.ts`).

## Behavior

- Fully offline; everything is computed on-device at render time from the
  bundled harmonic engine.
- Absolute times are the source of truth; a stale render is still correct.
  `refreshAfterDate = min(next extreme + 60s, now + 30min)` (best-effort,
  ~15-min practical floor on iOS).
- Tap opens the script in Scriptable (medium in-app preview with console).
- Brutalist: `#111` on `#f8f8f8`, monospaced system font, no rounded corners.
