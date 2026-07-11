// Fit harmonic constants to official tide-table events using src/lib/engine.ts
// (owned, UTC-correct, extended catalog). Two row types per official extreme
// (time t_i, height h_i):
//   height row:  level(t_i) = h_i                          weight 1
//   time row:    slope(t_i) = 0                            weight beta / max(|curv_i|, floor)
// The time-row weighting makes each residual proportional to the TIME error of our
// extreme (slope ≈ curv × dt), so beta directly prices "metres per hour of dt".
// Curvature is estimated from a reference predictor and re-estimated by iterating.
//
// Usage: node scripts/fit2.mjs <events.json> <out.json> [--train=all] [--beta=1.5] [--iters=3]
import { evalBasis, createPredictor, CATALOG } from '../src/lib/engine.ts'
import { ST_HELIER_CONSTITUENTS, DATUM } from '../src/lib/constants.ts'
import { readFileSync, writeFileSync } from 'node:fs'

const args = process.argv.slice(2)
const eventsPath = args[0]
const outPath = args[1]
const opt = Object.fromEntries(args.slice(2).map((a) => a.replace(/^--/, '').split('=')))
const TRAIN = opt.train ?? 'all'
const BETA = Number(opt.beta ?? 1.5) // metre-equivalent penalty per hour of time error
const ITERS = Number(opt.iters ?? 3)
const CURV_FLOOR = 0.12 // m/h^2 — below this the official time itself is fuzzy (flat/double tides)

const NAMES = [
  'M2', 'S2', 'N2', 'K2', 'L2', 'T2', 'R2', '2N2', 'MU2', 'NU2', 'LAM2', '2SM2',
  'MA2', 'MB2', 'MSN2', 'MNS2', 'MKS2',
  'K1', 'O1', 'P1', 'Q1', 'J1', 'M1', 'S1', 'OO1', '2Q1', 'RHO',
  'M3', 'MK3', '2MK3', 'MO3', 'SO3', 'SK3',
  'M4', 'MN4', 'MS4', 'S4', 'MK4', 'SN4', 'SK4',
  'M6', 'S6', '2MS6', '2MN6', 'MSN6', '2SM6', 'MSK6',
  'M8', '3MS8', '2MS8', '2MSN8', 'M10',
  'SA', 'SSA', 'MM', 'MF', 'MSF',
]
for (const n of NAMES) if (!CATALOG[n]) throw new Error(`engine missing ${n}`)

const SIGMAS = {
  M2: 0.3, S2: 0.2, N2: 0.15, K2: 0.1, L2: 0.08, '2N2': 0.06, MU2: 0.08, NU2: 0.06,
  LAM2: 0.05, '2SM2': 0.03, T2: 0.03, R2: 0.01,
  MA2: 0.06, MB2: 0.06, MSN2: 0.04, MNS2: 0.04, MKS2: 0.04,
  K1: 0.05, O1: 0.05, P1: 0.02, Q1: 0.03, J1: 0.01, M1: 0.01, S1: 0.01, OO1: 0.01,
  '2Q1': 0.01, RHO: 0.01,
  M3: 0.02, MK3: 0.02, '2MK3': 0.02, MO3: 0.02, SO3: 0.02, SK3: 0.02,
  M4: 0.08, MN4: 0.05, MS4: 0.06, S4: 0.02, MK4: 0.04, SN4: 0.03, SK4: 0.03,
  M6: 0.06, S6: 0.01, '2MS6': 0.06, '2MN6': 0.05, MSN6: 0.04, '2SM6': 0.04, MSK6: 0.03,
  M8: 0.03, '3MS8': 0.03, '2MS8': 0.03, '2MSN8': 0.02, M10: 0.015,
  SA: 0.05, SSA: 0.04, MM: 0.03, MF: 0.03, MSF: 0.03,
}

const allEvents = JSON.parse(readFileSync(eventsPath, 'utf8')).map((e) => ({ ...e, time: new Date(e.utc) }))
const trainSet = new Set(TRAIN.split(','))
const events = TRAIN === 'all' ? allEvents : allEvents.filter((e) => trainSet.has(e.source))
console.log(`training on ${events.length}/${allEvents.length} events (train=${TRAIN}), beta=${BETA} iters=${ITERS}`)

// Precompute basis (value + slope rows) once — it does not depend on the solution.
const K = NAMES.length
const P = 2 * K + 1
const B = events.map((e) => evalBasis(NAMES, e.time))

// prior from current app constants
const prior = new Float64Array(P)
for (let k = 0; k < K; k++) {
  const c = ST_HELIER_CONSTITUENTS.find((c) => c.name === NAMES[k])
  if (c) {
    const g = (c.phase_GMT * Math.PI) / 180
    prior[k] = c.amplitude * Math.cos(g)
    prior[K + k] = c.amplitude * Math.sin(g)
  }
}
prior[2 * K] = DATUM

function solve(weights) {
  const AtA = Array.from({ length: P }, () => new Float64Array(P))
  const Atb = new Float64Array(P)
  const row = new Float64Array(P)
  const addRow = (target, w) => {
    for (let i = 0; i < P; i++) {
      if (row[i] === 0) continue
      const ri = row[i] * w
      Atb[i] += ri * target * w
      const AtAi = AtA[i]
      for (let j = i; j < P; j++) AtAi[j] += ri * row[j] * w
    }
  }
  for (let n = 0; n < events.length; n++) {
    const b = B[n]
    for (let k = 0; k < K; k++) {
      row[k] = b[k].c
      row[K + k] = b[k].s
    }
    row[2 * K] = 1
    addRow(events[n].height, 1)
    for (let k = 0; k < K; k++) {
      row[k] = b[k].dc
      row[K + k] = b[k].ds
    }
    row[2 * K] = 0
    addRow(0, weights[n])
  }
  for (let k = 0; k < K; k++) {
    const sigma = SIGMAS[NAMES[k]] ?? 0.03
    const lambda = 1 / (sigma * sigma)
    for (const i of [k, K + k]) {
      AtA[i][i] += lambda
      Atb[i] += lambda * prior[i]
    }
  }
  const lambdaZ = 1 / (0.1 * 0.1)
  AtA[2 * K][2 * K] += lambdaZ
  Atb[2 * K] += lambdaZ * prior[2 * K]

  for (let i = 0; i < P; i++) for (let j = 0; j < i; j++) AtA[i][j] = AtA[j][i]
  const M = AtA.map((r, i) => [...r, Atb[i]])
  for (let col = 0; col < P; col++) {
    let piv = col
    for (let r = col + 1; r < P; r++) if (Math.abs(M[r][col]) > Math.abs(M[piv][col])) piv = r
    ;[M[col], M[piv]] = [M[piv], M[col]]
    const d = M[col][col]
    for (let j = col; j <= P; j++) M[col][j] /= d
    for (let r = 0; r < P; r++) {
      if (r === col) continue
      const f = M[r][col]
      if (f === 0) continue
      for (let j = col; j <= P; j++) M[r][j] -= f * M[col][j]
    }
  }
  return M.map((r) => r[P])
}

const toConstants = (theta) => ({
  datum: +theta[2 * K].toFixed(4),
  constituents: NAMES.map((name, k) => {
    const amplitude = Math.hypot(theta[k], theta[K + k])
    let phase = (Math.atan2(theta[K + k], theta[k]) * 180) / Math.PI
    if (phase < 0) phase += 360
    return { name, amplitude: +amplitude.toFixed(4), phase_GMT: +phase.toFixed(2) }
  }).filter((c) => c.amplitude >= 0.0005),
})

// curvature from a predictor via finite difference of analytic slope
function curvatures(pred) {
  const H = 15 / 60 // hours
  return events.map((e) => {
    const sPlus = pred.slopeAt(new Date(e.time.getTime() + H * 3600000))
    const sMinus = pred.slopeAt(new Date(e.time.getTime() - H * 3600000))
    return Math.abs(sPlus - sMinus) / (2 * H)
  })
}

let refPred = createPredictor(ST_HELIER_CONSTITUENTS)
let theta = null
for (let it = 0; it < ITERS; it++) {
  const curv = curvatures(refPred)
  const weights = curv.map((c) => BETA / Math.max(c, CURV_FLOOR))
  theta = solve(weights)
  const fit = toConstants(theta)
  refPred = createPredictor(fit.constituents)
  // quick in-sample timing diagnostic
  let sumAbs = 0
  let worst = 0
  for (let n = 0; n < events.length; n++) {
    const slope = refPred.slopeAt(events[n].time)
    const dtMin = Math.abs(slope) / Math.max(curv[n], CURV_FLOOR) * 60
    sumAbs += dtMin
    worst = Math.max(worst, dtMin)
  }
  console.log(`iter ${it + 1}: in-sample |dt| mean=${(sumAbs / events.length).toFixed(1)}min worst≈${worst.toFixed(0)}min`)
}

const fit = toConstants(theta)
writeFileSync(outPath, JSON.stringify(fit, null, 2))
console.log(`datum=${fit.datum} constituents=${fit.constituents.length}`)
console.log(`wrote ${outPath}`)
