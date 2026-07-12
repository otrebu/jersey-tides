import { formatTime } from '@u-b/tides-core'
import type { CurrentTide, TideExtreme } from '@u-b/tides-core'
import type { MoonPhaseInfo } from '@u-b/tides-core/almanac'

export interface CurrentLevelProps {
  currentLevel: CurrentTide | null
  isToday: boolean
  /** UTC instant of the viewed day's local midnight; null pre-mount without props */
  dayStart: Date | null
  timeZone: string
  moonPhase: MoonPhaseInfo | null
  extremes: TideExtreme[]
}

export function CurrentLevel({ currentLevel, isToday, dayStart, timeZone, moonPhase, extremes }: CurrentLevelProps) {
  const dateLabel = dayStart
    ? new Intl.DateTimeFormat('en-GB', { timeZone, day: 'numeric', month: 'short' }).format(dayStart)
    : '--'
  const yearLabel = dayStart
    ? new Intl.DateTimeFormat('en-GB', { timeZone, year: 'numeric' }).format(dayStart)
    : ''

  return (
    <div className="ubtide-current w-full mb-2 px-3 py-2.5 md:px-4 md:py-3 bg-[var(--ubtide-current-bg)] text-[var(--ubtide-current-text)] rounded-[var(--ubtide-border-radius)] shadow-[var(--ubtide-shadow)] border-[length:var(--ubtide-card-border-width)] border-[color:var(--ubtide-card-border-color)]">
      <div className="flex items-baseline gap-2.5">
        <span className="text-[0.55rem] font-bold tracking-wider">
          {isToday ? 'NOW' : 'VIEWING'}
        </span>
        <span className="text-2xl md:text-3xl font-black">
          {isToday && currentLevel ? `${currentLevel.height.toFixed(1)}m` : dateLabel}
        </span>
        <span className="text-[0.6rem] font-bold">
          {isToday && currentLevel
            ? currentLevel.rising ? '↑ RISING' : '↓ FALLING'
            : yearLabel}
        </span>
        <span className="text-xl ml-auto">
          {moonPhase?.emoji ?? ''}
        </span>
      </div>
      <div className="text-[0.55rem] text-[var(--ubtide-current-muted)] mt-1">
        {isToday && currentLevel?.nextExtreme
          ? `Next ${currentLevel.nextExtreme.type} at ${formatTime(currentLevel.nextExtreme.time, timeZone)}`
          : moonPhase
            ? `${extremes.length} tides · ${moonPhase.name}`
            : ' '}
      </div>
    </div>
  )
}
