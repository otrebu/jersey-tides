/**
 * Timezone-correct calendar-day handling. All UTC<->local conversion in this
 * package flows through tzOffsetMinutes below.
 */

export interface CalendarDay {
  year: number
  /** 1-12 */
  month: number
  day: number
}

const formatters = new Map<string, Intl.DateTimeFormat>()

/**
 * Offset of `timeZone` from UTC at the instant `utc`, in minutes (positive
 * east of Greenwich). This is the ONLY place the package touches Intl for
 * timezone math — swap this implementation (e.g. for a Scriptable DST table
 * fallback) and everything else follows.
 *
 * Gate 1 (2026-07-12): verified on-device in Scriptable (iOS JavaScriptCore)
 * via targets/scriptable/probe/IntlProbe.js — 9/9 PASS across the 2026 and
 * 2027 Europe/Jersey DST boundaries, including the h23 midnight case. Intl
 * is safe on iOS; no closed-form UK-DST fallback needed.
 */
export function tzOffsetMinutes(utc: Date, timeZone: string): number {
  let dtf = formatters.get(timeZone)
  if (!dtf) {
    dtf = new Intl.DateTimeFormat('en-US', {
      timeZone,
      year: 'numeric',
      month: 'numeric',
      day: 'numeric',
      hour: 'numeric',
      minute: 'numeric',
      second: 'numeric',
      hourCycle: 'h23'
    })
    formatters.set(timeZone, dtf)
  }
  const fields: Record<string, number> = {}
  for (const part of dtf.formatToParts(utc)) {
    if (part.type !== 'literal') fields[part.type] = Number(part.value)
  }
  const localAsUtc = Date.UTC(fields.year, fields.month - 1, fields.day, fields.hour, fields.minute, fields.second)
  return Math.round((localAsUtc - utc.getTime()) / 60000)
}

/** Calendar day that the instant `date` falls on in `timeZone`. */
export function calendarDayOf(date: Date, timeZone: string): CalendarDay {
  const shifted = new Date(date.getTime() + tzOffsetMinutes(date, timeZone) * 60000)
  return { year: shifted.getUTCFullYear(), month: shifted.getUTCMonth() + 1, day: shifted.getUTCDate() }
}

// Local midnight as a UTC instant, with the two-pass offset fixup: guess with
// the offset at the naive instant, recompute at the guess, adjust if a DST
// transition moved the offset between the two.
function localMidnightUtc(day: CalendarDay, timeZone: string): Date {
  const naive = Date.UTC(day.year, day.month - 1, day.day)
  const offsetAtGuess = tzOffsetMinutes(new Date(naive), timeZone)
  let ts = naive - offsetAtGuess * 60000
  const offsetAtResult = tzOffsetMinutes(new Date(ts), timeZone)
  if (offsetAtResult !== offsetAtGuess) ts = naive - offsetAtResult * 60000
  return new Date(ts)
}

/** UTC instants of local midnight and the next local midnight in `timeZone`. */
export function dayBoundsUtc(day: CalendarDay, timeZone: string): { start: Date; end: Date } {
  return { start: localMidnightUtc(day, timeZone), end: localMidnightUtc(addDays(day, 1), timeZone) }
}

/** True when both instants fall on the same calendar day in `timeZone`. */
export function sameCalendarDay(a: Date, b: Date, timeZone: string): boolean {
  const da = calendarDayOf(a, timeZone)
  const db = calendarDayOf(b, timeZone)
  return da.year === db.year && da.month === db.month && da.day === db.day
}

/** Normalize a Date (interpreted in `timeZone`) or CalendarDay to a CalendarDay. */
export function toDay(input: Date | CalendarDay, timeZone: string): CalendarDay {
  return input instanceof Date ? calendarDayOf(input, timeZone) : input
}

/** Shift a calendar day by whole days (pure calendar arithmetic, no timezone). */
export function addDays(day: CalendarDay, delta: number): CalendarDay {
  const shifted = new Date(Date.UTC(day.year, day.month - 1, day.day + delta))
  return { year: shifted.getUTCFullYear(), month: shifted.getUTCMonth() + 1, day: shifted.getUTCDate() }
}

/** HH:MM in `timeZone`. */
export function formatTime(date: Date, timeZone: string, locale = 'en-GB'): string {
  return date.toLocaleTimeString(locale, { timeZone, hour: '2-digit', minute: '2-digit' })
}

/** Uppercased short date in `timeZone`, e.g. "FRI, 11 JUL 2026". */
export function formatDate(date: Date, timeZone: string, locale = 'en-GB'): string {
  return date
    .toLocaleDateString(locale, { timeZone, weekday: 'short', day: 'numeric', month: 'short', year: 'numeric' })
    .toUpperCase()
}
