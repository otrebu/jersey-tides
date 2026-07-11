// Compare a constituent set (or the app constants) against official tide events,
// reporting BOTH height and timing errors of extremes. Uses src/lib/engine.ts.
// Usage: node scripts/compare2.mjs <events.json> [fit.json]
import { createPredictor } from '../src/lib/engine.ts'
import { ST_HELIER_CONSTITUENTS, DATUM } from '../src/lib/constants.ts'
import { readFileSync } from 'node:fs'

const eventsPath = process.argv[2]
let constituents = ST_HELIER_CONSTITUENTS
let datum = DATUM
if (process.argv[3]) {
  const alt = JSON.parse(readFileSync(process.argv[3], 'utf8'))
  constituents = alt.constituents
  datum = alt.datum
}
const pred = createPredictor(constituents)
const events = JSON.parse(readFileSync(eventsPath, 'utf8')).map((e) => ({ ...e, time: new Date(e.utc) }))

const rows = []
for (const e of events) {
  const atTime = datum + pred.levelAt(e.time)
  // our extremes within ±3h, matched by type
  const ext = pred
    .extremes(new Date(e.time.getTime() - 3 * 3600000), new Date(e.time.getTime() + 3 * 3600000))
    .filter((x) => (e.type === 'H' ? x.high : x.low))
    .map((x) => ({ ...x, dtMin: (x.time.getTime() - e.time.getTime()) / 60000 }))
    .sort((a, b) => Math.abs(a.dtMin) - Math.abs(b.dtMin))
  const m = ext[0] ?? null
  rows.push({
    utc: e.utc,
    source: e.source,
    type: e.type,
    official: e.height,
    e1: atTime - e.height,
    e2: m ? datum + m.level - e.height : null,
    dtMin: m ? m.dtMin : null,
  })
}

const stats = (vals) => {
  const a = vals.filter((v) => v !== null).map(Math.abs).sort((x, y) => x - y)
  if (!a.length) return null
  const q = (p) => a[Math.min(a.length - 1, Math.floor(p * a.length))]
  return { n: a.length, max: a[a.length - 1], mean: a.reduce((s, v) => s + v, 0) / a.length, p95: q(0.95) }
}
const fmtH = (s, over) =>
  `n=${s.n} max=${s.max.toFixed(3)} mean=${s.mean.toFixed(3)} p95=${s.p95.toFixed(3)} >0.25m:${over[0]} >0.5m:${over[1]}`
const fmtT = (s, over) =>
  `n=${s.n} max=${s.max.toFixed(1)}min mean=${s.mean.toFixed(1)}min p95=${s.p95.toFixed(1)}min >10min:${over[0]} >15min:${over[1]}`

for (const source of [...new Set(rows.map((r) => r.source))]) {
  const rs = rows.filter((r) => r.source === source)
  const e1 = rs.map((r) => r.e1)
  const e2 = rs.map((r) => r.e2)
  const dt = rs.map((r) => r.dtMin)
  console.log(`\n=== ${source} (${rs.length} events, unmatched=${rs.filter((r) => r.dtMin === null).length}) ===`)
  console.log('  height@time  :', fmtH(stats(e1), [e1.filter((v) => Math.abs(v) > 0.25).length, e1.filter((v) => Math.abs(v) > 0.5).length]))
  console.log('  extreme height:', fmtH(stats(e2), [e2.filter((v) => v !== null && Math.abs(v) > 0.25).length, e2.filter((v) => v !== null && Math.abs(v) > 0.5).length]))
  console.log('  extreme timing:', fmtT(stats(dt), [dt.filter((v) => v !== null && Math.abs(v) > 10).length, dt.filter((v) => v !== null && Math.abs(v) > 15).length]))
}

const dtAll = rows.map((r) => r.dtMin)
const e1All = rows.map((r) => r.e1)
const e2All = rows.map((r) => r.e2)
console.log(`\n=== overall (${rows.length}) ===`)
console.log('  height@time  :', fmtH(stats(e1All), [e1All.filter((v) => Math.abs(v) > 0.25).length, e1All.filter((v) => Math.abs(v) > 0.5).length]))
console.log('  extreme height:', fmtH(stats(e2All), [e2All.filter((v) => v !== null && Math.abs(v) > 0.25).length, e2All.filter((v) => v !== null && Math.abs(v) > 0.5).length]))
console.log('  extreme timing:', fmtT(stats(dtAll), [dtAll.filter((v) => v !== null && Math.abs(v) > 10).length, dtAll.filter((v) => v !== null && Math.abs(v) > 15).length]))

console.log('\nworst 15 by |dt|:')
for (const r of [...rows].filter((r) => r.dtMin !== null).sort((a, b) => Math.abs(b.dtMin) - Math.abs(a.dtMin)).slice(0, 15)) {
  console.log(
    `  ${r.utc} ${r.type} ${r.source.padEnd(4)} official=${r.official.toFixed(1)} dt=${r.dtMin.toFixed(1)}min e2=${r.e2.toFixed(2)}m e1=${r.e1.toFixed(2)}m`
  )
}
