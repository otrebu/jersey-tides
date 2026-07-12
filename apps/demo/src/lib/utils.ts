import {
  formatDate as coreFormatDate,
  formatTime as coreFormatTime,
  sameCalendarDay
} from '@u-b/tides-core'

const TIME_ZONE = 'Europe/Jersey'

/**
 * Format a Date to HH:MM time string (Jersey local time)
 */
export function formatTime(date: Date): string {
  return coreFormatTime(date, TIME_ZONE)
}

/**
 * Format a Date to a readable date string (Jersey local time)
 */
export function formatDate(date: Date): string {
  return coreFormatDate(date, TIME_ZONE)
}

/**
 * Check if two dates are the same calendar day in Jersey
 */
export function isSameDay(a: Date, b: Date): boolean {
  return sameCalendarDay(a, b, TIME_ZONE)
}

/**
 * Check if date is today in Jersey
 */
export function isToday(date: Date): boolean {
  return isSameDay(date, new Date())
}
