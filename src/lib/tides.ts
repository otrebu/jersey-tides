import TidePredictor from '@neaps/tide-predictor'
import { ST_HELIER_CONSTITUENTS, DATUM } from './constants'

// Initialize the tide predictor with St. Helier constituents
const predictor = TidePredictor(ST_HELIER_CONSTITUENTS, {
  phaseKey: 'phase_GMT'
})

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

/**
 * Get the tide level at a specific time
 */
export function getTideLevel(time: Date): number {
  const prediction: { level: number } = predictor.getWaterLevelAtTime({ time })
  return DATUM + prediction.level
}

/**
 * Get all high and low tides for a given day
 */
export function getDayExtremes(date: Date): TideExtreme[] {
  const start = new Date(date)
  start.setHours(0, 0, 0, 0)

  const end = new Date(start)
  end.setDate(end.getDate() + 1)

  const prediction: Array<{ time: Date; level: number; high: boolean }> = predictor.getExtremesPrediction({
    start,
    end,
    timeFidelity: 60 // 1 minute resolution in seconds
  })

  return prediction.map((e): TideExtreme => ({
    time: e.time,
    height: DATUM + e.level,
    type: e.high ? 'high' : 'low'
  }))
}

/**
 * Get current tide level with direction and next extreme
 */
export function getCurrentLevel(now: Date = new Date()): CurrentTide {
  const height = getTideLevel(now)

  // Get today's and tomorrow's extremes to find the next one
  const today = new Date(now)
  today.setHours(0, 0, 0, 0)

  const tomorrow = new Date(today)
  tomorrow.setDate(tomorrow.getDate() + 1)

  const extremes = [...getDayExtremes(today), ...getDayExtremes(tomorrow)]
  const nextExtreme = extremes.find(e => e.time > now) || null

  return {
    height,
    rising: nextExtreme ? nextExtreme.type === 'high' : false,
    nextExtreme
  }
}

/**
 * Get tide timeline for visualization (hourly points)
 */
export function getTideTimeline(date: Date, pointsPerHour: number = 6): Array<{ time: Date; height: number }> {
  const start = new Date(date)
  start.setHours(0, 0, 0, 0)

  const points: Array<{ time: Date; height: number }> = []
  const intervalMs = (60 / pointsPerHour) * 60 * 1000

  for (let i = 0; i <= 24 * pointsPerHour; i++) {
    const time = new Date(start.getTime() + i * intervalMs)
    points.push({
      time,
      height: getTideLevel(time)
    })
  }

  return points
}
