// Fit harmonic constituent amplitudes/phases (+ datum) to official gov.je tide events,
// using @neaps/tide-predictor as the basis engine so its phase/nodal conventions are
// absorbed into the fitted constants.
//
// Model: level(t) = Z0 + sum_k [ x_k * b0_k(t) + y_k * b90_k(t) ]
//   catalog constituent: b0_k(t) = neaps level for {name k, amplitude 1, phase 0} = f_k cos(V_k+u_k)
//                        b90_k(t) = same with phase 90 = f_k sin(V_k+u_k)
//   compound constituent (e.g. 2MS6 = 2*M2 + S2): complex-synthesized from parents,
//     arg = sum m_i*(V+u)_i, f = prod f_i^|m_i|  — the standard shallow-water convention.
//   x = A cos g, y = A sin g  =>  A = hypot(x,y), g = atan2(y,x)
//
// Each official extreme (time t_i, height h_i) contributes a height row (weight 1) and
// a zero-slope row (weight WD, pins extreme timing). Ridge pulls each constituent toward
// its prior (current app constants, 0 for new ones) with per-constituent sigma.
//
// Usage: node scripts/fit-constituents.mjs <official-events.json> <out.json> [--train=2026] [--wd=1.0]
import TidePredictor from '@neaps/tide-predictor'
import { readFileSync, writeFileSync } from 'node:fs'
import { ST_HELIER_CONSTITUENTS, DATUM } from '../src/lib/constants.ts'

const args = process.argv.slice(2)
const eventsPath = args[0]
const outPath = args[1]
const opt = Object.fromEntries(args.slice(2).map(a => a.replace(/^--/, '').split('=')))
const WD = Number(opt.wd ?? 1.0) // weight (hours) for zero-slope rows
const TRAIN = opt.train ?? 'all'

const CATALOG_NAMES = [
  'M2', 'S2', 'N2', 'K2', 'L2', 'T2', 'R2', '2N2', 'MU2', 'NU2', 'LAM2', '2SM2',
  'K1', 'O1', 'P1', 'Q1', 'J1', 'M1', 'S1', 'OO1', '2Q1', 'RHO',
  'M3', 'MK3', '2MK3',
  'M4', 'MN4', 'MS4', 'S4', 'M6', 'S6', 'M8',
  'SA', 'SSA', 'MM', 'MF', 'MSF',
]

// Compound tides synthesized from parents (name -> {parent: multiplier}).
export const COMPOUNDS = {
  MK4: { M2: 1, K2: 1 },
  SN4: { S2: 1, N2: 1 },
  SK4: { S2: 1, K2: 1 },
  MO3: { M2: 1, O1: 1 },
  SO3: { S2: 1, O1: 1 },
  SK3: { S2: 1, K1: 1 },
  MSN2: { M2: 1, S2: 1, N2: -1 },
  MKS2: { M2: 1, K2: 1, S2: -1 },
  MNS2: { M2: 1, N2: 1, S2: -1 },
  '2MS6': { M2: 2, S2: 1 },
  '2MN6': { M2: 2, N2: 1 },
  MSN6: { M2: 1, S2: 1, N2: 1 },
  '2SM6': { S2: 2, M2: 1 },
  MSK6: { M2: 1, S2: 1, K2: 1 },
  '3MS8': { M2: 3, S2: 1 },
  '2MS8': { M2: 2, S2: 2 },
  MA2: { M2: 1, SA: -1 },
  MB2: { M2: 1, SA: 1 },
}
const PARENTS = ['M2', 'S2', 'N2', 'K2', 'O1', 'K1', 'SA']

// Per-constituent ridge sigma (metres). Overtides/compounds and near-degenerate terms
// stay tight so the curve keeps a physical shape; well-observed main terms are loose.
const SIGMAS = {
  M2: 0.3, S2: 0.2, N2: 0.15, K2: 0.1, L2: 0.08, '2N2': 0.06, MU2: 0.08, NU2: 0.06,
  LAM2: 0.05, '2SM2': 0.03, T2: 0.03, R2: 0.01,
  K1: 0.05, O1: 0.05, P1: 0.02, Q1: 0.03, J1: 0.01, M1: 0.01, S1: 0.01, OO1: 0.01,
  '2Q1': 0.01, RHO: 0.01,
  M3: 0.02, MK3: 0.02, '2MK3': 0.02, MO3: 0.02, SO3: 0.02, SK3: 0.02,
  M4: 0.08, MN4: 0.05, MS4: 0.06, S4: 0.02, MK4: 0.04, SN4: 0.03, SK4: 0.03,
  MSN2: 0.04, MKS2: 0.04, MNS2: 0.04, MA2: 0.05, MB2: 0.05,
  M6: 0.05, S6: 0.01, '2MS6': 0.05, '2MN6': 0.04, MSN6: 0.03, '2SM6': 0.03, MSK6: 0.03,
  M8: 0.02, '3MS8': 0.02, '2MS8': 0.02,
  SA: 0.05, SSA: 0.04, MM: 0.03, MF: 0.03, MSF: 0.03,
}
const DEFAULT_SIGMA = 0.03

const allEvents = JSON.parse(readFileSync(eventsPath, 'utf8')).map(e => ({ ...e, time: new Date(e.utc) }))
const events = TRAIN === 'all' ? allEvents : allEvents.filter(e => e.source === TRAIN)
console.log(`training on ${events.length}/${allEvents.length} events (train=${TRAIN}), wd=${WD}h`)

// --- basis on a 3-offset time grid (t-D, t, t+D) for value + slope ---------
const DT_MIN = 6
const N = events.length
const grid = [] // 3N times: [t0-D, t0, t0+D, t1-D, ...]
for (const e of events) {
  grid.push(new Date(e.time.getTime() - DT_MIN * 60000), e.time, new Date(e.time.getTime() + DT_MIN * 60000))
}

function rawBasis(name) {
  const mk = phase => {
    const p = TidePredictor([{ name, amplitude: 1, phase_GMT: phase }], { phaseKey: 'phase_GMT' })
    return grid.map(t => p.getWaterLevelAtTime({ time: t }).level)
  }
  return { c: mk(0), s: mk(90) } // f*cos(V+u), f*sin(V+u) on the 3N grid
}

const raw = new Map()
const catalog = []
for (const name of CATALOG_NAMES) {
  const b = rawBasis(name)
  const rms = Math.sqrt(b.c.reduce((s, v) => s + v * v, 0) / b.c.length)
  if (rms < 1e-6) {
    console.log(`  skipping ${name}: not supported by engine`)
    continue
  }
  raw.set(name, b)
  catalog.push(name)
}

// compounds: complex power-product of parents. Opt-in: the app's prediction engine
// (@neaps/tide-predictor) silently zeroes unknown names, so fitting compounds is only
// valid if the app switches to a synthesizer that supports them.
const compoundNames = []
const wantCompounds = opt.compounds !== undefined
for (const [name, def] of wantCompounds ? Object.entries(COMPOUNDS) : []) {
  const c = new Array(grid.length).fill(0)
  const s = new Array(grid.length).fill(0)
  let ok = true
  for (const parent of Object.keys(def)) if (!raw.has(parent)) ok = false
  if (!ok) { console.log(`  skipping compound ${name}: missing parent`); continue }
  for (let i = 0; i < grid.length; i++) {
    let re = 1, im = 0, scale = 1
    for (const [parent, m] of Object.entries(def)) {
      const pb = raw.get(parent)
      const f = Math.hypot(pb.c[i], pb.s[i])
      const th = Math.atan2(pb.s[i], pb.c[i])
      scale *= Math.pow(f, Math.abs(m))
      const ang = m * th
      const cr = Math.cos(ang), ci = Math.sin(ang)
      const nre = re * cr - im * ci
      im = re * ci + im * cr
      re = nre
    }
    c[i] = scale * re
    s[i] = scale * im
  }
  raw.set(name, { c, s })
  compoundNames.push(name)
}

const names = [...catalog, ...compoundNames]
console.log(`basis built for ${names.length} constituents (${catalog.length} catalog + ${compoundNames.length} compound)`)

// value/slope views: index i -> grid rows 3i, 3i+1, 3i+2
function viewsFor(name) {
  const { c, s } = raw.get(name)
  const b0 = new Float64Array(N), b90 = new Float64Array(N)
  const db0 = new Float64Array(N), db90 = new Float64Array(N)
  const H = 2 * DT_MIN / 60 // hours between +-D
  for (let i = 0; i < N; i++) {
    b0[i] = c[3 * i + 1]
    b90[i] = s[3 * i + 1]
    db0[i] = (c[3 * i + 2] - c[3 * i]) / H
    db90[i] = (s[3 * i + 2] - s[3 * i]) / H
  }
  return { b0, b90, db0, db90 }
}
const basis = names.map(n => ({ name: n, ...viewsFor(n) }))

// --- assemble normal equations ---------------------------------------------
const K = basis.length
const P = 2 * K + 1
const AtA = Array.from({ length: P }, () => new Float64Array(P))
const Atb = new Float64Array(P)
const row = new Float64Array(P)

function addRow(target, w) {
  for (let i = 0; i < P; i++) {
    if (row[i] === 0) continue
    const ri = row[i] * w
    Atb[i] += ri * target * w
    const AtAi = AtA[i]
    for (let j = i; j < P; j++) AtAi[j] += ri * row[j] * w
  }
}

for (let i = 0; i < N; i++) {
  for (let k = 0; k < K; k++) {
    row[k] = basis[k].b0[i]
    row[K + k] = basis[k].b90[i]
  }
  row[2 * K] = 1
  addRow(events[i].height, 1)
  for (let k = 0; k < K; k++) {
    row[k] = basis[k].db0[i]
    row[K + k] = basis[k].db90[i]
  }
  row[2 * K] = 0
  addRow(0, WD)
}

const prior = new Float64Array(P)
for (let k = 0; k < K; k++) {
  const c = ST_HELIER_CONSTITUENTS.find(c => c.name === basis[k].name)
  if (c) {
    const g = c.phase_GMT * Math.PI / 180
    prior[k] = c.amplitude * Math.cos(g)
    prior[K + k] = c.amplitude * Math.sin(g)
  }
}
prior[2 * K] = DATUM
for (let k = 0; k < K; k++) {
  const sigma = SIGMAS[basis[k].name] ?? DEFAULT_SIGMA
  const lambda = 1 / (sigma * sigma)
  for (const i of [k, K + k]) {
    AtA[i][i] += lambda
    Atb[i] += lambda * prior[i]
  }
}
{
  const lambdaZ = 1 / (0.1 * 0.1)
  AtA[2 * K][2 * K] += lambdaZ
  Atb[2 * K] += lambdaZ * prior[2 * K]
}

// solve (Gaussian elimination with partial pivoting)
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
const theta = M.map(r => r[P])

// --- report + write ---------------------------------------------------------
const fitted = basis.map(({ name }, k) => {
  const x = theta[k]
  const y = theta[K + k]
  const amplitude = Math.hypot(x, y)
  let phase = Math.atan2(y, x) * 180 / Math.PI
  if (phase < 0) phase += 360
  return { name, amplitude: +amplitude.toFixed(4), phase_GMT: +phase.toFixed(2) }
})
const datum = +theta[2 * K].toFixed(4)

console.log(`\nfitted datum Z0 = ${datum} (was ${DATUM})`)
console.log('name      A_fit   g_fit   |  A_prior  g_prior')
for (const f of fitted) {
  const c = ST_HELIER_CONSTITUENTS.find(c => c.name === f.name)
  console.log(
    `${f.name.padEnd(6)} ${f.amplitude.toFixed(4).padStart(8)} ${f.phase_GMT.toFixed(1).padStart(7)}  | ` +
    (c ? `${c.amplitude.toFixed(4).padStart(8)} ${c.phase_GMT.toFixed(1).padStart(8)}` : '     new        -')
  )
}

writeFileSync(outPath, JSON.stringify({
  datum,
  constituents: fitted.filter(f => f.amplitude >= 0.0005),
}, null, 2))
console.log(`\nwrote ${outPath}`)
