import { createPredictor } from './engine.ts'
import type { HarmonicConstant } from './engine.ts'
import { addDays, dayBoundsUtc, toDay } from './time.ts'
import type { CalendarDay } from './time.ts'

export interface StationDefinition {
  id: string
  name: string
  latitude: number
  longitude: number
  /** IANA timezone the station's calendar days are reckoned in */
  timeZone: string
  /** chart datum offset in metres (added to predictor output) */
  datum: number
  constituents: HarmonicConstant[]
}

export interface TideExtreme {
  time: Date
  height: number
  type: 'high' | 'low'
}

export interface CurrentTide {
  height: number
  rising: boolean
  nextExtreme: TideExtreme | null
}

export interface TimelinePoint {
  time: Date
  height: number
}

export interface Station extends Readonly<StationDefinition> {
  /** Tide height above chart datum in metres. */
  levelAt(t: Date): number
  /** d(height)/dt in metres/hour. */
  slopeAt(t: Date): number
  /** All high/low extremes in [from, to). */
  extremes(from: Date, to: Date): TideExtreme[]
  /** Extremes for a calendar day in the station's timezone. */
  dayExtremes(day: Date | CalendarDay): TideExtreme[]
  /** Height, direction and next extreme (searched over today + tomorrow). */
  currentLevel(now?: Date): CurrentTide
  /** Evenly spaced heights across a calendar day in the station's timezone. */
  timeline(day: Date | CalendarDay, pointsPerHour?: number): TimelinePoint[]
}

export function createStation(def: StationDefinition): Station {
  const predictor = createPredictor(def.constituents)

  const levelAt = (t: Date): number => def.datum + predictor.levelAt(t)

  const slopeAt = (t: Date): number => predictor.slopeAt(t)

  const extremes = (from: Date, to: Date): TideExtreme[] =>
    predictor.extremes(from, to).map((e): TideExtreme => ({
      time: e.time,
      height: def.datum + e.level,
      type: e.high ? 'high' : 'low'
    }))

  const dayExtremes = (day: Date | CalendarDay): TideExtreme[] => {
    const { start, end } = dayBoundsUtc(toDay(day, def.timeZone), def.timeZone)
    // Pad the search window so an extreme falling exactly at midnight is still
    // bracketed by the slope-sign scan, then filter back to the day.
    const padMs = 60 * 60 * 1000
    return extremes(new Date(start.getTime() - padMs), new Date(end.getTime() + padMs))
      .filter(e => e.time >= start && e.time < end)
  }

  const currentLevel = (now: Date = new Date()): CurrentTide => {
    const height = levelAt(now)
    const today = toDay(now, def.timeZone)
    const candidates = [...dayExtremes(today), ...dayExtremes(addDays(today, 1))]
    const nextExtreme = candidates.find(e => e.time > now) || null
    return {
      height,
      rising: nextExtreme ? nextExtreme.type === 'high' : false,
      nextExtreme
    }
  }

  const timeline = (day: Date | CalendarDay, pointsPerHour: number = 6): TimelinePoint[] => {
    const { start, end } = dayBoundsUtc(toDay(day, def.timeZone), def.timeZone)
    const intervalMs = (60 / pointsPerHour) * 60 * 1000
    const points: TimelinePoint[] = []
    for (let t = start.getTime(); t <= end.getTime(); t += intervalMs) {
      const time = new Date(t)
      points.push({ time, height: levelAt(time) })
    }
    return points
  }

  return { ...def, levelAt, slopeAt, extremes, dayExtremes, currentLevel, timeline }
}
