/**
 * Self-contained tidal harmonic prediction engine. Zero dependencies.
 *
 * Ported from @neaps/tide-predictor v0.2.1 (MIT, https://github.com/neaps/tide-predictor)
 * with three changes:
 *  - astronomical arguments use UTC calendar fields (neaps used local time, so its
 *    output depended on the host timezone)
 *  - extended shallow-water/compound constituent catalog (MK4, 2MS6, MA2/MB2, ...)
 *  - analytic time-derivative of the tide level, so extremes are located by Newton
 *    iteration instead of a sampling lattice
 *
 * Constants fitted against this engine are convention-bound to it: amplitude/phase
 * pairs absorb this engine's V+u/f definitions and are not portable to other engines.
 */

const d2r = Math.PI / 180
const r2d = 180 / Math.PI

// --- astronomy -------------------------------------------------------------

const sexagesimal = (deg: number, min = 0, sec = 0) => deg + min / 60 + sec / 3600

const COEFFS = {
  terrestrialObliquity: [
    sexagesimal(23, 26, 21.448),
    -sexagesimal(0, 0, 4680.93),
    -sexagesimal(0, 0, 1.55),
    sexagesimal(0, 0, 1999.25),
    -sexagesimal(0, 0, 51.38),
    -sexagesimal(0, 0, 249.67),
    -sexagesimal(0, 0, 39.05),
    sexagesimal(0, 0, 7.12),
    sexagesimal(0, 0, 27.87),
    sexagesimal(0, 0, 5.79),
    sexagesimal(0, 0, 2.45),
  ].map((n, i) => n * Math.pow(0.01, i)),
  solarPerigee: [-77.06265000000002, 1.7190199999968172, 4591e-7, 48e-8],
  solarLongitude: [280.46645, 36000.76983, 3032e-7],
  lunarInclination: [5.145],
  lunarLongitude: [218.3164591, 481267.88134236, -0.0013268, 1 / 538841 - 1 / 65194e3],
  lunarNode: [125.044555, -1934.1361849, 0.0020762, 1 / 467410, -1 / 60616e3],
  lunarPerigee: [83.353243, 4069.0137111, -0.0103238, -1 / 80053, 1 / 18999e3],
}

const polynomial = (c: number[], x: number) => c.reduce((s, v, i) => s + v * Math.pow(x, i), 0)
const dPolynomial = (c: number[], x: number) => c.reduce((s, v, i) => s + v * i * Math.pow(x, i - 1), 0)

// Julian date from UTC calendar fields (Meeus). neaps used local fields here.
const JD = (t: Date): number => {
  let Y = t.getUTCFullYear()
  let M = t.getUTCMonth() + 1
  const D =
    t.getUTCDate() +
    t.getUTCHours() / 24 +
    t.getUTCMinutes() / 1440 +
    t.getUTCSeconds() / 86400 +
    t.getUTCMilliseconds() / 86400000
  if (M <= 2) {
    Y -= 1
    M += 12
  }
  const A = Math.floor(Y / 100)
  const B = 2 - A + Math.floor(A / 4)
  return Math.floor(365.25 * (Y + 4716)) + Math.floor(30.6001 * (M + 1)) + D + B - 1524.5
}

const T = (t: Date) => (JD(t) - 2451545) / 36525

const mod360 = (a: number) => ((a % 360) + 360) % 360

const _I = (N: number, i: number, omega: number) => {
  N *= d2r; i *= d2r; omega *= d2r
  const cosI = Math.cos(i) * Math.cos(omega) - Math.sin(i) * Math.sin(omega) * Math.cos(N)
  return r2d * Math.acos(cosI)
}
const xiNu = (N: number, i: number, omega: number) => {
  N *= d2r; i *= d2r; omega *= d2r
  let e1 = Math.atan((Math.cos(0.5 * (omega - i)) / Math.cos(0.5 * (omega + i))) * Math.tan(0.5 * N)) - 0.5 * N
  let e2 = Math.atan((Math.sin(0.5 * (omega - i)) / Math.sin(0.5 * (omega + i))) * Math.tan(0.5 * N)) - 0.5 * N
  return { xi: -(e1 + e2) * r2d, nu: (e1 - e2) * r2d }
}
const _nup = (I: number, nu: number) => {
  I *= d2r; nu *= d2r
  return r2d * Math.atan((Math.sin(2 * I) * Math.sin(nu)) / (Math.sin(2 * I) * Math.cos(nu) + 0.3347))
}
const _nupp = (I: number, nu: number) => {
  I *= d2r; nu *= d2r
  const tan2 = (Math.sin(I) ** 2 * Math.sin(2 * nu)) / (Math.sin(I) ** 2 * Math.cos(2 * nu) + 0.0727)
  return r2d * 0.5 * Math.atan(tan2)
}

export interface AstroValue { value: number; speed: number | null }
export type Astro = Record<string, AstroValue>

export const astro = (time: Date): Astro => {
  const result: Astro = {}
  const polys: Record<string, number[]> = {
    s: COEFFS.lunarLongitude,
    h: COEFFS.solarLongitude,
    p: COEFFS.lunarPerigee,
    N: COEFFS.lunarNode,
    pp: COEFFS.solarPerigee,
    '90': [90],
    omega: COEFFS.terrestrialObliquity,
    i: COEFFS.lunarInclination,
  }
  const dTdHour = 1 / (24 * 365.25 * 100)
  const tt = T(time)
  for (const name in polys) {
    result[name] = {
      value: mod360(polynomial(polys[name], tt)),
      speed: dPolynomial(polys[name], tt) * dTdHour,
    }
  }
  const I = _I(result.N.value, result.i.value, result.omega.value)
  const { xi, nu } = xiNu(result.N.value, result.i.value, result.omega.value)
  result.I = { value: mod360(I), speed: null }
  result.xi = { value: mod360(xi), speed: null }
  result.nu = { value: mod360(nu), speed: null }
  result.nup = { value: mod360(_nup(I, nu)), speed: null }
  result.nupp = { value: mod360(_nupp(I, nu)), speed: null }
  const hour = { value: (JD(time) - Math.floor(JD(time))) * 360, speed: 15 }
  result['T+h-s'] = {
    value: hour.value + result.h.value - result.s.value,
    speed: hour.speed + (result.h.speed as number) - (result.s.speed as number),
  }
  result.P = { value: mod360(result.p.value - result.xi.value), speed: null }
  return result
}

// --- nodal corrections (Schureman) ------------------------------------------

type FU = (a: Astro) => number
const fUnity: FU = () => 1
const uZero: FU = () => 0

const fMm: FU = (a) => {
  const omega = d2r * a.omega.value, i = d2r * a.i.value, I = d2r * a.I.value
  const mean = (2 / 3 - Math.sin(omega) ** 2) * (1 - (3 / 2) * Math.sin(i) ** 2)
  return (2 / 3 - Math.sin(I) ** 2) / mean
}
const fMf: FU = (a) => {
  const omega = d2r * a.omega.value, i = d2r * a.i.value, I = d2r * a.I.value
  return Math.sin(I) ** 2 / (Math.sin(omega) ** 2 * Math.cos(0.5 * i) ** 4)
}
const fO1: FU = (a) => {
  const omega = d2r * a.omega.value, i = d2r * a.i.value, I = d2r * a.I.value
  const mean = Math.sin(omega) * Math.cos(0.5 * omega) ** 2 * Math.cos(0.5 * i) ** 4
  return (Math.sin(I) * Math.cos(0.5 * I) ** 2) / mean
}
const fJ1: FU = (a) => {
  const omega = d2r * a.omega.value, i = d2r * a.i.value, I = d2r * a.I.value
  return Math.sin(2 * I) / (Math.sin(2 * omega) * (1 - (3 / 2) * Math.sin(i) ** 2))
}
const fOO1: FU = (a) => {
  const omega = d2r * a.omega.value, i = d2r * a.i.value, I = d2r * a.I.value
  const mean = Math.sin(omega) * Math.sin(0.5 * omega) ** 2 * Math.cos(0.5 * i) ** 4
  return (Math.sin(I) * Math.sin(0.5 * I) ** 2) / mean
}
const fM2: FU = (a) => {
  const omega = d2r * a.omega.value, i = d2r * a.i.value, I = d2r * a.I.value
  return Math.cos(0.5 * I) ** 4 / (Math.cos(0.5 * omega) ** 4 * Math.cos(0.5 * i) ** 4)
}
const fK1: FU = (a) => {
  const omega = d2r * a.omega.value, i = d2r * a.i.value, I = d2r * a.I.value, nu = d2r * a.nu.value
  const mean = 0.5023 * (Math.sin(2 * omega) * (1 - (3 / 2) * Math.sin(i) ** 2)) + 0.1681
  return Math.pow(0.2523 * Math.sin(2 * I) ** 2 + 0.1689 * Math.sin(2 * I) * Math.cos(nu) + 0.0283, 0.5) / mean
}
const fL2: FU = (a) => {
  const P = d2r * a.P.value, I = d2r * a.I.value
  const rAInv = Math.pow(1 - 12 * Math.tan(0.5 * I) ** 2 * Math.cos(2 * P) + 36 * Math.tan(0.5 * I) ** 4, 0.5)
  return fM2(a) * rAInv
}
const fK2: FU = (a) => {
  const omega = d2r * a.omega.value, i = d2r * a.i.value, I = d2r * a.I.value, nu = d2r * a.nu.value
  const mean = 0.5023 * (Math.sin(omega) ** 2 * (1 - (3 / 2) * Math.sin(i) ** 2)) + 0.0365
  return Math.pow(0.2523 * Math.sin(I) ** 4 + 0.0367 * Math.sin(I) ** 2 * Math.cos(2 * nu) + 0.0013, 0.5) / mean
}
const fM1: FU = (a) => {
  const P = d2r * a.P.value, I = d2r * a.I.value
  const qAInv = Math.pow(
    0.25 + 1.5 * Math.cos(I) * Math.cos(2 * P) * Math.cos(0.5 * I) ** -0.5 + 2.25 * Math.cos(I) ** 2 * Math.cos(0.5 * I) ** -4,
    0.5
  )
  return fO1(a) * qAInv
}
const uMf: FU = (a) => -2 * a.xi.value
const uO1: FU = (a) => 2 * a.xi.value - a.nu.value
const uJ1: FU = (a) => -a.nu.value
const uOO1: FU = (a) => -2 * a.xi.value - a.nu.value
const uM2: FU = (a) => 2 * a.xi.value - 2 * a.nu.value
const uK1: FU = (a) => -a.nup.value
const uL2: FU = (a) => {
  const I = d2r * a.I.value, P = d2r * a.P.value
  const R = r2d * Math.atan(Math.sin(2 * P) / ((1 / 6) * Math.tan(0.5 * I) ** -2 - Math.cos(2 * P)))
  return 2 * a.xi.value - 2 * a.nu.value - R
}
const uK2: FU = (a) => -2 * a.nupp.value
const uM1: FU = (a) => {
  const I = d2r * a.I.value, P = d2r * a.P.value
  const Q = r2d * Math.atan(((5 * Math.cos(I) - 1) / (7 * Math.cos(I) + 1)) * Math.tan(P))
  return a.xi.value - a.nu.value + Q
}

// --- constituents ------------------------------------------------------------

export interface Constituent {
  name: string
  coefficients: number[]
  value: (a: Astro) => number
  speed: (a: Astro) => number
  u: FU
  f: FU
}

const DOODSON_KEYS = ['T+h-s', 's', 'h', 'p', 'N', 'pp', '90'] as const

const base = (name: string, coefficients: number[], u: FU = uZero, f: FU = fUnity): Constituent => ({
  name,
  coefficients,
  value: (a) => coefficients.reduce((s, c, i) => s + c * a[DOODSON_KEYS[i]].value, 0),
  speed: (a) => coefficients.reduce((s, c, i) => s + c * (a[DOODSON_KEYS[i]].speed ?? 0), 0),
  u,
  f,
})

const compound = (name: string, members: Array<{ c: Constituent; factor: number }>): Constituent => ({
  name,
  coefficients: DOODSON_KEYS.map((_, i) => members.reduce((s, m) => s + (m.c.coefficients[i] ?? 0) * m.factor, 0)),
  value: (a) => members.reduce((s, m) => s + m.c.value(a) * m.factor, 0),
  speed: (a) => members.reduce((s, m) => s + m.c.speed(a) * m.factor, 0),
  u: (a) => members.reduce((s, m) => s + m.c.u(a) * m.factor, 0),
  f: (a) => members.reduce((s, m) => s * Math.pow(m.c.f(a), Math.abs(m.factor)), 1),
})

const C: Record<string, Constituent> = {}
C.Z0 = base('Z0', [0, 0, 0, 0, 0, 0, 0])
C.SA = base('SA', [0, 0, 1, 0, 0, 0, 0])
C.SSA = base('SSA', [0, 0, 2, 0, 0, 0, 0])
C.MM = base('MM', [0, 1, 0, -1, 0, 0, 0], uZero, fMm)
C.MF = base('MF', [0, 2, 0, 0, 0, 0, 0], uMf, fMf)
C.Q1 = base('Q1', [1, -2, 0, 1, 0, 0, 1], uO1, fO1)
C.O1 = base('O1', [1, -1, 0, 0, 0, 0, 1], uO1, fO1)
C.K1 = base('K1', [1, 1, 0, 0, 0, 0, -1], uK1, fK1)
C.J1 = base('J1', [1, 2, 0, -1, 0, 0, -1], uJ1, fJ1)
C.M1 = base('M1', [1, 0, 0, 0, 0, 0, 1], uM1, fM1)
C.P1 = base('P1', [1, 1, -2, 0, 0, 0, 1])
C.S1 = base('S1', [1, 1, -1, 0, 0, 0, 0])
C.OO1 = base('OO1', [1, 3, 0, 0, 0, 0, -1], uOO1, fOO1)
C['2N2'] = base('2N2', [2, -2, 0, 2, 0, 0, 0], uM2, fM2)
C.N2 = base('N2', [2, -1, 0, 1, 0, 0, 0], uM2, fM2)
C.NU2 = base('NU2', [2, -1, 2, -1, 0, 0, 0], uM2, fM2)
C.M2 = base('M2', [2, 0, 0, 0, 0, 0, 0], uM2, fM2)
C.LAM2 = base('LAM2', [2, 1, -2, 1, 0, 0, 2], uM2, fM2)
C.L2 = base('L2', [2, 1, 0, -1, 0, 0, 2], uL2, fL2)
C.T2 = base('T2', [2, 2, -3, 0, 0, 1, 0])
C.S2 = base('S2', [2, 2, -2, 0, 0, 0, 0])
C.R2 = base('R2', [2, 2, -1, 0, 0, -1, 2])
C.K2 = base('K2', [2, 2, 0, 0, 0, 0, 0], uK2, fK2)
C.M3 = base('M3', [3, 0, 0, 0, 0, 0, 0], (a) => 1.5 * uM2(a), (a) => Math.pow(fM2(a), 1.5))
// compounds (as in neaps)
C.MSF = compound('MSF', [{ c: C.S2, factor: 1 }, { c: C.M2, factor: -1 }])
C['2Q1'] = compound('2Q1', [{ c: C.N2, factor: 1 }, { c: C.J1, factor: -1 }])
C.RHO = compound('RHO', [{ c: C.NU2, factor: 1 }, { c: C.K1, factor: -1 }])
C.MU2 = compound('MU2', [{ c: C.M2, factor: 2 }, { c: C.S2, factor: -1 }])
C['2SM2'] = compound('2SM2', [{ c: C.S2, factor: 2 }, { c: C.M2, factor: -1 }])
C['2MK3'] = compound('2MK3', [{ c: C.M2, factor: 1 }, { c: C.O1, factor: 1 }])
C.MK3 = compound('MK3', [{ c: C.M2, factor: 1 }, { c: C.K1, factor: 1 }])
C.MN4 = compound('MN4', [{ c: C.M2, factor: 1 }, { c: C.N2, factor: 1 }])
C.M4 = compound('M4', [{ c: C.M2, factor: 2 }])
C.MS4 = compound('MS4', [{ c: C.M2, factor: 1 }, { c: C.S2, factor: 1 }])
C.S4 = compound('S4', [{ c: C.S2, factor: 2 }])
C.M6 = compound('M6', [{ c: C.M2, factor: 3 }])
C.S6 = compound('S6', [{ c: C.S2, factor: 3 }])
C.M8 = compound('M8', [{ c: C.M2, factor: 4 }])
// extended shallow-water catalog (beyond neaps)
C.MA2 = compound('MA2', [{ c: C.M2, factor: 1 }, { c: C.SA, factor: -1 }])
C.MB2 = compound('MB2', [{ c: C.M2, factor: 1 }, { c: C.SA, factor: 1 }])
C.MSN2 = compound('MSN2', [{ c: C.M2, factor: 1 }, { c: C.S2, factor: 1 }, { c: C.N2, factor: -1 }])
C.MNS2 = compound('MNS2', [{ c: C.M2, factor: 1 }, { c: C.N2, factor: 1 }, { c: C.S2, factor: -1 }])
C.MKS2 = compound('MKS2', [{ c: C.M2, factor: 1 }, { c: C.K2, factor: 1 }, { c: C.S2, factor: -1 }])
C.MO3 = compound('MO3', [{ c: C.M2, factor: 1 }, { c: C.O1, factor: 1 }])
C.SO3 = compound('SO3', [{ c: C.S2, factor: 1 }, { c: C.O1, factor: 1 }])
C.SK3 = compound('SK3', [{ c: C.S2, factor: 1 }, { c: C.K1, factor: 1 }])
C.MK4 = compound('MK4', [{ c: C.M2, factor: 1 }, { c: C.K2, factor: 1 }])
C.SN4 = compound('SN4', [{ c: C.S2, factor: 1 }, { c: C.N2, factor: 1 }])
C.SK4 = compound('SK4', [{ c: C.S2, factor: 1 }, { c: C.K2, factor: 1 }])
C['2MS6'] = compound('2MS6', [{ c: C.M2, factor: 2 }, { c: C.S2, factor: 1 }])
C['2MN6'] = compound('2MN6', [{ c: C.M2, factor: 2 }, { c: C.N2, factor: 1 }])
C.MSN6 = compound('MSN6', [{ c: C.M2, factor: 1 }, { c: C.S2, factor: 1 }, { c: C.N2, factor: 1 }])
C['2SM6'] = compound('2SM6', [{ c: C.S2, factor: 2 }, { c: C.M2, factor: 1 }])
C.MSK6 = compound('MSK6', [{ c: C.M2, factor: 1 }, { c: C.S2, factor: 1 }, { c: C.K2, factor: 1 }])
C['3MS8'] = compound('3MS8', [{ c: C.M2, factor: 3 }, { c: C.S2, factor: 1 }])
C['2MS8'] = compound('2MS8', [{ c: C.M2, factor: 2 }, { c: C.S2, factor: 2 }])
C['2MSN8'] = compound('2MSN8', [{ c: C.M2, factor: 2 }, { c: C.S2, factor: 1 }, { c: C.N2, factor: 1 }])
C.M10 = compound('M10', [{ c: C.M2, factor: 5 }])
C['2MK5'] = compound('2MK5', [{ c: C.M2, factor: 2 }, { c: C.K1, factor: 1 }])
C['2SK5'] = compound('2SK5', [{ c: C.S2, factor: 2 }, { c: C.K1, factor: 1 }])
C['2MO5'] = compound('2MO5', [{ c: C.M2, factor: 2 }, { c: C.O1, factor: 1 }])
C['3MK7'] = compound('3MK7', [{ c: C.M2, factor: 3 }, { c: C.K1, factor: 1 }])
C['3MO7'] = compound('3MO7', [{ c: C.M2, factor: 3 }, { c: C.O1, factor: 1 }])
C['2MN2'] = compound('2MN2', [{ c: C.M2, factor: 2 }, { c: C.N2, factor: -1 }])

export const CATALOG = C

// --- prediction ---------------------------------------------------------------

export interface HarmonicConstant {
  name: string
  amplitude: number
  phase_GMT: number
}

export interface Extreme {
  time: Date
  level: number
  high: boolean
  low: boolean
}

export interface BasisSample {
  /** f·cos(V+u) — multiply by A·cos(g) */
  c: number
  /** f·sin(V+u) — multiply by A·sin(g) */
  s: number
  /** d/dt of c in 1/hour */
  dc: number
  /** d/dt of s in 1/hour */
  ds: number
}

/** Evaluate the harmonic basis for the given constituent names at time t. */
export function evalBasis(names: string[], t: Date): BasisSample[] {
  const a = astro(t)
  return names.map((name) => {
    const model = C[name]
    if (!model) throw new Error(`Unknown constituent: ${name}`)
    const theta = d2r * (model.value(a) + model.u(a))
    const omega = d2r * model.speed(a) // rad/hour
    const f = model.f(a)
    return {
      c: f * Math.cos(theta),
      s: f * Math.sin(theta),
      dc: -f * omega * Math.sin(theta),
      ds: f * omega * Math.cos(theta),
    }
  })
}

export interface Predictor {
  /** metres above datum-reference (add your Z0/datum offset externally) */
  levelAt(t: Date): number
  /** d(level)/dt in metres/hour */
  slopeAt(t: Date): number
  /** All high/low extremes in [start, end), located by Newton iteration (sub-second). */
  extremes(start: Date, end: Date): Extreme[]
}

export function createPredictor(constants: HarmonicConstant[]): Predictor {
  const known = constants.filter((c) => C[c.name])
  const unknown = constants.filter((c) => !C[c.name])
  if (unknown.length) throw new Error(`Unknown constituents: ${unknown.map((c) => c.name).join(', ')}`)
  const names = known.map((c) => c.name)
  const x = known.map((c) => c.amplitude * Math.cos(d2r * c.phase_GMT))
  const y = known.map((c) => c.amplitude * Math.sin(d2r * c.phase_GMT))

  const levelAt = (t: Date) => {
    const b = evalBasis(names, t)
    let sum = 0
    for (let k = 0; k < b.length; k++) sum += x[k] * b[k].c + y[k] * b[k].s
    return sum
  }
  const slopeAt = (t: Date) => {
    const b = evalBasis(names, t)
    let sum = 0
    for (let k = 0; k < b.length; k++) sum += x[k] * b[k].dc + y[k] * b[k].ds
    return sum
  }

  const extremes = (start: Date, end: Date): Extreme[] => {
    const out: Extreme[] = []
    const STEP_MIN = 20
    let tPrev = start
    let sPrev = slopeAt(tPrev)
    for (let t = start.getTime() + STEP_MIN * 60000; t <= end.getTime() + STEP_MIN * 60000; t += STEP_MIN * 60000) {
      const tCur = new Date(t)
      const sCur = slopeAt(tCur)
      if (sPrev === 0 || sPrev * sCur < 0) {
        // bracketed a stationary point: bisect then polish with secant on slope
        let lo = tPrev.getTime()
        let hi = tCur.getTime()
        let sLo = sPrev
        for (let i = 0; i < 40 && hi - lo > 500; i++) {
          const mid = 0.5 * (lo + hi)
          const sMid = slopeAt(new Date(mid))
          if (sLo * sMid <= 0) {
            hi = mid
          } else {
            lo = mid
            sLo = sMid
          }
        }
        const tExt = new Date(0.5 * (lo + hi))
        if (tExt >= start && tExt < end) {
          // classify by second derivative sign (finite difference of slope)
          const h = 10 * 60000
          const curv = slopeAt(new Date(tExt.getTime() + h)) - slopeAt(new Date(tExt.getTime() - h))
          const high = curv < 0
          out.push({ time: tExt, level: levelAt(tExt), high, low: !high })
        }
      }
      tPrev = tCur
      sPrev = sCur
    }
    return out
  }

  return { levelAt, slopeAt, extremes }
}
