// GATE: prove the harmonic engine survived the monorepo move byte-for-byte.
// Extracts the PRE-move engine + constants from the pinned pre-migration
// baseline commit (main's tip before the monorepo, immutable by SHA), imports
// them alongside the moved core sources, builds a predictor from each, and
// asserts the two agree to the bit on 5000 deterministic levels and on
// extremes over 60 spread days. Both sides run in the SAME process, so the
// comparison is exact regardless of platform/V8 version. Data-independent:
// no official events, no Math.random, no Date.now.
//
// Requires full git history (CI checks out with fetch-depth: 0).
//
// Usage: node tools/fit/verify-engine-move.mjs   (exit 0 = PASS, 1 = FAIL)
import { execFileSync } from 'node:child_process'
import { mkdtempSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { pathToFileURL } from 'node:url'

import { createPredictor as newPredictor } from '../../packages/core/src/engine.ts'
import { ST_HELIER_CONSTITUENTS as NEW_CONSTITUENTS } from '../../packages/core/src/stations/st-helier.data.ts'

// Last pre-monorepo commit ("Bring extreme timing under 5 minutes with
// TICON-4 anchored refit") — the fitted engine this gate preserves.
const BASELINE = '58fded99e04824dfe0f74c0eaf6ebffe94ad81c1'

const repoRoot = join(import.meta.dirname, '..', '..')
const showBaseline = (path) =>
  execFileSync('git', ['show', `${BASELINE}:${path}`], { cwd: repoRoot, encoding: 'utf8' })

const dir = mkdtempSync(join(tmpdir(), 'engine-move-'))
const engineMainPath = join(dir, 'engine-main.ts')
const constantsMainPath = join(dir, 'constants-main.ts')
// Both files are dependency-free leaves at the baseline (engine imports nothing;
// constants imports nothing), so they type-strip and import as-is.
writeFileSync(engineMainPath, showBaseline('src/lib/engine.ts'))
writeFileSync(constantsMainPath, showBaseline('src/lib/constants.ts'))

const { createPredictor: mainPredictor } = await import(pathToFileURL(engineMainPath).href)
const { ST_HELIER_CONSTITUENTS: MAIN_CONSTITUENTS } = await import(pathToFileURL(constantsMainPath).href)

const pNew = newPredictor(NEW_CONSTITUENTS)
const pMain = mainPredictor(MAIN_CONSTITUENTS)

// Deterministic timestamps: seeded LCG (Numerical Recipes constants) over the
// 2023-01-01 .. 2030-12-31 window. No Math.random.
let seed = 0x9e3779b9
const nextU32 = () => {
  seed = (Math.imul(1664525, seed) + 1013904223) >>> 0
  return seed
}
const START = Date.UTC(2023, 0, 1, 0, 0, 0)
const END = Date.UTC(2030, 11, 31, 23, 59, 59)
const SPAN = END - START
const nextTime = () => new Date(START + Math.floor((nextU32() / 0x100000000) * SPAN))

let levelPass = 0
let levelFail = 0
const LEVEL_N = 5000
for (let i = 0; i < LEVEL_N; i++) {
  const t = nextTime()
  if (Object.is(pNew.levelAt(t), pMain.levelAt(t))) levelPass++
  else levelFail++
}

// Extremes day-by-day for 60 days spread evenly across the window.
const DAY_N = 60
const DAY_MS = 86400000
let extPass = 0
let extFail = 0
let extPairs = 0
for (let d = 0; d < DAY_N; d++) {
  const dayStart = new Date(START + Math.floor((d / DAY_N) * SPAN))
  const dayEnd = new Date(dayStart.getTime() + DAY_MS)
  const en = pNew.extremes(dayStart, dayEnd)
  const em = pMain.extremes(dayStart, dayEnd)
  if (en.length !== em.length) {
    extFail++
    console.log(`  extreme count mismatch on day ${d}: new=${en.length} main=${em.length}`)
    continue
  }
  let dayOk = true
  for (let k = 0; k < en.length; k++) {
    extPairs++
    const sameTime = en[k].time.getTime() === em[k].time.getTime()
    const sameLevel = Object.is(en[k].level, em[k].level)
    const sameKind = en[k].high === em[k].high && en[k].low === em[k].low
    if (!(sameTime && sameLevel && sameKind)) {
      dayOk = false
      console.log(
        `  extreme mismatch day ${d} #${k}: dt=${en[k].time.getTime() - em[k].time.getTime()}ms ` +
          `dLevel=${en[k].level - em[k].level}`
      )
    }
  }
  if (dayOk) extPass++
  else extFail++
}

console.log(`levels:   ${levelPass}/${LEVEL_N} identical (fail=${levelFail})`)
console.log(`extremes: ${extPass}/${DAY_N} days identical (fail=${extFail}, ${extPairs} extreme pairs compared)`)

const ok = levelFail === 0 && extFail === 0
console.log(ok ? 'PASS: engine survived the move byte-for-byte' : 'FAIL: engine output diverged after move')
process.exit(ok ? 0 : 1)
