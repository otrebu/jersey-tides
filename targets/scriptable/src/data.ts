import { calendarDayOf, dayBoundsUtc, formatTime } from '@u-b/tides-core'
import type { CalendarDay, TideExtreme, TimelinePoint } from '@u-b/tides-core'
import { getSunTimes } from '@u-b/tides-core/almanac'
import { stHelier } from '@u-b/tides-core/stations/st-helier'

export const TZ = stHelier.timeZone

export interface TideVM {
  now: Date
  height: number
  rising: boolean
  /** Next extremes after `now`, chronological — [0] and [1] alternate HW/LW. */
  next: TideExtreme[]
  day: CalendarDay
  /** UTC instants of local midnight and next local midnight (23/24/25h on DST days). */
  dayStart: Date
  dayEnd: Date
  /** 10-minute sampled curve across the local day. */
  points: TimelinePoint[]
  dayExtremes: TideExtreme[]
  sunrise: Date | null
  sunset: Date | null
  refreshAfter: Date
}

export function buildVM(now: Date = new Date()): TideVM {
  const day = calendarDayOf(now, TZ)
  const { start, end } = dayBoundsUtc(day, TZ)
  // A 26h horizon always spans the next HW and LW (extremes are ~6.2h apart).
  const next = stHelier.extremes(now, new Date(now.getTime() + 26 * 3_600_000)).slice(0, 2)
  const height = stHelier.levelAt(now)
  const rising = next.length > 0 ? next[0].type === 'high' : stHelier.slopeAt(now) > 0
  const sun = getSunTimes(day)
  // Best-effort refresh just after the next extreme, at most 30 min out. A
  // delayed refresh still renders correctly — all displayed times are absolute.
  const nextAt = next.length > 0 ? next[0].time.getTime() + 60_000 : Infinity
  const refreshAfter = new Date(Math.min(nextAt, now.getTime() + 30 * 60_000))
  return {
    now,
    height,
    rising,
    next,
    day,
    dayStart: start,
    dayEnd: end,
    points: stHelier.timeline(day, 6),
    dayExtremes: stHelier.dayExtremes(day),
    sunrise: sun.sunrise,
    sunset: sun.sunset,
    refreshAfter
  }
}

export function fmtExtreme(e: TideExtreme): string {
  return `${e.type === 'high' ? 'HW' : 'LW'} ${formatTime(e.time, TZ)} · ${e.height.toFixed(1)}m`
}

export function arrow(rising: boolean): string {
  return rising ? '▲' : '▼'
}
