/**
 * Thin shim over @u-b/tides-core/almanac preserving the app's original
 * signatures (Jersey defaults baked in).
 */

import {
  getMonthMoonPhaseEvents as almanacMonthMoonPhaseEvents,
  getSunTimes as almanacSunTimes,
} from '@u-b/tides-core/almanac';
import type { MoonPhaseEvent, SunTimes } from '@u-b/tides-core/almanac';

export { getMoonPhase, getMoonPhaseEvents } from '@u-b/tides-core/almanac';
export type { MoonPhaseEvent, MoonPhaseInfo, SunTimes } from '@u-b/tides-core/almanac';

export function getSunTimes(date: Date): SunTimes {
  return almanacSunTimes(date);
}

export function getMonthMoonPhaseEvents(
  year: number,
  month: number
): Map<number, MoonPhaseEvent> {
  return almanacMonthMoonPhaseEvents(year, month, 'Europe/Jersey');
}
