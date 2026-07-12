import { Body, Illumination, MoonPhase, Observer, SearchMoonPhase, SearchRiseSet } from 'astronomy-engine'
import { describe, expect, it } from 'vitest'
import { getMonthMoonPhaseEvents, getMoonPhase, getMoonPhaseEvents, getSunTimes } from '../src/almanac.ts'
import { calendarDayOf, dayBoundsUtc } from '../src/time.ts'
import type { CalendarDay } from '../src/time.ts'

const LAT = 49.183
const LON = -2.117
const TZ = 'Europe/Jersey'
const DAY_MS = 86400000
const RANGE_START = Date.UTC(2025, 0, 1)
const RANGE_END = Date.UTC(2027, 11, 31, 23, 59, 59)

const observer = new Observer(LAT, LON, 0)

const utcDay = (ms: number): CalendarDay => {
  const d = new Date(ms)
  return { year: d.getUTCFullYear(), month: d.getUTCMonth() + 1, day: d.getUTCDate() }
}

describe('almanac parity: sun times', () => {
  const days: CalendarDay[] = []
  for (let ms = RANGE_START; ms <= RANGE_END; ms += 11 * DAY_MS) days.push(utcDay(ms))
  const solstices: CalendarDay[] = [
    { year: 2025, month: 6, day: 21 }, { year: 2025, month: 12, day: 21 },
    { year: 2026, month: 6, day: 21 }, { year: 2026, month: 12, day: 21 },
    { year: 2027, month: 6, day: 21 }, { year: 2027, month: 12, day: 22 }
  ]

  it('sunrise and sunset match astronomy-engine within 2 minutes', () => {
    for (const day of [...days, ...solstices]) {
      const mine = getSunTimes(day)
      const { start, end } = dayBoundsUtc(day, TZ)
      const limit = (end.getTime() - start.getTime()) / DAY_MS
      const riseResult = SearchRiseSet(Body.Sun, observer, +1, start, limit)
      const setResult = SearchRiseSet(Body.Sun, observer, -1, start, limit)
      const rise = riseResult && riseResult.date < end ? riseResult.date : null
      const set = setResult && setResult.date < end ? setResult.date : null

      expect(mine.sunrise === null).toBe(rise === null)
      expect(mine.sunset === null).toBe(set === null)
      if (mine.sunrise && rise) {
        expect(Math.abs(mine.sunrise.getTime() - rise.getTime())).toBeLessThanOrEqual(120000)
      }
      if (mine.sunset && set) {
        expect(Math.abs(mine.sunset.getTime() - set.getTime())).toBeLessThanOrEqual(120000)
      }
      expect(mine.dayLength === null).toBe(rise === null || set === null)
    }
  })

  it('agrees on null for polar day and polar night', () => {
    const svalbard = { latitude: 78.22, longitude: 15.65, timeZone: 'Arctic/Longyearbyen' }
    const polarObserver = new Observer(svalbard.latitude, svalbard.longitude, 0)
    for (const day of [
      { year: 2026, month: 6, day: 21 },
      { year: 2026, month: 12, day: 21 }
    ]) {
      const mine = getSunTimes(day, svalbard)
      const { start, end } = dayBoundsUtc(day, svalbard.timeZone)
      const limit = (end.getTime() - start.getTime()) / DAY_MS
      const riseResult = SearchRiseSet(Body.Sun, polarObserver, +1, start, limit)
      const rise = riseResult && riseResult.date < end ? riseResult.date : null
      expect(mine.sunrise).toBeNull()
      expect(mine.sunset).toBeNull()
      expect(mine.dayLength).toBeNull()
      expect(rise).toBeNull()
    }
  })
})

describe('almanac parity: moon phase', () => {
  it('phase angle within 0.5 degrees, illumination within 2', () => {
    for (let ms = RANGE_START + 12 * 3600000; ms <= RANGE_END; ms += 3 * DAY_MS) {
      const t = new Date(ms)
      const mine = getMoonPhase(t)
      const angleDiff = Math.abs(((mine.phaseAngle - MoonPhase(t) + 540) % 360) - 180)
      expect(angleDiff).toBeLessThanOrEqual(0.5)
      const ill = Math.round(Illumination(Body.Moon, t).phase_fraction * 100)
      expect(Math.abs(mine.illumination - ill)).toBeLessThanOrEqual(2)
    }
  })
})

describe('almanac parity: quadrature events', () => {
  it('matches every astronomy-engine event 2025-2027 within 10 minutes', () => {
    const start = new Date(RANGE_START)
    const end = new Date(RANGE_END)
    const mine = getMoonPhaseEvents(start, end)

    const angles = { new: 0, first_quarter: 90, full: 180, last_quarter: 270 } as const
    const reference: Array<{ type: keyof typeof angles; time: Date }> = []
    for (const [type, angle] of Object.entries(angles) as Array<[keyof typeof angles, number]>) {
      let cursor = start
      while (cursor < end) {
        const found = SearchMoonPhase(angle, cursor, 40)
        if (!found || found.date > end) break
        reference.push({ type, time: found.date })
        cursor = new Date(found.date.getTime() + DAY_MS)
      }
    }
    reference.sort((a, b) => a.time.getTime() - b.time.getTime())

    expect(mine.length).toBe(reference.length)
    for (let i = 0; i < reference.length; i++) {
      expect(mine[i].type).toBe(reference[i].type)
      expect(Math.abs(mine[i].time.getTime() - reference[i].time.getTime())).toBeLessThanOrEqual(600000)
    }
  })
})

describe('almanac: month bucketing', () => {
  it('buckets events by civil day-of-month in the given timezone', () => {
    for (const [year, month0] of [[2026, 0], [2026, 5], [2026, 11], [2027, 2]] as const) {
      const byDay = getMonthMoonPhaseEvents(year, month0, TZ)
      expect(byDay.size).toBeGreaterThanOrEqual(3)
      for (const [dom, event] of byDay) {
        const civil = calendarDayOf(event.time, TZ)
        expect(civil.year).toBe(year)
        expect(civil.month).toBe(month0 + 1)
        expect(civil.day).toBe(dom)
      }
    }
  })
})
