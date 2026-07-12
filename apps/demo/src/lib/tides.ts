import { stHelier } from '@u-b/tides-core/stations/st-helier'
import type { CurrentTide, TideExtreme } from '@u-b/tides-core'

export type { CurrentTide, TideExtreme } from '@u-b/tides-core'

/**
 * Get the tide level at a specific time
 */
export function getTideLevel(time: Date): number {
  return stHelier.levelAt(time)
}

/**
 * Get all high and low tides for a given day
 */
export function getDayExtremes(date: Date): TideExtreme[] {
  return stHelier.dayExtremes(date)
}

/**
 * Get current tide level with direction and next extreme
 */
export function getCurrentLevel(now: Date = new Date()): CurrentTide {
  return stHelier.currentLevel(now)
}

/**
 * Get tide timeline for visualization (hourly points)
 */
export function getTideTimeline(date: Date, pointsPerHour: number = 6): Array<{ time: Date; height: number }> {
  return stHelier.timeline(date, pointsPerHour)
}
