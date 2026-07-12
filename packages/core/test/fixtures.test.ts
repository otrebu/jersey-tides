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

const predictor = createPredictor(ST_HELIER_CONSTITUENTS)

describe('golden replay: levels', () => {
  it('reproduces every raw-engine level exactly', () => {
    expect(levels.length).toBe(2000)
    for (const { utc, level } of levels) {
      expect(predictor.levelAt(new Date(utc))).toBe(level)
    }
  })
})

describe('golden replay: extremes', () => {
  it('reproduces every raw-engine extreme exactly', () => {
    expect(extremeWindows.length).toBeGreaterThan(0)
    for (const w of extremeWindows) {
      const got = predictor.extremes(new Date(w.fromUtc), new Date(w.toUtc))
      expect(got.length).toBe(w.extremes.length)
      for (let i = 0; i < got.length; i++) {
        expect(got[i].time.getTime()).toBe(new Date(w.extremes[i].utc).getTime())
        expect(got[i].level).toBe(w.extremes[i].level)
        expect(got[i].high ? 'high' : 'low').toBe(w.extremes[i].type)
      }
    }
  })
})

describe('golden replay: station days', () => {
  it('reproduces every datum-inclusive station extreme exactly', () => {
    expect(stationDays.length).toBe(25)
    for (const d of stationDays) {
      const got = stHelier.dayExtremes(d.day)
      expect(got.length).toBe(d.extremes.length)
      for (let i = 0; i < got.length; i++) {
        expect(got[i].time.getTime()).toBe(new Date(d.extremes[i].utc).getTime())
        expect(got[i].height).toBe(d.extremes[i].height)
        expect(got[i].type).toBe(d.extremes[i].type)
      }
    }
  })
})

describe('golden replay: almanac', () => {
  it('reproduces every sun time exactly', () => {
    expect(almanac.sun.length).toBe(16)
    for (const s of almanac.sun) {
      const got = getSunTimes(s.day)
      expect(got.sunrise ? got.sunrise.toISOString() : null).toBe(s.sunrise)
      expect(got.sunset ? got.sunset.toISOString() : null).toBe(s.sunset)
      expect(got.dayLength).toEqual(s.dayLength)
    }
  })

  it('reproduces every 2026 moon phase event exactly', () => {
    const got = getMoonPhaseEvents(
      new Date('2026-01-01T00:00:00.000Z'),
      new Date('2026-12-31T23:59:59.999Z')
    )
    expect(got.length).toBe(almanac.moonEvents.length)
    for (let i = 0; i < got.length; i++) {
      expect(got[i].type).toBe(almanac.moonEvents[i].type)
      expect(got[i].time.toISOString()).toBe(almanac.moonEvents[i].utc)
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
