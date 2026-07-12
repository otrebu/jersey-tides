import { useMemo } from 'react'
import { formatTime } from '@u-b/tides-core'
import type { CalendarDay } from '@u-b/tides-core'
import { getMonthMoonPhaseEvents } from '@u-b/tides-core/almanac'
import { DAYS, MONTHS } from './labels.ts'

export interface CalendarProps {
  year: number
  /** 0-based month */
  month0: number
  selected: CalendarDay | null
  today: CalendarDay | null
  timeZone: string
  onSelect: (day: CalendarDay) => void
  onNavigateMonth: (delta: number) => void
}

function sameDay(a: CalendarDay, b: CalendarDay | null): boolean {
  return b !== null && a.year === b.year && a.month === b.month && a.day === b.day
}

export function Calendar({ year, month0, selected, today, timeZone, onSelect, onNavigateMonth }: CalendarProps) {
  const cells = useMemo(() => {
    const pad = (new Date(Date.UTC(year, month0, 1)).getUTCDay() + 6) % 7
    const count = new Date(Date.UTC(year, month0 + 1, 0)).getUTCDate()
    const days: (number | null)[] = []
    for (let i = 0; i < pad; i++) days.push(null)
    for (let d = 1; d <= count; d++) days.push(d)
    return days
  }, [year, month0])

  // Exact moon phase events (only major phases: New, First Quarter, Full, Last Quarter)
  const moonPhaseEvents = useMemo(
    () => getMonthMoonPhaseEvents(year, month0, timeZone),
    [year, month0, timeZone]
  )

  return (
    <div className="ubtide-calendar w-full bg-[var(--ubtide-card-bg)] rounded-[var(--ubtide-border-radius)] shadow-[var(--ubtide-shadow)] overflow-hidden border-[length:var(--ubtide-card-border-width)] border-[color:var(--ubtide-card-border-color)]">
      {/* Month navigation header */}
      <div className="flex justify-between items-center px-2.5 py-2 bg-[var(--ubtide-header-bg)] text-[var(--ubtide-header-text)] border-b-[length:var(--ubtide-card-border-width)] border-[color:var(--ubtide-card-border-color)]">
        <button
          onClick={() => onNavigateMonth(-1)}
          className="bg-transparent border-none text-inherit text-sm cursor-pointer px-1.5 py-0.5"
        >
          ◀
        </button>
        <span className="text-[0.7rem] md:text-sm font-bold tracking-wider">
          {MONTHS[month0]} {year}
        </span>
        <button
          onClick={() => onNavigateMonth(1)}
          className="bg-transparent border-none text-inherit text-sm cursor-pointer px-1.5 py-0.5"
        >
          ▶
        </button>
      </div>

      {/* Day of week headers */}
      <div className="grid grid-cols-7 border-b border-[var(--ubtide-text-muted)]/25">
        {DAYS.map((d, i) => (
          <div key={i} className="text-center p-1.5 text-[0.6rem] font-bold text-[var(--ubtide-text-muted)]">
            {d}
          </div>
        ))}
      </div>

      {/* Calendar grid */}
      <div className="grid grid-cols-7">
        {cells.map((day, i) => {
          // Only show emoji if a major phase event occurs on this day
          const phaseEvent = day ? moonPhaseEvents.get(day) : undefined
          const cellDay: CalendarDay | null = day ? { year, month: month0 + 1, day } : null
          const isSelected = cellDay && sameDay(cellDay, selected)
          const isTodayDate = cellDay && sameDay(cellDay, today)

          return (
            <button
              key={i}
              onClick={() => cellDay && onSelect(cellDay)}
              disabled={!day}
              className={`aspect-square border-none text-[0.7rem] flex flex-col items-center justify-center gap-px p-0.5 ${
                isSelected
                  ? 'bg-[var(--ubtide-selected-bg)] text-[var(--ubtide-selected-text)] font-bold'
                  : day
                    ? 'bg-[var(--ubtide-card-bg)] text-[var(--ubtide-text)] cursor-pointer'
                    : 'bg-[var(--ubtide-text-muted)]/5 cursor-default'
              } ${isTodayDate && !isSelected ? 'font-bold shadow-[inset_0_0_0_2px_var(--ubtide-today-border)]' : ''}`}
              title={phaseEvent ? `${phaseEvent.name} at ${formatTime(phaseEvent.time, timeZone)}` : undefined}
            >
              <span>{day || ''}</span>
              {phaseEvent && (
                <span className={`text-[0.55rem] leading-none ${isSelected ? 'opacity-100' : 'opacity-60'}`}>
                  {phaseEvent.emoji}
                </span>
              )}
            </button>
          )
        })}
      </div>
    </div>
  )
}
