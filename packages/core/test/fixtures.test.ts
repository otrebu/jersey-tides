import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { getMoonPhaseEvents, getSunTimes } from '../src/almanac.ts'
import { createPredictor } from '../src/engine.ts'
import { ST_HELIER_CONSTITUENTS } from '../src/stations/st-helier.data.ts'
import { stHelier } from '../src/stations/st-helier.ts'
import { dayBoundsUtc } from '../src/time.ts'

const load = (name: string) =>
  JSON.parse(readFileSync(new URL(`../fixtures/${name}`, import.meta.url), 'utf8'))

const levels = load('levels.json') as Array<{ utc: string; level: number }>
const extremeWindows = load('extremes.json') as Array<{
  fromUtc: string
  toUtc: string
  extremes: Array<{ utc: string; level: number; type: 'high' | 'low' }>
}>
const stationDays = load('station-days.json') as Array<{
  day: { year: number; month: number; day: number }
  tz: string
  extremes: Array<{ utc: string; height: number; type: 'high' | 'low' }>
}>

const almanac = load('almanac.json') as {
  sun: Array<{
    day: { year: number; month: number; day: number }
    tz: string
    sunrise: string | null
    sunset: string | null
    dayLength: { hours: number; minutes: number } | null
  }>
  moonEvents: Array<{ type: string; utc: string }>
}

// Replay tolerances, NOT exact equality: Math.sin/cos/atan2 are not required
// to be correctly rounded and differ by ~1 ULP across V8 versions and
// architectures (fixtures are generated on the arm64/Node-25 dev machine; CI
// replays on x64/Node 22). 1e-9 m and 1 s still pin the engine numerically —
// a real constituent or algorithm change moves heights by ≥ millimetres and
// extreme times by minutes. Byte-identity for pure refactors is enforced
// in-process (same runtime on both sides) by tools/fit/verify-engine-move.mjs.
const HEIGHT_EPS_M = 1e-9
const TIME_EPS_MS = 1000

const expectHeight = (got: number, want: number) => {
  expect(Math.abs(got - want)).toBeLessThanOrEqual(HEIGHT_EPS_M)
}
const expectInstant = (gotMs: number, wantUtc: string) => {
  expect(Math.abs(gotMs - new Date(wantUtc).getTime())).toBeLessThanOrEqual(TIME_EPS_MS)
}
const expectNullableInstant = (got: Date | null, wantUtc: string | null) => {
  if (wantUtc === null) {
    expect(got).toBeNull()
    return
  }
  expect(got).not.toBeNull()
  expectInstant((got as Date).getTime(), wantUtc)
}

const predictor = createPredictor(ST_HELIER_CONSTITUENTS)

describe('golden replay: levels', () => {
  it('reproduces every raw-engine level to 1e-9 m', () => {
    expect(levels.length).toBe(2000)
    for (const { utc, level } of levels) {
      expectHeight(predictor.levelAt(new Date(utc)), level)
    }
  })
})

describe('golden replay: extremes', () => {
  it('reproduces every raw-engine extreme to 1e-9 m / 1 s', () => {
    expect(extremeWindows.length).toBeGreaterThan(0)
    for (const w of extremeWindows) {
      const got = predictor.extremes(new Date(w.fromUtc), new Date(w.toUtc))
      expect(got.length).toBe(w.extremes.length)
      for (let i = 0; i < got.length; i++) {
        expectInstant(got[i].time.getTime(), w.extremes[i].utc)
        expectHeight(got[i].level, w.extremes[i].level)
        expect(got[i].high ? 'high' : 'low').toBe(w.extremes[i].type)
      }
    }
  })
})

describe('golden replay: station days', () => {
  it('reproduces every datum-inclusive station extreme to 1e-9 m / 1 s', () => {
    expect(stationDays.length).toBe(25)
    for (const d of stationDays) {
      const got = stHelier.dayExtremes(d.day)
      expect(got.length).toBe(d.extremes.length)
      for (let i = 0; i < got.length; i++) {
        expectInstant(got[i].time.getTime(), d.extremes[i].utc)
        expectHeight(got[i].height, d.extremes[i].height)
        expect(got[i].type).toBe(d.extremes[i].type)
      }
    }
  })
})

describe('golden replay: almanac', () => {
  it('reproduces every sun time to 1 s', () => {
    expect(almanac.sun.length).toBe(16)
    for (const s of almanac.sun) {
      const got = getSunTimes(s.day)
      expectNullableInstant(got.sunrise, s.sunrise)
      expectNullableInstant(got.sunset, s.sunset)
      expect(got.dayLength).toEqual(s.dayLength)
    }
  })

  it('reproduces every 2026 moon phase event to 1 s', () => {
    const got = getMoonPhaseEvents(
      new Date('2026-01-01T00:00:00.000Z'),
      new Date('2026-12-31T23:59:59.999Z')
    )
    expect(got.length).toBe(almanac.moonEvents.length)
    for (let i = 0; i < got.length; i++) {
      expect(got[i].type).toBe(almanac.moonEvents[i].type)
      expectInstant(got[i].time.getTime(), almanac.moonEvents[i].utc)
    }
  })
})

describe('semantic invariants', () => {
  it('extremes alternate high/low within each window', () => {
    for (const w of extremeWindows) {
      for (let i = 1; i < w.extremes.length; i++) {
        expect(w.extremes[i].type).not.toBe(w.extremes[i - 1].type)
      }
    }
  })

  it('slope is ~0 at every extreme time', () => {
    // extremes() bisects the slope-zero bracket to a 500ms window, so the residual
    // slope is bounded by curv * dt (~5e-5 m/h worst case) — four to five orders of
    // magnitude below the several-m/h slopes away from extremes.
    for (const w of extremeWindows) {
      for (const e of w.extremes) {
        expect(Math.abs(predictor.slopeAt(new Date(e.utc)))).toBeLessThan(1e-4)
      }
    }
  })

  it('DST-transition days are 23h and 25h long', () => {
    const hours = (day: { year: number; month: number; day: number }) => {
      const { start, end } = dayBoundsUtc(day, 'Europe/Jersey')
      return (end.getTime() - start.getTime()) / 3600000
    }
    // Spring forward (clocks +1h) → 23h civil day; fall back (clocks -1h) → 25h.
    expect(hours({ year: 2025, month: 3, day: 30 })).toBe(23)
    expect(hours({ year: 2025, month: 10, day: 26 })).toBe(25)
    expect(hours({ year: 2026, month: 3, day: 29 })).toBe(23)
    expect(hours({ year: 2026, month: 10, day: 25 })).toBe(25)
    // Ordinary day is exactly 24h.
    expect(hours({ year: 2025, month: 7, day: 4 })).toBe(24)
  })
})
