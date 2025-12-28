/**
 * Astronomy utilities using astronomy-engine library
 * Provides sun times and moon phase calculations
 */

import {
  Body,
  Observer,
  SearchRiseSet,
  MoonPhase,
  Illumination,
  SearchMoonPhase,
} from 'astronomy-engine';

// Default coordinates for Jersey
export const JERSEY_LAT = 49.2138;
export const JERSEY_LON = -2.1358;

// Types
export interface SunTimes {
  sunrise: Date | null;
  sunset: Date | null;
  dayLength: { hours: number; minutes: number } | null;
}

export interface MoonPhaseInfo {
  phaseAngle: number;
  name: string;
  emoji: string;
  illumination: number;
}

export interface MoonPhaseEvent {
  type: 'new' | 'first_quarter' | 'full' | 'last_quarter';
  name: string;
  emoji: string;
  time: Date;
}

/**
 * Calculate sunrise, sunset, and day length for a given date and location
 * @param date - The date to calculate sun times for
 * @param lat - Latitude (default: Jersey)
 * @param lon - Longitude (default: Jersey)
 * @returns Object with sunrise, sunset, and dayLength
 */
export function getSunTimes(
  date: Date,
  lat: number = JERSEY_LAT,
  lon: number = JERSEY_LON
): SunTimes {
  // Create observer at the given location (height = 0 meters)
  const observer = new Observer(lat, lon, 0);

  // Set search date to start of day
  const startOfDay = new Date(date);
  startOfDay.setHours(0, 0, 0, 0);

  // Search for sunrise (direction = +1 for rise)
  const sunriseResult = SearchRiseSet(
    Body.Sun,
    observer,
    +1, // rise
    startOfDay,
    1 // search within 1 day
  );

  // Search for sunset (direction = -1 for set)
  const sunsetResult = SearchRiseSet(
    Body.Sun,
    observer,
    -1, // set
    startOfDay,
    1 // search within 1 day
  );

  const sunrise = sunriseResult ? sunriseResult.date : null;
  const sunset = sunsetResult ? sunsetResult.date : null;

  // Calculate day length
  let dayLength: { hours: number; minutes: number } | null = null;
  if (sunrise && sunset) {
    const diff = sunset.getTime() - sunrise.getTime();
    dayLength = {
      hours: Math.floor(diff / (1000 * 60 * 60)),
      minutes: Math.round((diff % (1000 * 60 * 60)) / (1000 * 60))
    };
  }

  return { sunrise, sunset, dayLength };
}

/**
 * Calculate moon phase information for a given date
 * @param date - The date to calculate moon phase for
 * @returns Object with phaseAngle, name, emoji, and illumination
 */
export function getMoonPhase(date: Date): MoonPhaseInfo {
  // Get moon phase angle (0-360 degrees)
  const phaseAngle = MoonPhase(date);

  // Get illumination fraction
  const illuminationResult = Illumination(Body.Moon, date);
  const illumination = Math.round(illuminationResult.phase_fraction * 100);

  // Determine phase name and emoji based on phase angle
  // Use tight ranges for major phases (~1 day = ~12°), rest are transitional
  let name: string;
  let emoji: string;

  if (phaseAngle < 6 || phaseAngle >= 354) {
    // New Moon: within ~12 hours of 0°
    name = 'New Moon';
    emoji = '🌑';
  } else if (phaseAngle < 84) {
    name = 'Waxing Crescent';
    emoji = '🌒';
  } else if (phaseAngle < 96) {
    // First Quarter: within ~12 hours of 90°
    name = 'First Quarter';
    emoji = '🌓';
  } else if (phaseAngle < 174) {
    name = 'Waxing Gibbous';
    emoji = '🌔';
  } else if (phaseAngle < 186) {
    // Full Moon: within ~12 hours of 180°
    name = 'Full Moon';
    emoji = '🌕';
  } else if (phaseAngle < 264) {
    name = 'Waning Gibbous';
    emoji = '🌖';
  } else if (phaseAngle < 276) {
    // Last Quarter: within ~12 hours of 270°
    name = 'Last Quarter';
    emoji = '🌗';
  } else {
    name = 'Waning Crescent';
    emoji = '🌘';
  }

  return { phaseAngle, name, emoji, illumination };
}

/**
 * Find exact times of major moon phases within a date range
 * Uses SearchMoonPhase to find precise times when phases occur
 * @param startDate - Start of search range
 * @param endDate - End of search range (defaults to 30 days from start)
 * @returns Array of moon phase events with exact times
 */
export function getMoonPhaseEvents(
  startDate: Date,
  endDate?: Date
): MoonPhaseEvent[] {
  const end = endDate || new Date(startDate.getTime() + 30 * 24 * 60 * 60 * 1000);
  const events: MoonPhaseEvent[] = [];

  // Phase angles: 0 = New, 90 = First Quarter, 180 = Full, 270 = Last Quarter
  const phases: Array<{ angle: number; type: MoonPhaseEvent['type']; name: string; emoji: string }> = [
    { angle: 0, type: 'new', name: 'New Moon', emoji: '🌑' },
    { angle: 90, type: 'first_quarter', name: 'First Quarter', emoji: '🌓' },
    { angle: 180, type: 'full', name: 'Full Moon', emoji: '🌕' },
    { angle: 270, type: 'last_quarter', name: 'Last Quarter', emoji: '🌗' },
  ];

  for (const phase of phases) {
    // Search for this phase starting from startDate
    let searchStart = new Date(startDate);

    while (searchStart < end) {
      const result = SearchMoonPhase(phase.angle, searchStart, 30);

      if (!result || result.date > end) break;

      events.push({
        type: phase.type,
        name: phase.name,
        emoji: phase.emoji,
        time: result.date,
      });

      // Move search start past this result (add 1 day buffer)
      searchStart = new Date(result.date.getTime() + 24 * 60 * 60 * 1000);
    }
  }

  // Sort events by time
  events.sort((a, b) => a.time.getTime() - b.time.getTime());

  return events;
}

/**
 * Get moon phase events for a specific month
 * @param year - Year
 * @param month - Month (0-11)
 * @returns Map of day number to moon phase event occurring on that day
 */
export function getMonthMoonPhaseEvents(
  year: number,
  month: number
): Map<number, MoonPhaseEvent> {
  const startDate = new Date(year, month, 1);
  const endDate = new Date(year, month + 1, 0, 23, 59, 59);

  const events = getMoonPhaseEvents(startDate, endDate);
  const eventsByDay = new Map<number, MoonPhaseEvent>();

  for (const event of events) {
    // Convert to local day
    const day = event.time.getDate();
    eventsByDay.set(day, event);
  }

  return eventsByDay;
}
