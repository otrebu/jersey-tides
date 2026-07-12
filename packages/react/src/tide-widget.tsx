import { useState, useEffect, useMemo } from 'react'
import { calendarDayOf, dayBoundsUtc } from '@u-b/tides-core'
import type { CalendarDay, Station } from '@u-b/tides-core'
import { getSunTimes, getMoonPhase } from '@u-b/tides-core/almanac'
import { stHelier } from '@u-b/tides-core/stations/st-helier'
import { CurrentLevel } from './current-level.tsx'
import { Calendar } from './calendar.tsx'
import { TideCurve } from './tide-curve.tsx'
import { TideEvents } from './tide-events.tsx'
import { themeToStyle } from './theme.ts'
import type { TideTheme } from './theme.ts'

export interface TideWidgetProps {
  station?: Station
  /** Day to show initially; defaults to `now`'s day, or today (resolved after mount) */
  initialDate?: Date
  /** Fixed clock for deterministic rendering; omit for a live 60s clock started on mount */
  now?: Date
  theme?: Partial<TideTheme>
  className?: string
  showCalendar?: boolean
  showEvents?: boolean
}

function sameDay(a: CalendarDay | null, b: CalendarDay | null): boolean {
  return a !== null && b !== null && a.year === b.year && a.month === b.month && a.day === b.day
}

export function TideWidget({
  station = stHelier,
  initialDate,
  now,
  theme,
  className,
  showCalendar = true,
  showEvents = true
}: TideWidgetProps) {
  const tz = station.timeZone
  const [tick, setTick] = useState<Date | null>(null)
  const [selected, setSelected] = useState<CalendarDay | null>(() => {
    const base = initialDate ?? now
    return base ? calendarDayOf(base, tz) : null
  })
  const [view, setView] = useState<{ year: number; month0: number } | null>(() => {
    const base = initialDate ?? now
    if (!base) return null
    const d = calendarDayOf(base, tz)
    return { year: d.year, month0: d.month - 1 }
  })

  useEffect(() => {
    if (now) return
    setTick(new Date())
    const interval = setInterval(() => setTick(new Date()), 60000)
    return () => clearInterval(interval)
  }, [now])

  const time = now ?? tick
  const today = time ? calendarDayOf(time, tz) : null
  const day = selected ?? today
  const viewYm = view ?? (day ? { year: day.year, month0: day.month - 1 } : null)
  const dayKey = day ? `${day.year}-${day.month}-${day.day}` : null

  const bounds = useMemo(
    () => (day ? dayBoundsUtc(day, tz) : null),
    [dayKey, tz]
  )
  const extremes = useMemo(
    () => (day ? station.dayExtremes(day) : []),
    [station, dayKey]
  )
  const sunTimes = useMemo(
    () =>
      day
        ? getSunTimes(day, { latitude: station.latitude, longitude: station.longitude, timeZone: tz })
        : null,
    [station, dayKey]
  )
  const moonPhase = useMemo(() => (bounds ? getMoonPhase(bounds.start) : null), [bounds])

  const isTodaySelected = sameDay(day, today)
  const currentLevel = useMemo(
    () => (isTodaySelected && time ? station.currentLevel(time) : null),
    [station, isTodaySelected, time]
  )

  const navigateMonth = (delta: number) => {
    if (!viewYm) return
    const total = viewYm.year * 12 + viewYm.month0 + delta
    setView({ year: Math.floor(total / 12), month0: ((total % 12) + 12) % 12 })
  }

  const lat = station.latitude
  const lon = station.longitude
  const coords = `${Math.abs(lat).toFixed(2)}°${lat >= 0 ? 'N' : 'S'} · ${Math.abs(lon).toFixed(2)}°${lon >= 0 ? 'E' : 'W'}`

  return (
    <div
      className={className ? `ubtide ${className}` : 'ubtide'}
      style={theme ? themeToStyle(theme) : undefined}
    >
      <div className="flex flex-col items-center">
        <header className="text-center mb-2">
          <h1 className="text-2xl md:text-3xl font-black tracking-widest m-0 pb-1 border-b-[3px] border-[color:var(--ubtide-border-strong)] text-[var(--ubtide-text)]">
            {station.name.toUpperCase()}
          </h1>
          <div className="text-[0.55rem] md:text-xs text-[var(--ubtide-text-muted)] tracking-wider mt-1">
            TIDES · SUN · MOON
          </div>
        </header>

        <CurrentLevel
          currentLevel={currentLevel}
          isToday={isTodaySelected}
          dayStart={bounds?.start ?? null}
          timeZone={tz}
          moonPhase={moonPhase}
          extremes={extremes}
        />

        {showCalendar &&
          (viewYm ? (
            <Calendar
              year={viewYm.year}
              month0={viewYm.month0}
              selected={day}
              today={today}
              timeZone={tz}
              onSelect={setSelected}
              onNavigateMonth={navigateMonth}
            />
          ) : (
            <div className="ubtide-calendar w-full" />
          ))}

        <div className="ubtide-curve w-full mt-2 p-2 bg-[var(--ubtide-card-bg)] rounded-[var(--ubtide-border-radius)] shadow-[var(--ubtide-shadow)] border-[length:var(--ubtide-card-border-width)] border-[color:var(--ubtide-card-border-color)]">
          {bounds && sunTimes && (
            <TideCurve
              extremes={extremes}
              dayStart={bounds.start}
              dayEnd={bounds.end}
              currentTime={time}
              isToday={isTodaySelected}
              sunTimes={sunTimes}
            />
          )}
        </div>

        {showEvents &&
          (bounds && sunTimes && moonPhase ? (
            <TideEvents
              extremes={extremes}
              sunTimes={sunTimes}
              moonPhase={moonPhase}
              dayStart={bounds.start}
              timeZone={tz}
            />
          ) : (
            <div className="ubtide-events w-full" />
          ))}

        <footer className="mt-2 text-[0.5rem] md:text-xs text-[var(--ubtide-text-muted)] text-center">
          {coords} · DATUM: LAT
        </footer>
      </div>
    </div>
  )
}
