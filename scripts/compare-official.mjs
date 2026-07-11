// Compare the offline tide algorithm against official gov.je predictions.
// Usage: node scripts/compare-official.mjs <official-events.json> [constituents.json]
// Official events: [{utc, height, type: 'H'|'L', source}], heights in metres above chart datum.
import TidePredictor from '@neaps/tide-predictor'
import { readFileSync } from 'node:fs'
import { ST_HELIER_CONSTITUENTS, DATUM } from '../src/lib/constants.ts'

const eventsPath = process.argv[2]
if (!eventsPath) {
  console.error('usage: node scripts/compare-official.mjs <official-events.json> [constituents.json]')
  process.exit(1)
}

let constituents = ST_HELIER_CONSTITUENTS
let datum = DATUM
if (process.argv[3]) {
  const alt = JSON.parse(readFileSync(process.argv[3], 'utf8'))
  constituents = alt.constituents
  datum = alt.datum
}

const predictor = TidePredictor(constituents, { phaseKey: 'phase_GMT' })
const events = JSON.parse(readFileSync(eventsPath, 'utf8'))
  .map(e => ({ ...e, time: new Date(e.utc) }))

const levelAt = (t) => datum + predictor.getWaterLevelAtTime({ time: t }).level

// Find our nearest extreme to time t by scanning +-150 min at 1-min steps.
function nearestExtreme(t) {
  const HALF = 150
  let best = null
  let prev = levelAt(new Date(t.getTime() - (HALF + 1) * 60000))
  let curr = levelAt(new Date(t.getTime() - HALF * 60000))
  for (let m = -HALF + 1; m <= HALF; m++) {
    const next = levelAt(new Date(t.getTime() + m * 60000))
    const isMax = curr >= prev && curr >= next
    const isMin = curr <= prev && curr <= next
    if (isMax || isMin) {
      const cand = { dtMin: m - 1, height: curr, type: isMax ? 'H' : 'L' }
      if (!best || Math.abs(cand.dtMin) < Math.abs(best.dtMin)) best = cand
    }
    prev = curr
    curr = next
  }
  return best
}

const rows = []
for (const e of events) {
  const hAtTime = levelAt(e.time)
  const ext = nearestExtreme(e.time)
  rows.push({
    utc: e.utc,
    source: e.source,
    type: e.type,
    official: e.height,
    atTime: hAtTime,
    e1: hAtTime - e.height,
    extHeight: ext?.height ?? null,
    e2: ext && ext.type === e.type ? ext.height - e.height : null,
    dtMin: ext && ext.type === e.type ? ext.dtMin : null,
  })
}

function stats(vals) {
  const a = vals.filter(v => v !== null).map(Math.abs).sort((x, y) => x - y)
  if (!a.length) return null
  const q = p => a[Math.min(a.length - 1, Math.floor(p * a.length))]
  return {
    n: a.length,
    max: a[a.length - 1],
    mean: a.reduce((s, v) => s + v, 0) / a.length,
    p95: q(0.95),
    over50: a.filter(v => v > 0.5).length,
    over25: a.filter(v => v > 0.25).length,
  }
}

const fmt = s => s
  ? `n=${s.n} max=${s.max.toFixed(3)} mean=${s.mean.toFixed(3)} p95=${s.p95.toFixed(3)} >0.25m:${s.over25} >0.5m:${s.over50}`
  : 'n/a'

for (const source of [...new Set(rows.map(r => r.source))]) {
  const rs = rows.filter(r => r.source === source)
  console.log(`\n=== source ${source} (${rs.length} events) ===`)
  console.log('  height@official-time e1:', fmt(stats(rs.map(r => r.e1))))
  console.log('  extreme height       e2:', fmt(stats(rs.map(r => r.e2))))
  const dts = rs.map(r => r.dtMin).filter(v => v !== null).map(Math.abs)
  console.log(`  extreme time |dt|: max=${Math.max(...dts)}min mean=${(dts.reduce((s, v) => s + v, 0) / dts.length).toFixed(1)}min unmatched=${rs.length - dts.length}`)
}

console.log('\n=== overall ===')
console.log('  e1:', fmt(stats(rows.map(r => r.e1))))
console.log('  e2:', fmt(stats(rows.map(r => r.e2))))

console.log('\nworst 12 by |e1|:')
for (const r of [...rows].sort((a, b) => Math.abs(b.e1) - Math.abs(a.e1)).slice(0, 12)) {
  console.log(`  ${r.utc} ${r.type} official=${r.official.toFixed(1)} ours=${r.atTime.toFixed(2)} e1=${r.e1.toFixed(2)} e2=${r.e2 === null ? '  n/a' : r.e2.toFixed(2)} dt=${r.dtMin ?? 'n/a'}min`)
}
