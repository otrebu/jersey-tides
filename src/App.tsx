import { useState, useEffect, useMemo } from 'react'
import { getDayExtremes, getCurrentLevel } from '@/lib/tides'
import { getSunTimes, getMoonPhase } from '@/lib/astronomy'
import { isToday as checkIsToday } from '@/lib/utils'
import { CurrentLevel } from '@/components/current-level'
import { Calendar } from '@/components/calendar'
import { TideCurve } from '@/components/tide-curve'
import { TideEvents } from '@/components/tide-events'

export default function App() {
  const [currentDate, setCurrentDate] = useState(new Date())
  const [selectedDate, setSelectedDate] = useState(new Date())
  const [currentTime, setCurrentTime] = useState(new Date())

  useEffect(() => {
    const interval = setInterval(() => setCurrentTime(new Date()), 60000)
    return () => clearInterval(interval)
  }, [])

  const extremes = useMemo(() => getDayExtremes(selectedDate), [selectedDate])
  const isTodaySelected = checkIsToday(selectedDate)
  const currentLevel = useMemo(
    () => (isTodaySelected ? getCurrentLevel(currentTime) : null),
    [isTodaySelected, currentTime]
  )
  const sunTimes = useMemo(() => getSunTimes(selectedDate), [selectedDate])
  const moonPhase = useMemo(() => getMoonPhase(selectedDate), [selectedDate])

  const navigateMonth = (delta: number) => {
    setCurrentDate(new Date(currentDate.getFullYear(), currentDate.getMonth() + delta, 1))
  }

  return (
    <div className="min-h-screen bg-[var(--bg)] p-4 text-[var(--text)]">
      <div className="flex flex-col items-center">
        <header className="text-center mb-2">
          <h1 className="text-2xl font-black tracking-widest m-0 pb-1 border-b-[3px] border-[#111] text-[var(--text)]">
            JERSEY TIDES
          </h1>
          <div className="text-[0.55rem] text-[var(--text-muted)] tracking-wider mt-1">
            ST. HELIER · TIDES · SUN · MOON
          </div>
        </header>

        <CurrentLevel
          currentLevel={currentLevel}
          isToday={isTodaySelected}
          selectedDate={selectedDate}
          moonPhase={moonPhase}
          extremes={extremes}
        />

        <Calendar
          currentDate={currentDate}
          selectedDate={selectedDate}
          onSelectDate={setSelectedDate}
          onNavigateMonth={navigateMonth}
        />

        <div className="w-full max-w-[360px] mt-2 p-2 bg-[var(--card-bg)] rounded-[var(--border-radius)] shadow-[var(--shadow)] border-[var(--card-border)]">
          <TideCurve
            extremes={extremes}
            currentTime={currentTime}
            isToday={isTodaySelected}
            sunTimes={sunTimes}
          />
        </div>

        <TideEvents
          extremes={extremes}
          sunTimes={sunTimes}
          moonPhase={moonPhase}
          selectedDate={selectedDate}
        />

        <footer className="mt-2 text-[0.5rem] text-[var(--text-muted)] text-center">
          49.21°N · 2.14°W · DATUM: LAT
        </footer>
      </div>
    </div>
  )
}
