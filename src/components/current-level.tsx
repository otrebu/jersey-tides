import { formatTime } from '@/lib/utils'
import type { CurrentTide, TideExtreme } from '@/lib/tides'
import type { MoonPhaseInfo } from '@/lib/astronomy'

interface CurrentLevelProps {
  currentLevel: CurrentTide | null
  isToday: boolean
  selectedDate: Date
  moonPhase: MoonPhaseInfo
  extremes: TideExtreme[]
}

export function CurrentLevel({ currentLevel, isToday, selectedDate, moonPhase, extremes }: CurrentLevelProps) {
  return (
    <div className="w-full max-w-[360px] mb-2 px-3 py-2.5 bg-[var(--current-bg)] text-[var(--current-text)] rounded-[var(--border-radius)] shadow-[var(--shadow)] border-[var(--card-border)]">
      <div className="flex items-baseline gap-2.5">
        <span className="text-[0.55rem] font-bold tracking-wider">
          {isToday ? 'NOW' : 'VIEWING'}
        </span>
        <span className="text-2xl font-black">
          {isToday && currentLevel
            ? `${currentLevel.height.toFixed(1)}m`
            : selectedDate.toLocaleDateString('en-GB', { day: 'numeric', month: 'short' })}
        </span>
        <span className="text-[0.6rem] font-bold">
          {isToday && currentLevel
            ? currentLevel.rising ? '↑ RISING' : '↓ FALLING'
            : selectedDate.getFullYear()}
        </span>
        <span className="text-xl ml-auto">
          {moonPhase.emoji}
        </span>
      </div>
      <div className="text-[0.55rem] text-[var(--current-muted)] mt-1">
        {isToday && currentLevel?.nextExtreme
          ? `Next ${currentLevel.nextExtreme.type} at ${formatTime(currentLevel.nextExtreme.time)}`
          : `${extremes.length} tides · ${moonPhase.name}`}
      </div>
    </div>
  )
}
