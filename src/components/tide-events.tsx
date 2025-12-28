import { useMemo } from 'react'
import { formatTime, formatDate } from '@/lib/utils'
import { SunriseIcon, SunsetIcon, SunIcon } from './icons'
import type { TideExtreme } from '@/lib/tides'
import type { SunTimes, MoonPhaseInfo } from '@/lib/astronomy'

interface TideEventsProps {
  extremes: TideExtreme[]
  sunTimes: SunTimes
  moonPhase: MoonPhaseInfo
  selectedDate: Date
}

type TideEvent =
  | { type: 'high' | 'low'; time: Date; height: number }
  | { type: 'sunrise' | 'sunset'; time: Date }

export function TideEvents({ extremes, sunTimes, moonPhase, selectedDate }: TideEventsProps) {
  const events = useMemo(() => {
    const e: TideEvent[] = extremes.map(x => ({ ...x }))
    if (sunTimes.sunrise) e.push({ type: 'sunrise', time: sunTimes.sunrise })
    if (sunTimes.sunset) e.push({ type: 'sunset', time: sunTimes.sunset })
    return e.sort((a, b) => a.time.getTime() - b.time.getTime())
  }, [extremes, sunTimes])

  return (
    <div className="w-full max-w-[360px] md:max-w-[480px] lg:max-w-[540px] mt-2 bg-[var(--card-bg)] rounded-[var(--border-radius)] shadow-[var(--shadow)] overflow-hidden border-[var(--card-border)]">
      {/* Header */}
      <div className="px-2.5 py-2 bg-[var(--header-bg)] text-[var(--header-text)] flex justify-between items-center border-b-[var(--card-border)]">
        <div className="text-[0.6rem] font-bold tracking-wide">
          {formatDate(selectedDate)}
        </div>
      </div>

      {/* Sun/Moon info bar */}
      <div className="flex justify-between items-center px-2.5 py-2 bg-[var(--sun-moon-bg)] border-b border-[var(--text-muted)]/20">
        <div className="flex items-center gap-1.5">
          <SunIcon color="var(--sun-color)" size={16} />
          <div>
            <div className="text-[0.5rem] text-[var(--text-muted)] tracking-wide">DAYLIGHT</div>
            <div className="text-[0.7rem] font-bold text-[var(--sun-color)]">
              {sunTimes.dayLength ? `${sunTimes.dayLength.hours}h ${sunTimes.dayLength.minutes}m` : '--'}
            </div>
          </div>
        </div>
        <div className="flex items-center gap-1.5">
          <span className="text-lg">{moonPhase.emoji}</span>
          <div className="text-right">
            <div className="text-[0.5rem] text-[var(--text-muted)] tracking-wide">MOON</div>
            <div className="text-[0.7rem] font-bold">{moonPhase.name}</div>
          </div>
        </div>
      </div>

      {/* Events list */}
      <div className="py-1">
        {events.map((e, i) => {
          const isSun = e.type === 'sunrise' || e.type === 'sunset'

          return (
            <div
              key={i}
              className={`grid grid-cols-[44px_55px_1fr] items-center px-2.5 py-2 gap-2 ${
                i < events.length - 1 ? 'border-b border-[var(--text-muted)]/10' : ''
              } ${isSun ? 'bg-[var(--sun-moon-bg)]' : ''}`}
            >
              {/* Event type badge */}
              <span
                className={`text-[0.55rem] font-bold py-0.5 w-9 text-center rounded-[var(--border-radius)] ${
                  isSun
                    ? 'bg-[var(--sun-moon-bg)] text-[var(--sun-color)] border-2 border-[var(--sun-color)]'
                    : e.type === 'high'
                      ? 'bg-[var(--high-bg)] text-[var(--high-text)] border-2 border-transparent'
                      : 'bg-[var(--low-bg)] text-[var(--low-text)] border-2 border-[var(--low-border)]'
                }`}
              >
                {isSun ? (e.type === 'sunrise' ? 'RISE' : 'SET') : e.type.toUpperCase()}
              </span>

              {/* Time */}
              <span className="text-base font-bold">{formatTime(e.time)}</span>

              {/* Details */}
              {isSun ? (
                <div className="text-xs text-[var(--sun-color)] font-semibold flex items-center gap-1.5">
                  {e.type === 'sunrise' ? (
                    <SunriseIcon color="var(--sun-color)" size={18} />
                  ) : (
                    <SunsetIcon color="var(--sun-color)" size={18} />
                  )}
                  {e.type === 'sunrise' ? 'Sunrise' : 'Sunset'}
                </div>
              ) : (
                <div className="flex items-center gap-2">
                  <span className="text-sm text-[var(--text-muted)] min-w-[38px]">
                    {(e as TideExtreme).height.toFixed(1)}m
                  </span>
                  <div className="flex-1 h-1.5 bg-[var(--bar-bg)] rounded-[var(--border-radius)] overflow-hidden">
                    <div
                      className="h-full bg-[var(--bar-fill)] rounded-[var(--border-radius)]"
                      style={{ width: `${((e as TideExtreme).height / 12) * 100}%` }}
                    />
                  </div>
                </div>
              )}
            </div>
          )
        })}
      </div>

      {/* Footer */}
      <div className="px-2.5 py-1.5 text-[0.5rem] text-[var(--text-muted)] text-center border-t border-[var(--text-muted)]/10">
        CALCULATED · ±10 MIN TYPICAL ACCURACY
      </div>
    </div>
  )
}
