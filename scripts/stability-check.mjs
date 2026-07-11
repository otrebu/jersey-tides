// Compare two fitted constituent sets over a long horizon: max instantaneous level
// divergence sampled every 10 minutes. If two fits trained on disjoint epochs agree
// tightly across the whole window, the harmonic extrapolation is stable there.
// Usage: node scripts/stability-check.mjs <fitA.json> <fitB.json> <startISO> <days>
import TidePredictor from '@neaps/tide-predictor'
import { readFileSync } from 'node:fs'

const [aPath, bPath, startISO, daysStr] = process.argv.slice(2)
const A = JSON.parse(readFileSync(aPath, 'utf8'))
const B = JSON.parse(readFileSync(bPath, 'utf8'))
const pa = TidePredictor(A.constituents, { phaseKey: 'phase_GMT' })
const pb = TidePredictor(B.constituents, { phaseKey: 'phase_GMT' })

const start = new Date(startISO)
const days = Number(daysStr)
const STEP_MIN = 10
const samplesPerDay = (24 * 60) / STEP_MIN

let maxDiff = 0
let maxAt = null
let sum = 0
let n = 0
const monthly = new Map()

for (let d = 0; d < days; d++) {
  for (let s = 0; s < samplesPerDay; s++) {
    const t = new Date(start.getTime() + (d * 24 * 60 + s * STEP_MIN) * 60000)
    const la = A.datum + pa.getWaterLevelAtTime({ time: t }).level
    const lb = B.datum + pb.getWaterLevelAtTime({ time: t }).level
    const diff = Math.abs(la - lb)
    sum += diff
    n++
    if (diff > maxDiff) {
      maxDiff = diff
      maxAt = t.toISOString()
    }
    const mk = t.toISOString().slice(0, 7)
    monthly.set(mk, Math.max(monthly.get(mk) ?? 0, diff))
  }
  if (d % 100 === 99) console.log(`  ...day ${d + 1}/${days}, running max ${maxDiff.toFixed(3)}m`)
}

console.log(`\nsamples=${n} mean|diff|=${(sum / n).toFixed(4)}m max|diff|=${maxDiff.toFixed(4)}m at ${maxAt}`)
console.log('\nworst month-by-month:')
for (const [m, v] of [...monthly.entries()].sort()) console.log(`  ${m}  ${v.toFixed(3)}m`)
