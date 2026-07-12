# @u-b/tides-core

Zero-dependency harmonic tide prediction. Ships a generic harmonic engine plus a
St Helier (Jersey) station whose constituents are **fitted to the States of
Jersey published tide tables**. ESM-only, TypeScript types included.

```bash
pnpm add @u-b/tides-core
```

## Quickstart

The St Helier station is ready to use — no setup, no network:

```ts
import { stHelier } from '@u-b/tides-core/stations/st-helier'

// Height now, whether the tide is rising, and the next high/low.
const { height, rising, nextExtreme } = stHelier.currentLevel()
//    height: metres above chart datum
//    rising: boolean
//    nextExtreme: { time: Date, height: number, type: 'high' | 'low' } | null

// Every high/low for a calendar day (in the station's timezone, Europe/Jersey).
const events = stHelier.dayExtremes(new Date())
for (const e of events) {
  console.log(e.type, e.time.toISOString(), e.height.toFixed(2))
}

// Evenly spaced heights across a day — handy for plotting a curve.
const curve = stHelier.timeline(new Date(), 6) // 6 points/hour
```

`currentLevel`, `dayExtremes`, `timeline`, `levelAt`, `slopeAt` and `extremes`
are all documented on the `Station` type.

## Other stations

Bring your own harmonic constants and reckon days in any timezone:

```ts
import { createStation } from '@u-b/tides-core'

const station = createStation({
  id: 'my-port',
  name: 'My Port',
  latitude: 49.0,
  longitude: -2.0,
  timeZone: 'Europe/Jersey', // calendar days are reckoned here
  datum: 5.9,                 // metres added to predictor output (chart datum)
  constituents: [
    // { name, amplitude (m), phase_GMT (deg) }
    // name must be one of the built-in CATALOG constituents (M2, S2, N2, K1, ...)
    // ...your fitted or published harmonic constants
  ]
})
```

Constituent names must exist in the engine's built-in `CATALOG` (exported for
inspection) — `createStation` throws `Unknown constituents: ...` for any name
it does not recognise. Speeds and nodal corrections come from the catalog;
you supply only amplitude and Greenwich phase lag (`phase_GMT`).

The sun/moon almanac (pure NOAA sun position + Meeus moon phase, no
dependencies) is a separate entrypoint:

```ts
import { getSunTimes, getMoonPhase } from '@u-b/tides-core/almanac'
```

## Accuracy

St Helier predictions were checked against **931 official events** from the
States of Jersey tables (cross-verified against gov.je / NOC and SHOM):

| Metric  | Mean     | Max      |
| ------- | -------- | -------- |
| Timing  | 1.2 min  | 4.3 min  |
| Heights | 0.11 m   | 0.39 m   |

## Provenance

Constituents derived by harmonic fit to States of Jersey published tide tables.
Predictions are computed locally and are **NOT for navigation**.

## License

MIT
