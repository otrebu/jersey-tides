import { useMemo } from 'react'
import { formatDate, formatTime } from '@u-b/tides-core'
import { SunriseIcon, SunsetIcon, SunIcon } from './icons.tsx'
import type { TideExtreme } from '@u-b/tides-core'
import type { SunTimes, MoonPhaseInfo } from '@u-b/tides-core/almanac'

export interface TideEventsProps {
  extremes: TideExtreme[]
  sunTimes: SunTimes
  moonPhase: MoonPhaseInfo
  /** UTC instant of the viewed day's local midnight */
  dayStart: Date
  timeZone: string
}

type TideEvent =
  | { type: 'high' | 'low'; time: Date; height: number }
  | { type: 'sunrise' | 'sunset'; time: Date }

export function TideEvents({ extremes, sunTimes, moonPhase, dayStart, timeZone }: TideEventsProps) {
  const events = useMemo(() => {
    const e: TideEvent[] = extremes.map(x => ({ ...x }))
    if (sunTimes.sunrise) e.push({ type: 'sunrise', time: sunTimes.sunrise })
    if (sunTimes.sunset) e.push({ type: 'sunset', time: sunTimes.sunset })
    return e.sort((a, b) => a.time.getTime() - b.time.getTime())
  }, [extremes, sunTimes])

  return (
    <div className="ubtide-events w-full mt-2 bg-[var(--ubtide-card-bg)] rounded-[var(--ubtide-border-radius)] shadow-[var(--ubtide-shadow)] overflow-hidden border-[length:var(--ubtide-card-border-width)] border-[color:var(--ubtide-card-border-color)]">
      {/* Header */}
      <div className="px-2.5 py-2 bg-[var(--ubtide-header-bg)] text-[var(--ubtide-header-text)] flex justify-between items-center border-b-[length:var(--ubtide-card-border-width)] border-[color:var(--ubtide-card-border-color)]">
        <div className="text-[0.6rem] font-bold tracking-wide">
          {formatDate(dayStart, timeZone)}
        </div>
      </div>

      {/* Sun/Moon info bar */}
      <div className="flex justify-between items-center px-2.5 py-2 bg-[var(--ubtide-sun-moon-bg)] border-b border-[var(--ubtide-text-muted)]/20">
        <div className="flex items-center gap-1.5">
          <SunIcon color="var(--ubtide-sun-color)" size={16} />
          <div>
            <div className="text-[0.5rem] text-[var(--ubtide-text-muted)] tracking-wide">DAYLIGHT</div>
            <div className="text-[0.7rem] font-bold text-[var(--ubtide-sun-color)]">
              {sunTimes.dayLength ? `${sunTimes.dayLength.hours}h ${sunTimes.dayLength.minutes}m` : '--'}
            </div>
          </div>
        </div>
        <div className="flex items-center gap-1.5">
          <span className="text-lg">{moonPhase.emoji}</span>
          <div className="text-right">
            <div className="text-[0.5rem] text-[var(--ubtide-text-muted)] tracking-wide">MOON</div>
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
                i < events.length - 1 ? 'border-b border-[var(--ubtide-text-muted)]/10' : ''
              } ${isSun ? 'bg-[var(--ubtide-sun-moon-bg)]' : ''}`}
            >
              {/* Event type badge */}
              <span
                className={`text-[0.55rem] font-bold py-0.5 w-9 text-center rounded-[var(--ubtide-border-radius)] ${
                  isSun
                    ? 'bg-[var(--ubtide-sun-moon-bg)] text-[var(--ubtide-sun-color)] border-2 border-[var(--ubtide-sun-color)]'
                    : e.type === 'high'
                      ? 'bg-[var(--ubtide-high-bg)] text-[var(--ubtide-high-text)] border-2 border-transparent'
                      : 'bg-[var(--ubtide-low-bg)] text-[var(--ubtide-low-text)] border-2 border-[var(--ubtide-low-border)]'
                }`}
              >
                {isSun ? (e.type === 'sunrise' ? 'RISE' : 'SET') : e.type.toUpperCase()}
              </span>

              {/* Time */}
              <span className="text-base font-bold">{formatTime(e.time, timeZone)}</span>

              {/* Details */}
              {isSun ? (
                <div className="text-xs text-[var(--ubtide-sun-color)] font-semibold flex items-center gap-1.5">
                  {e.type === 'sunrise' ? (
                    <SunriseIcon color="var(--ubtide-sun-color)" size={18} />
                  ) : (
                    <SunsetIcon color="var(--ubtide-sun-color)" size={18} />
                  )}
                  {e.type === 'sunrise' ? 'Sunrise' : 'Sunset'}
                </div>
              ) : (
                <div className="flex items-center gap-2">
                  <span className="text-sm text-[var(--ubtide-text-muted)] min-w-[38px]">
                    {(e as TideExtreme).height.toFixed(1)}m
                  </span>
                  <div className="flex-1 h-1.5 bg-[var(--ubtide-bar-bg)] rounded-[var(--ubtide-border-radius)] overflow-hidden">
                    <div
                      className="h-full bg-[var(--ubtide-bar-fill)] rounded-[var(--ubtide-border-radius)]"
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
      <div className="px-2.5 py-1.5 text-[0.5rem] text-[var(--ubtide-text-muted)] text-center border-t border-[var(--ubtide-text-muted)]/10">
        CALCULATED · ±5 MIN TYPICAL ACCURACY
      </div>
    </div>
  )
}
