/**
 * Zero-dependency astronomical almanac. Sun rise/set from the NOAA solar
 * calculator (fractional-century solar position, equation of time, hour angle
 * at zenith 90.833°). Moon phase angle from Meeus "Astronomical Algorithms":
 * Sun longitude ch.25 low-precision, Moon longitude ch.47 main periodic
 * terms. Quadrature times from Meeus ch.49 "Phases of the Moon". All
 * civil-day handling is timezone-explicit via ./time.ts.
 */

import { calendarDayOf, dayBoundsUtc, toDay } from './time.ts'
import type { CalendarDay } from './time.ts'

export interface SunTimes {
  sunrise: Date | null
  sunset: Date | null
  dayLength: { hours: number; minutes: number } | null
}

export interface MoonPhaseInfo {
  phaseAngle: number
  name: string
  emoji: string
  illumination: number
}

export interface MoonPhaseEvent {
  type: 'new' | 'first_quarter' | 'full' | 'last_quarter'
  name: string
  emoji: string
  time: Date
}

export interface AlmanacOptions {
  latitude?: number
  longitude?: number
  timeZone?: string
}

const DEFAULT_LATITUDE = 49.183
const DEFAULT_LONGITUDE = -2.117
const DEFAULT_TIME_ZONE = 'Europe/Jersey'

const DEG = Math.PI / 180
const DAY_MS = 86400000
const J2000_JD = 2451545
const UNIX_EPOCH_JD = 2440587.5

const norm360 = (deg: number) => ((deg % 360) + 360) % 360

// TT-UT in seconds, Espenak & Meeus 2005-2050 polynomial. Within a few
// seconds of the observed value this decade; the parity tolerances here are
// minutes, so the residual is irrelevant.
function deltaTSeconds(utcMs: number): number {
  const y = 1970 + utcMs / 31556952000
  const t = y - 2000
  return 62.92 + 0.32217 * t + 0.005589 * t * t
}

// Julian centuries of Terrestrial Time since J2000.0 for a UTC instant.
function centuriesTT(utcMs: number): number {
  const jd = (utcMs + deltaTSeconds(utcMs) * 1000) / DAY_MS + UNIX_EPOCH_JD
  return (jd - J2000_JD) / 36525
}

// --- Sun: NOAA solar calculator ---------------------------------------------

// Geometric geocentric ecliptic longitude of the Sun (Meeus ch.25), degrees.
function sunLongitude(T: number): number {
  const L0 = 280.46646 + T * (36000.76983 + T * 0.0003032)
  const M = (357.52911 + T * (35999.05029 - T * 0.0001537)) * DEG
  const C =
    (1.914602 - T * (0.004817 + T * 0.000014)) * Math.sin(M) +
    (0.019993 - T * 0.000101) * Math.sin(2 * M) +
    0.000289 * Math.sin(3 * M)
  return norm360(L0 + C)
}

// Solar declination (radians) and equation of time (minutes) — the two
// quantities the NOAA sunrise/sunset formula needs.
function solarCoords(T: number): { declRad: number; eqTimeMin: number } {
  const L0 = norm360(280.46646 + T * (36000.76983 + T * 0.0003032))
  const M = norm360(357.52911 + T * (35999.05029 - T * 0.0001537))
  const e = 0.016708634 - T * (0.000042037 + T * 0.0000001267)
  const Mr = M * DEG
  const C =
    (1.914602 - T * (0.004817 + T * 0.000014)) * Math.sin(Mr) +
    (0.019993 - T * 0.000101) * Math.sin(2 * Mr) +
    0.000289 * Math.sin(3 * Mr)
  const omega = (125.04 - 1934.136 * T) * DEG
  const lambda = (L0 + C - 0.00569 - 0.00478 * Math.sin(omega)) * DEG
  const eps0 = 23 + (26 + (21.448 - T * (46.815 + T * (0.00059 - T * 0.001813))) / 60) / 60
  const eps = (eps0 + 0.00256 * Math.cos(omega)) * DEG
  const declRad = Math.asin(Math.sin(eps) * Math.sin(lambda))
  const y = Math.tan(eps / 2) ** 2
  const L0r = L0 * DEG
  const eqTimeMin =
    (4 / DEG) *
    (y * Math.sin(2 * L0r) -
      2 * e * Math.sin(Mr) +
      4 * e * y * Math.sin(Mr) * Math.cos(2 * L0r) -
      0.5 * y * y * Math.sin(4 * L0r) -
      1.25 * e * e * Math.sin(2 * Mr))
  return { declRad, eqTimeMin }
}

const ZENITH_COS = Math.cos(90.833 * DEG)

// Sunrise or sunset (UTC ms) attributed to the UTC day starting at
// utcMidnightMs, or null when the sun never crosses the horizon. Iterated so
// declination and equation of time are evaluated at the event itself.
function solarEventUtcMs(
  utcMidnightMs: number,
  latitude: number,
  longitude: number,
  rise: boolean
): number | null {
  const latR = latitude * DEG
  let minutes = 720 - 4 * longitude
  for (let i = 0; i < 3; i++) {
    const { declRad, eqTimeMin } = solarCoords(centuriesTT(utcMidnightMs + minutes * 60000))
    const cosHa = (ZENITH_COS - Math.sin(latR) * Math.sin(declRad)) / (Math.cos(latR) * Math.cos(declRad))
    if (cosHa < -1 || cosHa > 1) return null
    const haDeg = Math.acos(cosHa) / DEG
    minutes = 720 - 4 * (longitude + (rise ? haDeg : -haDeg)) - eqTimeMin
  }
  return utcMidnightMs + minutes * 60000
}

function solarEventInWindow(
  startMs: number,
  endMs: number,
  latitude: number,
  longitude: number,
  rise: boolean
): Date | null {
  const firstMidnight = Math.floor(startMs / DAY_MS) * DAY_MS
  for (let m = firstMidnight; m < endMs; m += DAY_MS) {
    const t = solarEventUtcMs(m, latitude, longitude, rise)
    if (t !== null && t >= startMs && t < endMs) return new Date(t)
  }
  return null
}

/**
 * Sunrise, sunset and day length within the civil day in `timeZone`.
 * `day` given as a Date is interpreted as the civil day it falls on.
 */
export function getSunTimes(day: Date | CalendarDay, opts: AlmanacOptions = {}): SunTimes {
  const latitude = opts.latitude ?? DEFAULT_LATITUDE
  const longitude = opts.longitude ?? DEFAULT_LONGITUDE
  const timeZone = opts.timeZone ?? DEFAULT_TIME_ZONE
  const { start, end } = dayBoundsUtc(toDay(day, timeZone), timeZone)
  const sunrise = solarEventInWindow(start.getTime(), end.getTime(), latitude, longitude, true)
  const sunset = solarEventInWindow(start.getTime(), end.getTime(), latitude, longitude, false)

  let dayLength: { hours: number; minutes: number } | null = null
  if (sunrise && sunset) {
    const diff = sunset.getTime() - sunrise.getTime()
    dayLength = {
      hours: Math.floor(diff / (1000 * 60 * 60)),
      minutes: Math.round((diff % (1000 * 60 * 60)) / (1000 * 60))
    }
  }

  return { sunrise, sunset, dayLength }
}

// --- Moon longitude: Meeus ch.47 main periodic terms -------------------------

// [D, M, M', F, coefficient in 1e-6 degrees] for Σl (Meeus table 47.A).
// Terms with |M| = 1 are scaled by E, |M| = 2 by E².
const MOON_L_TERMS: ReadonlyArray<readonly [number, number, number, number, number]> = [
  [0, 0, 1, 0, 6288774],
  [2, 0, -1, 0, 1274027],
  [2, 0, 0, 0, 658314],
  [0, 0, 2, 0, 213618],
  [0, 1, 0, 0, -185116],
  [0, 0, 0, 2, -114332],
  [2, 0, -2, 0, 58793],
  [2, -1, -1, 0, 57066],
  [2, 0, 1, 0, 53322],
  [2, -1, 0, 0, 45758],
  [0, 1, -1, 0, -40923],
  [1, 0, 0, 0, -34720],
  [0, 1, 1, 0, -30383],
  [2, 0, 0, -2, 15327],
  [0, 0, 1, 2, -12528],
  [0, 0, 1, -2, 10980],
  [4, 0, -1, 0, 10675],
  [0, 0, 3, 0, 10034],
  [4, 0, -2, 0, 8548],
  [2, 1, -1, 0, -7888],
  [2, 1, 0, 0, -6766],
  [1, 0, -1, 0, -5163],
  [1, 1, 0, 0, 4987],
  [2, -1, 1, 0, 4036],
  [2, 0, 2, 0, 3994],
  [4, 0, 0, 0, 3861],
  [2, 0, -3, 0, 3665],
  [0, 1, -2, 0, -2689],
  [2, 0, -1, 2, -2602],
  [2, -1, -2, 0, 2390],
  [1, 0, 1, 0, -2348],
  [2, -2, 0, 0, 2236],
  [0, 1, 2, 0, -2120],
  [0, 2, 0, 0, -2069],
  [2, -2, -1, 0, 2048],
  [2, 0, 1, -2, -1773],
  [2, 0, 0, 2, -1595],
  [4, -1, -1, 0, 1215],
  [0, 0, 2, 2, -1110],
  [3, 0, -1, 0, -892],
  [2, 1, 1, 0, -810],
  [4, -1, -2, 0, 759],
  [0, 2, -1, 0, -713],
  [2, 2, -1, 0, -700],
  [2, 1, -2, 0, 691],
  [2, -1, 0, -2, 596],
  [4, 0, 1, 0, 549],
  [0, 0, 4, 0, 537],
  [4, -1, 0, 0, 520],
  [1, 0, -2, 0, -487],
  [2, 1, 0, -2, -399],
  [0, 0, 2, -2, -381],
  [1, 1, 1, 0, 351],
  [3, 0, -2, 0, -340],
  [4, 0, -3, 0, 330],
  [2, -1, 2, 0, 327],
  [0, 2, 1, 0, -323],
  [1, 1, -1, 0, 299],
  [2, 0, 3, 0, 294]
]

// Geocentric ecliptic longitude of the Moon (Meeus ch.47), degrees.
function moonLongitude(T: number): number {
  const T2 = T * T
  const T3 = T2 * T
  const T4 = T3 * T
  const Lp = 218.3164477 + 481267.88123421 * T - 0.0015786 * T2 + T3 / 538841 - T4 / 65194000
  const D = (297.8501921 + 445267.1114034 * T - 0.0018819 * T2 + T3 / 545868 - T4 / 113065000) * DEG
  const M = (357.5291092 + 35999.0502909 * T - 0.0001536 * T2 + T3 / 24490000) * DEG
  const Mp = (134.9633964 + 477198.8675055 * T + 0.0087414 * T2 + T3 / 69699 - T4 / 14712000) * DEG
  const F = (93.272095 + 483202.0175233 * T - 0.0036539 * T2 - T3 / 3526000 + T4 / 863310000) * DEG
  const A1 = (119.75 + 131.849 * T) * DEG
  const A2 = (53.09 + 479264.29 * T) * DEG
  const E = 1 - 0.002516 * T - 0.0000074 * T2
  const E2 = E * E

  let sum = 0
  for (const [d, m, mp, f, coef] of MOON_L_TERMS) {
    const scale = m === 1 || m === -1 ? E : m === 2 || m === -2 ? E2 : 1
    sum += coef * scale * Math.sin(d * D + m * M + mp * Mp + f * F)
  }
  sum += 3958 * Math.sin(A1) + 1962 * Math.sin(Lp * DEG - F) + 318 * Math.sin(A2)

  return norm360(Lp + sum / 1e6)
}

/**
 * Moon phase for an instant: phase angle 0-360° (0 new, 90 first quarter,
 * 180 full, 270 last quarter), elongation-based illumination percentage,
 * and the display name/emoji bucket.
 */
export function getMoonPhase(date: Date): MoonPhaseInfo {
  const T = centuriesTT(date.getTime())
  const phaseAngle = norm360(moonLongitude(T) - sunLongitude(T))
  const illumination = Math.round(50 * (1 - Math.cos(phaseAngle * DEG)))

  // Determine phase name and emoji based on phase angle
  // Use tight ranges for major phases (~1 day = ~12°), rest are transitional
  let name: string
  let emoji: string

  if (phaseAngle < 6 || phaseAngle >= 354) {
    // New Moon: within ~12 hours of 0°
    name = 'New Moon'
    emoji = '🌑'
  } else if (phaseAngle < 84) {
    name = 'Waxing Crescent'
    emoji = '🌒'
  } else if (phaseAngle < 96) {
    // First Quarter: within ~12 hours of 90°
    name = 'First Quarter'
    emoji = '🌓'
  } else if (phaseAngle < 174) {
    name = 'Waxing Gibbous'
    emoji = '🌔'
  } else if (phaseAngle < 186) {
    // Full Moon: within ~12 hours of 180°
    name = 'Full Moon'
    emoji = '🌕'
  } else if (phaseAngle < 264) {
    name = 'Waning Gibbous'
    emoji = '🌖'
  } else if (phaseAngle < 276) {
    // Last Quarter: within ~12 hours of 270°
    name = 'Last Quarter'
    emoji = '🌗'
  } else {
    name = 'Waning Crescent'
    emoji = '🌘'
  }

  return { phaseAngle, name, emoji, illumination }
}

// --- Moon quadratures: Meeus ch.49 "Phases of the Moon" ----------------------

const PHASE_META: ReadonlyArray<Pick<MoonPhaseEvent, 'type' | 'name' | 'emoji'>> = [
  { type: 'new', name: 'New Moon', emoji: '🌑' },
  { type: 'first_quarter', name: 'First Quarter', emoji: '🌓' },
  { type: 'full', name: 'Full Moon', emoji: '🌕' },
  { type: 'last_quarter', name: 'Last Quarter', emoji: '🌗' }
]

// Correction series shared by new and full moon; the first 16 coefficients
// differ between the two, the tail is common (Meeus p.351).
const NEW_MOON_COEFFS = [
  -0.4072, 0.17241, 0.01608, 0.01039, 0.00739, -0.00514, 0.00208, -0.00111,
  -0.00057, 0.00056, -0.00042, 0.00042, 0.00038, -0.00024, -0.00017, -0.00007
]
const FULL_MOON_COEFFS = [
  -0.40614, 0.17302, 0.01614, 0.01043, 0.00734, -0.00515, 0.00209, -0.00111,
  -0.00057, 0.00056, -0.00042, 0.00042, 0.00038, -0.00024, -0.00017, -0.00007
]

// JDE (TT) of the quadrature `quarter` (0 new, 1 first, 2 full, 3 last) of
// the given integer lunation, converted to a UTC ms timestamp.
function quadratureUtcMs(lunation: number, quarter: 0 | 1 | 2 | 3): number {
  const k = lunation + quarter / 4
  const T = k / 1236.85
  const T2 = T * T
  const T3 = T2 * T
  const T4 = T3 * T

  let jde = 2451550.09766 + 29.530588861 * k + 0.00015437 * T2 - 0.00000015 * T3 + 0.00000000073 * T4

  const E = 1 - 0.002516 * T - 0.0000074 * T2
  const E2 = E * E
  const M = (2.5534 + 29.1053567 * k - 0.0000014 * T2 - 0.00000011 * T3) * DEG
  const Mp = (201.5643 + 385.81693528 * k + 0.0107582 * T2 + 0.00001238 * T3 - 0.000000058 * T4) * DEG
  const F = (160.7108 + 390.67050284 * k - 0.0016118 * T2 - 0.00000227 * T3 + 0.000000011 * T4) * DEG
  const O = (124.7746 - 1.56375588 * k + 0.0020672 * T2 + 0.00000215 * T3) * DEG

  if (quarter === 0 || quarter === 2) {
    const c = quarter === 0 ? NEW_MOON_COEFFS : FULL_MOON_COEFFS
    jde +=
      c[0] * Math.sin(Mp) +
      c[1] * E * Math.sin(M) +
      c[2] * Math.sin(2 * Mp) +
      c[3] * Math.sin(2 * F) +
      c[4] * E * Math.sin(Mp - M) +
      c[5] * E * Math.sin(Mp + M) +
      c[6] * E2 * Math.sin(2 * M) +
      c[7] * Math.sin(Mp - 2 * F) +
      c[8] * Math.sin(Mp + 2 * F) +
      c[9] * E * Math.sin(2 * Mp + M) +
      c[10] * Math.sin(3 * Mp) +
      c[11] * E * Math.sin(M + 2 * F) +
      c[12] * E * Math.sin(M - 2 * F) +
      c[13] * E * Math.sin(2 * Mp - M) +
      c[14] * Math.sin(O) +
      c[15] * Math.sin(Mp + 2 * M) +
      0.00004 * Math.sin(2 * Mp - 2 * F) +
      0.00004 * Math.sin(3 * M) +
      0.00003 * Math.sin(Mp + M - 2 * F) +
      0.00003 * Math.sin(2 * Mp + 2 * F) -
      0.00003 * Math.sin(Mp + M + 2 * F) +
      0.00003 * Math.sin(Mp - M + 2 * F) -
      0.00002 * Math.sin(Mp - M - 2 * F) -
      0.00002 * Math.sin(3 * Mp + M) +
      0.00002 * Math.sin(4 * Mp)
  } else {
    jde +=
      -0.62801 * Math.sin(Mp) +
      0.17172 * E * Math.sin(M) -
      0.01183 * E * Math.sin(Mp + M) +
      0.00862 * Math.sin(2 * Mp) +
      0.00804 * Math.sin(2 * F) +
      0.00454 * E * Math.sin(Mp - M) +
      0.00204 * E2 * Math.sin(2 * M) -
      0.0018 * Math.sin(Mp - 2 * F) -
      0.0007 * Math.sin(Mp + 2 * F) -
      0.0004 * Math.sin(3 * Mp) -
      0.00034 * E * Math.sin(2 * Mp - M) +
      0.00032 * E * Math.sin(M + 2 * F) +
      0.00032 * E * Math.sin(M - 2 * F) -
      0.00028 * E2 * Math.sin(Mp + 2 * M) +
      0.00027 * E * Math.sin(2 * Mp + M) -
      0.00017 * Math.sin(O) -
      0.00005 * Math.sin(Mp - M - 2 * F) +
      0.00004 * Math.sin(2 * Mp + 2 * F) -
      0.00004 * Math.sin(Mp + M + 2 * F) +
      0.00004 * Math.sin(Mp - 2 * M) +
      0.00003 * Math.sin(Mp + M - 2 * F) +
      0.00003 * Math.sin(3 * M) +
      0.00002 * Math.sin(2 * Mp - 2 * F) +
      0.00002 * Math.sin(Mp - M + 2 * F) -
      0.00002 * Math.sin(3 * Mp + M)
    const W =
      0.00306 -
      0.00038 * E * Math.cos(M) +
      0.00026 * Math.cos(Mp) -
      0.00002 * Math.cos(Mp - M) +
      0.00002 * Math.cos(Mp + M) +
      0.00002 * Math.cos(2 * F)
    jde += quarter === 1 ? W : -W
  }

  // Additional corrections for planetary perturbations (all phases).
  const A = [
    [0.000325, 299.77 + 0.107408 * k - 0.009173 * T2],
    [0.000165, 251.88 + 0.016321 * k],
    [0.000164, 251.83 + 26.651886 * k],
    [0.000126, 349.42 + 36.412478 * k],
    [0.00011, 84.66 + 18.206239 * k],
    [0.000062, 141.74 + 53.303771 * k],
    [0.00006, 207.14 + 2.453732 * k],
    [0.000056, 154.84 + 7.30686 * k],
    [0.000047, 34.52 + 27.261239 * k],
    [0.000042, 207.19 + 0.121824 * k],
    [0.00004, 291.34 + 1.844379 * k],
    [0.000037, 161.72 + 24.198154 * k],
    [0.000035, 239.56 + 25.513099 * k],
    [0.000023, 331.55 + 3.592518 * k]
  ]
  for (const [coef, angle] of A) jde += coef * Math.sin(angle * DEG)

  const ttMs = (jde - UNIX_EPOCH_JD) * DAY_MS
  return ttMs - deltaTSeconds(ttMs) * 1000
}

/**
 * Exact times of the four principal moon phases within [start, end].
 * `end` defaults to 30 days after `start`.
 */
export function getMoonPhaseEvents(start: Date, end?: Date): MoonPhaseEvent[] {
  const startMs = start.getTime()
  const endMs = (end ?? new Date(startMs + 30 * DAY_MS)).getTime()

  // Approximate lunation number at `start` (Meeus 49.2), backed off by one so
  // quarters of the preceding lunation that fall inside the range are found.
  const yearFrac = 2000 + (startMs / DAY_MS + UNIX_EPOCH_JD - J2000_JD) / 365.25
  let lunation = Math.floor((yearFrac - 2000) * 12.3685) - 1

  const events: MoonPhaseEvent[] = []
  while (quadratureUtcMs(lunation, 0) <= endMs) {
    for (const quarter of [0, 1, 2, 3] as const) {
      const t = quadratureUtcMs(lunation, quarter)
      if (t >= startMs && t <= endMs) {
        events.push({ ...PHASE_META[quarter], time: new Date(t) })
      }
    }
    lunation++
  }

  events.sort((a, b) => a.time.getTime() - b.time.getTime())
  return events
}

/**
 * Principal moon phase events of a month, keyed by the civil day-of-month
 * the event falls on in `timeZone`. `month0` is 0-based.
 */
export function getMonthMoonPhaseEvents(
  year: number,
  month0: number,
  timeZone = DEFAULT_TIME_ZONE
): Map<number, MoonPhaseEvent> {
  const first: CalendarDay = { year, month: month0 + 1, day: 1 }
  const nextFirst: CalendarDay =
    month0 === 11 ? { year: year + 1, month: 1, day: 1 } : { year, month: month0 + 2, day: 1 }
  const { start } = dayBoundsUtc(first, timeZone)
  const { start: end } = dayBoundsUtc(nextFirst, timeZone)

  const events = getMoonPhaseEvents(start, new Date(end.getTime() - 1))
  const eventsByDay = new Map<number, MoonPhaseEvent>()
  for (const event of events) {
    eventsByDay.set(calendarDayOf(event.time, timeZone).day, event)
  }
  return eventsByDay
}
