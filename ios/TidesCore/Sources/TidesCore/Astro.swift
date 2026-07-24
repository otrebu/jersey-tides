import Foundation

/// Astronomical arguments for the tidal harmonic engine.
///
/// Swift port of the astronomy section of `packages/core/src/engine.ts`
/// (itself ported from @neaps/tide-predictor v0.2.1, MIT). The formulas are
/// deliberately identical — including summation order, single-argument `atan`
/// quadrant folding and the double-mod normalisation — because the St Helier
/// harmonic constants are fitted to this exact V+u/f convention.

/// Degrees to radians.
let d2r = Double.pi / 180
/// Radians to degrees.
let r2d = 180 / Double.pi

/// `deg + min/60 + sec/3600`.
func sexagesimal(_ deg: Double, _ min: Double = 0, _ sec: Double = 0) -> Double {
    deg + min / 60 + sec / 3600
}

/// Polynomial coefficient tables (ascending powers of Julian centuries).
enum AstroCoeffs {
    /// Obliquity of the ecliptic; element i is scaled by 0.01^i exactly as in TS.
    static let terrestrialObliquity: [Double] = [
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
    ].enumerated().map { i, n in n * pow(0.01, Double(i)) }

    static let solarPerigee: [Double] = [-77.06265000000002, 1.7190199999968172, 4591e-7, 48e-8]
    static let solarLongitude: [Double] = [280.46645, 36000.76983, 3032e-7]
    static let lunarInclination: [Double] = [5.145]
    static let lunarLongitude: [Double] = [218.3164591, 481267.88134236, -0.0013268, 1.0 / 538841 - 1.0 / 65194e3]
    static let lunarNode: [Double] = [125.044555, -1934.1361849, 0.0020762, 1.0 / 467410, -1.0 / 60616e3]
    static let lunarPerigee: [Double] = [83.353243, 4069.0137111, -0.0103238, -1.0 / 80053, 1.0 / 18999e3]
}

/// `Σ c[i]·x^i` — ascending index with `pow`, matching the TS reduce exactly.
func polynomial(_ c: [Double], _ x: Double) -> Double {
    var sum = 0.0
    for (i, v) in c.enumerated() {
        sum += v * pow(x, Double(i))
    }
    return sum
}

/// `Σ c[i]·i·x^(i-1)` — the i = 0 term is identically zero, so start at 1
/// (avoids the JS `0·pow(x,-1)` NaN at x == 0 exactly).
func dPolynomial(_ c: [Double], _ x: Double) -> Double {
    var sum = 0.0
    for i in 1 ..< c.count {
        sum += c[i] * Double(i) * pow(x, Double(i - 1))
    }
    return sum
}

/// Julian Date from UTC calendar fields (Meeus 7.1), fed by an epoch-ms
/// instant. Fractional ms are truncated toward zero first — the JS engine only
/// ever sees whole-ms `Date`s (ECMAScript TimeClip).
func julianDate(ms: Double) -> Double {
    let m = ms.rounded(.towardZero)
    let dayIndex = (m / 86_400_000).rounded(.down)
    let msOfDay = m - dayIndex * 86_400_000
    let civil = civilFromDays(Int(dayIndex))
    let hours = (msOfDay / 3_600_000).rounded(.down)
    let minutes = (msOfDay / 60_000).rounded(.down).truncatingRemainder(dividingBy: 60)
    let seconds = (msOfDay / 1000).rounded(.down).truncatingRemainder(dividingBy: 60)
    let millis = msOfDay.truncatingRemainder(dividingBy: 1000)

    var Y = civil.year
    var M = civil.month
    let D = Double(civil.day) + hours / 24 + minutes / 1440 + seconds / 86400 + millis / 86_400_000
    if M <= 2 {
        Y -= 1
        M += 12
    }
    let A = (Double(Y) / 100).rounded(.down)
    let B = 2 - A + (A / 4).rounded(.down)
    return (365.25 * (Double(Y) + 4716)).rounded(.down) + (30.6001 * Double(M + 1)).rounded(.down) + D + B - 1524.5
}

/// Julian centuries of Universal Time since J2000 (deliberately no ΔT).
func julianCenturies(ms: Double) -> Double {
    (julianDate(ms: ms) - 2451545) / 36525
}

/// Wrap an angle into [0, 360). The double-mod idiom is required: a single
/// `truncatingRemainder` leaves negative inputs negative, like JS `%`.
func mod360(_ a: Double) -> Double {
    ((a.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360)
}

/// Obliquity of the lunar orbit w.r.t. the equator, degrees.
private func inclinationI(_ N: Double, _ i: Double, _ omega: Double) -> Double {
    let N = N * d2r, i = i * d2r, omega = omega * d2r
    let cosI = cos(i) * cos(omega) - sin(i) * sin(omega) * cos(N)
    return r2d * acos(cosI)
}

/// Schureman's ξ and ν, degrees. Single-argument `atan` on purpose — the
/// quadrant folding is part of the convention the constants were fitted to.
private func xiNu(_ N: Double, _ i: Double, _ omega: Double) -> (xi: Double, nu: Double) {
    let N = N * d2r, i = i * d2r, omega = omega * d2r
    let e1 = atan((cos(0.5 * (omega - i)) / cos(0.5 * (omega + i))) * tan(0.5 * N)) - 0.5 * N
    let e2 = atan((sin(0.5 * (omega - i)) / sin(0.5 * (omega + i))) * tan(0.5 * N)) - 0.5 * N
    return (xi: -(e1 + e2) * r2d, nu: (e1 - e2) * r2d)
}

private func nupOf(_ I: Double, _ nu: Double) -> Double {
    let I = I * d2r, nu = nu * d2r
    return r2d * atan((sin(2 * I) * sin(nu)) / (sin(2 * I) * cos(nu) + 0.3347))
}

private func nuppOf(_ I: Double, _ nu: Double) -> Double {
    let I = I * d2r, nu = nu * d2r
    let tan2 = (sin(I) * sin(I) * sin(2 * nu)) / (sin(I) * sin(I) * cos(2 * nu) + 0.0727)
    return r2d * 0.5 * atan(tan2)
}

/// The full set of astronomical arguments at one instant, degrees.
///
/// The Doodson arrays are ordered `[T+h-s, s, h, p, N, pp, 90]` — the key
/// order constituent coefficients are expressed in. "T+h-s" is deliberately
/// NOT normalised to [0, 360).
public struct Astro: Sendable {
    /// Doodson-key values in degrees.
    public let doodsonValues: [Double]
    /// Doodson-key speeds in degrees/hour ("90" is stationary).
    public let doodsonSpeeds: [Double]
    /// Obliquity of the ecliptic ω, degrees in [0, 360).
    public let omega: Double
    /// Lunar orbit inclination i, degrees in [0, 360).
    public let i: Double
    /// Inclination I of the lunar orbit to the equator, degrees in [0, 360).
    public let I: Double
    /// Schureman ξ, degrees in [0, 360).
    public let xi: Double
    /// Schureman ν, degrees in [0, 360).
    public let nu: Double
    /// Schureman ν′, degrees in [0, 360).
    public let nup: Double
    /// Schureman ν″, degrees in [0, 360).
    public let nupp: Double
    /// P = p − ξ, degrees in [0, 360).
    public let P: Double
}

/// Astronomical arguments at an epoch-ms instant.
func astroAt(ms: Double) -> Astro {
    let dTdHour = 1.0 / (24 * 365.25 * 100)
    let tt = julianCenturies(ms: ms)

    func entry(_ coeffs: [Double]) -> (value: Double, speed: Double) {
        (value: mod360(polynomial(coeffs, tt)), speed: dPolynomial(coeffs, tt) * dTdHour)
    }

    let s = entry(AstroCoeffs.lunarLongitude)
    let h = entry(AstroCoeffs.solarLongitude)
    let p = entry(AstroCoeffs.lunarPerigee)
    let N = entry(AstroCoeffs.lunarNode)
    let pp = entry(AstroCoeffs.solarPerigee)
    let ninety = entry([90])
    let omega = entry(AstroCoeffs.terrestrialObliquity)
    let i = entry(AstroCoeffs.lunarInclination)

    // Derived angles consume the normalised values; nup/nupp consume the RAW
    // (pre-mod360) I and nu, exactly as in TS.
    let IRaw = inclinationI(N.value, i.value, omega.value)
    let (xiRaw, nuRaw) = xiNu(N.value, i.value, omega.value)
    let nup = mod360(nupOf(IRaw, nuRaw))
    let nupp = mod360(nuppOf(IRaw, nuRaw))
    let xi = mod360(xiRaw)

    // Hour angle: fraction of the Julian day (starts at noon UT) times 360.
    let jd = julianDate(ms: ms)
    let hourValue = (jd - jd.rounded(.down)) * 360
    let hourSpeed = 15.0

    let thsValue = hourValue + h.value - s.value
    let thsSpeed = hourSpeed + h.speed - s.speed

    return Astro(
        doodsonValues: [thsValue, s.value, h.value, p.value, N.value, pp.value, ninety.value],
        doodsonSpeeds: [thsSpeed, s.speed, h.speed, p.speed, N.speed, pp.speed, ninety.speed],
        omega: omega.value,
        i: i.value,
        I: mod360(IRaw),
        xi: xi,
        nu: mod360(nuRaw),
        nup: nup,
        nupp: nupp,
        P: mod360(p.value - xi)
    )
}

/// Astronomical arguments at `time`.
public func astro(_ time: Date) -> Astro {
    astroAt(ms: time.msSinceEpoch)
}
