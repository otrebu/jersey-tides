import { useMemo } from 'react'
import { getMonthMoonPhaseEvents, type MoonPhaseEvent } from '@/lib/astronomy'
import { DAYS, MONTHS } from '@/lib/labels'
import { isSameDay, isToday } from '@/lib/utils'

interface CalendarProps {
  currentDate: Date
  selectedDate: Date
  onSelectDate: (date: Date) => void
  onNavigateMonth: (delta: number) => void
}

export function Calendar({ currentDate, selectedDate, onSelectDate, onNavigateMonth }: CalendarProps) {
  const calendarData = useMemo(() => {
    const year = currentDate.getFullYear()
    const month = currentDate.getMonth()
    const first = new Date(year, month, 1)
    const last = new Date(year, month + 1, 0)
    const pad = (first.getDay() + 6) % 7
    const days: (Date | null)[] = []

    for (let i = 0; i < pad; i++) days.push(null)
    for (let i = 1; i <= last.getDate(); i++) {
      days.push(new Date(year, month, i))
    }

    return days
  }, [currentDate])

  // Get exact moon phase events (only major phases: New, First Quarter, Full, Last Quarter)
  const moonPhaseEvents = useMemo(() => {
    const year = currentDate.getFullYear()
    const month = currentDate.getMonth()
    return getMonthMoonPhaseEvents(year, month)
  }, [currentDate])

  return (
    <div className="w-full max-w-[360px] md:max-w-[480px] lg:max-w-[540px] bg-[var(--card-bg)] rounded-[var(--border-radius)] shadow-[var(--shadow)] overflow-hidden border-[var(--card-border)]">
      {/* Month navigation header */}
      <div className="flex justify-between items-center px-2.5 py-2 bg-[var(--header-bg)] text-[var(--header-text)] border-b-[var(--card-border)]">
        <button
          onClick={() => onNavigateMonth(-1)}
          className="bg-transparent border-none text-inherit text-sm cursor-pointer px-1.5 py-0.5"
        >
          ◀
        </button>
        <span className="text-[0.7rem] md:text-sm font-bold tracking-wider">
          {MONTHS[currentDate.getMonth()]} {currentDate.getFullYear()}
        </span>
        <button
          onClick={() => onNavigateMonth(1)}
          className="bg-transparent border-none text-inherit text-sm cursor-pointer px-1.5 py-0.5"
        >
          ▶
        </button>
      </div>

      {/* Day of week headers */}
      <div className="grid grid-cols-7 border-b border-[var(--text-muted)]/25">
        {DAYS.map((d, i) => (
          <div key={i} className="text-center p-1.5 text-[0.6rem] font-bold text-[var(--text-muted)]">
            {d}
          </div>
        ))}
      </div>

      {/* Calendar grid */}
      <div className="grid grid-cols-7">
        {calendarData.map((date, i) => {
          const day = date?.getDate()
          // Only show emoji if a major phase event occurs on this day
          const phaseEvent = day ? moonPhaseEvents.get(day) : undefined
          const isSelected = date && isSameDay(date, selectedDate)
          const isTodayDate = date && isToday(date)

          return (
            <button
              key={i}
              onClick={() => date && onSelectDate(date)}
              disabled={!date}
              className={`aspect-square border-none text-[0.7rem] flex flex-col items-center justify-center gap-px p-0.5 ${
                isSelected
                  ? 'bg-[var(--selected-bg)] text-[var(--selected-text)] font-bold'
                  : date
                    ? 'bg-[var(--card-bg)] text-[var(--text)] cursor-pointer'
                    : 'bg-[var(--text-muted)]/5 cursor-default'
              } ${isTodayDate && !isSelected ? 'font-bold shadow-[inset_0_0_0_2px_var(--today-border)]' : ''}`}
              title={phaseEvent ? `${phaseEvent.name} at ${phaseEvent.time.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}` : undefined}
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
