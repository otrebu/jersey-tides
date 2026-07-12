// Generate language-neutral golden fixtures for @u-b/tides-core from the moved
// engine + fitted St Helier constants. Deterministic: seeded LCG, fixed date
// ranges, NO Date.now — so regenerating produces byte-identical JSON.
//
// Usage: node tools/fit/gen-fixtures.mjs
import { mkdirSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'

import { getMoonPhaseEvents, getSunTimes } from '../../packages/core/src/almanac.ts'
import { createPredictor } from '../../packages/core/src/engine.ts'
import { ST_HELIER_CONSTITUENTS } from '../../packages/core/src/stations/st-helier.data.ts'
import { stHelier } from '../../packages/core/src/stations/st-helier.ts'

const outDir = join(import.meta.dirname, '..', '..', 'packages', 'core', 'fixtures')
mkdirSync(outDir, { recursive: true })

const predictor = createPredictor(ST_HELIER_CONSTITUENTS)
const write = (name, data) => {
  const path = join(outDir, name)
  writeFileSync(path, JSON.stringify(data, null, 2) + '\n')
  return path
}
const extremeType = (e) => (e.high ? 'high' : 'low')

// --- levels.json: 2000 raw-engine samples over 2023-01-01 .. 2030-12-31 --------
// Seeded LCG (Numerical Recipes constants), no Math.random.
let seed = 0x1234abcd
const nextU32 = () => {
  seed = (Math.imul(1664525, seed) + 1013904223) >>> 0
  return seed
}
const LEVEL_START = Date.UTC(2023, 0, 1, 0, 0, 0)
const LEVEL_END = Date.UTC(2030, 11, 31, 23, 59, 59)
const LEVEL_SPAN = LEVEL_END - LEVEL_START
const levels = []
for (let i = 0; i < 2000; i++) {
  const t = new Date(LEVEL_START + Math.floor((nextU32() / 0x100000000) * LEVEL_SPAN))
  levels.push({ utc: t.toISOString(), level: predictor.levelAt(t) })
}

// --- extremes.json: 48h windows over ~40 notable dates ------------------------
const solsticesEquinoxes = [
  '2024-03-20', '2024-06-20', '2024-09-22', '2024-12-21',
  '2025-03-20', '2025-06-21', '2025-09-22', '2025-12-21',
  '2026-03-20', '2026-06-21', '2026-09-23', '2026-12-21',
]
const firstOfMonth2025 = Array.from({ length: 12 }, (_, m) => `2025-${String(m + 1).padStart(2, '0')}-01`)
const firstOfMonth2026 = Array.from({ length: 12 }, (_, m) => `2026-${String(m + 1).padStart(2, '0')}-01`)
// 2026 spring tides — days near new/full moon (large tidal range at St Helier).
const springTides2026 = ['2026-01-18', '2026-03-19', '2026-06-14', '2026-08-12', '2026-09-11', '2026-10-10']
const notableDates = [...solsticesEquinoxes, ...firstOfMonth2025, ...firstOfMonth2026, ...springTides2026]
const extremes = notableDates.map((d) => {
  const from = new Date(`${d}T00:00:00.000Z`)
  const to = new Date(from.getTime() + 48 * 3600000)
  return {
    fromUtc: from.toISOString(),
    toUtc: to.toISOString(),
    extremes: predictor.extremes(from, to).map((e) => ({
      utc: e.time.toISOString(),
      level: e.level,
      type: extremeType(e),
    })),
  }
})

// --- station-days.json: 25 civil days via the station API (datum-inclusive) ----
// DST transition days (last Sun of Mar/Oct 2025-2027), year boundaries, ordinary.
const dstDays = [
  { year: 2025, month: 3, day: 30 }, { year: 2025, month: 10, day: 26 },
  { year: 2026, month: 3, day: 29 }, { year: 2026, month: 10, day: 25 },
  { year: 2027, month: 3, day: 28 }, { year: 2027, month: 10, day: 31 },
]
const boundaryDays = [
  { year: 2024, month: 12, day: 31 }, { year: 2025, month: 1, day: 1 },
  { year: 2025, month: 12, day: 31 }, { year: 2026, month: 1, day: 1 },
]
const ordinaryDays = [
  { year: 2025, month: 1, day: 15 }, { year: 2025, month: 2, day: 14 },
  { year: 2025, month: 4, day: 10 }, { year: 2025, month: 5, day: 20 },
  { year: 2025, month: 6, day: 21 }, { year: 2025, month: 7, day: 4 },
  { year: 2025, month: 8, day: 12 }, { year: 2025, month: 9, day: 9 },
  { year: 2025, month: 11, day: 11 }, { year: 2025, month: 12, day: 3 },
  { year: 2026, month: 1, day: 20 }, { year: 2026, month: 2, day: 17 },
  { year: 2026, month: 4, day: 15 }, { year: 2026, month: 7, day: 14 },
  { year: 2026, month: 9, day: 22 },
]
const stationDayList = [...dstDays, ...boundaryDays, ...ordinaryDays]
const stationDays = stationDayList.map((day) => ({
  day,
  tz: 'Europe/Jersey',
  extremes: stHelier.dayExtremes(day).map((e) => ({
    utc: e.time.toISOString(),
    height: e.height,
    type: e.type,
  })),
}))

// --- almanac.json: 2026 sun times + moon phase events (regression pin) ---------
const almanacSunDates = [
  '2026-03-20', '2026-06-21', '2026-09-23', '2026-12-21',
  ...firstOfMonth2026,
]
const almanacSun = almanacSunDates.map((d) => {
  const [y, m, dd] = d.split('-').map(Number)
  const day = { year: y, month: m, day: dd }
  const sun = getSunTimes(day)
  return {
    day,
    tz: 'Europe/Jersey',
    sunrise: sun.sunrise ? sun.sunrise.toISOString() : null,
    sunset: sun.sunset ? sun.sunset.toISOString() : null,
    dayLength: sun.dayLength,
  }
})
const almanacMoonEvents = getMoonPhaseEvents(
  new Date('2026-01-01T00:00:00.000Z'),
  new Date('2026-12-31T23:59:59.999Z')
).map((e) => ({ type: e.type, utc: e.time.toISOString() }))
const almanac = { sun: almanacSun, moonEvents: almanacMoonEvents }

const meta = {
  generatedFrom: 'st-helier.data.ts',
  engine: 'packages/core/src/engine.ts',
  note:
    'Golden fixtures for @u-b/tides-core. Deterministic (seeded LCG, fixed date ranges). ' +
    'levels/extremes are raw engine output (no datum); station-days heights include the chart datum; ' +
    'almanac.json pins the zero-dep almanac (2026 sun times + moon phase events). ' +
    'Regenerate with `pnpm fixtures`; the core test suite replays these for exact equality.',
}

const paths = [
  write('levels.json', levels),
  write('extremes.json', extremes),
  write('station-days.json', stationDays),
  write('almanac.json', almanac),
  write('meta.json', meta),
]
console.log(`levels:       ${levels.length} samples`)
console.log(`extremes:     ${extremes.length} windows, ${extremes.reduce((s, w) => s + w.extremes.length, 0)} extremes`)
console.log(`station-days: ${stationDays.length} days, ${stationDays.reduce((s, w) => s + w.extremes.length, 0)} extremes`)
console.log(`almanac:      ${almanacSun.length} sun days, ${almanacMoonEvents.length} moon events`)
for (const p of paths) console.log(`wrote ${p}`)
