// Far-window stability between two fitted sets on the owned engine: max instantaneous
// level divergence (10-min sampling) AND max extreme-time divergence, over a horizon.
// Usage: node scripts/stability2.mjs <fitA.json> <fitB.json> <startISO> <days>
import { createPredictor } from '../../packages/core/src/engine.ts'
import { readFileSync } from 'node:fs'

const [aPath, bPath, startISO, daysStr] = process.argv.slice(2)
const A = JSON.parse(readFileSync(aPath, 'utf8'))
const B = JSON.parse(readFileSync(bPath, 'utf8'))
const pa = createPredictor(A.constituents)
const pb = createPredictor(B.constituents)
const start = new Date(startISO)
const days = Number(daysStr)

// level divergence
let maxL = 0, maxLAt = null, sumL = 0, nL = 0
for (let d = 0; d < days; d++) {
  for (let s = 0; s < 144; s++) {
    const t = new Date(start.getTime() + (d * 144 + s) * 600000)
    const diff = Math.abs(A.datum + pa.levelAt(t) - (B.datum + pb.levelAt(t)))
    sumL += diff
    nL++
    if (diff > maxL) { maxL = diff; maxLAt = t.toISOString() }
  }
  if (d % 100 === 99) console.log(`  level: day ${d + 1}/${days}, running max ${maxL.toFixed(3)}m`)
}
console.log(`level: mean=${(sumL / nL).toFixed(4)}m max=${maxL.toFixed(4)}m at ${maxLAt}`)

// extreme-time divergence: A's extremes vs nearest same-type B extreme
let maxDt = 0, maxDtAt = null, sumDt = 0, nDt = 0
const CHUNK_DAYS = 30
for (let c = 0; c < Math.ceil(days / CHUNK_DAYS); c++) {
  const s = new Date(start.getTime() + c * CHUNK_DAYS * 86400000)
  const e = new Date(Math.min(s.getTime() + CHUNK_DAYS * 86400000, start.getTime() + days * 86400000))
  const ea = pa.extremes(s, e)
  const eb = pb.extremes(new Date(s.getTime() - 6 * 3600000), new Date(e.getTime() + 6 * 3600000))
  for (const x of ea) {
    const match = eb
      .filter((y) => y.high === x.high)
      .reduce((best, y) => {
        const dt = Math.abs(y.time.getTime() - x.time.getTime())
        return !best || dt < best.dt ? { dt, y } : best
      }, null)
    if (!match) continue
    const dtMin = match.dt / 60000
    sumDt += dtMin
    nDt++
    if (dtMin > maxDt) { maxDt = dtMin; maxDtAt = x.time.toISOString() }
  }
  if (c % 4 === 3) console.log(`  extremes: through day ${Math.min((c + 1) * CHUNK_DAYS, days)}/${days}, running max ${maxDt.toFixed(1)}min`)
}
console.log(`extreme timing: n=${nDt} mean=${(sumDt / nDt).toFixed(2)}min max=${maxDt.toFixed(2)}min at ${maxDtAt}`)
