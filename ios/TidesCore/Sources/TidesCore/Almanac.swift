import Foundation

/// Zero-dependency astronomical almanac. Sun rise/set from the NOAA solar
/// calculator (fractional-century solar position, equation of time, hour
/// angle at zenith 90.833°). Moon phase angle from Meeus "Astronomical
/// Algorithms": Sun longitude ch.25 low-precision, Moon longitude ch.47 main
/// periodic terms. Quadrature times from Meeus ch.49 "Phases of the Moon".
///
/// Port of `packages/core/src/almanac.ts`. All civil-day handling is
/// timezone-explicit via TideTime.swift.

/// Sunrise, sunset and day length for one civil day.
public struct SunTimes: Sendable, Equatable {
    public let sunrise: Date?
    public let sunset: Date?
    public let dayLength: DayLength?
}

/// Day length split into whole hours and rounded minutes.
public struct DayLength: Sendable, Equatable {
    public let hours: Int
    public let minutes: Int

    public init(hours: Int, minutes: Int) {
        self.hours = hours
        self.minutes = minutes
    }
}

/// Moon phase for an instant.
public struct MoonPhaseInfo: Sendable, Equatable {
    /// 0–360°: 0 new, 90 first quarter, 180 full, 270 last quarter.
    public let phaseAngle: Double
    public let name: String
    public let emoji: String
    /// Elongation-based illumination percentage, 0–100.
    public let illumination: Int
}

/// One of the four principal moon phases.
public enum MoonPhaseType: String, Sendable {
    case new
    case firstQuarter = "first_quarter"
    case full
    case lastQuarter = "last_quarter"
}

/// An exact principal-phase event.
public struct MoonPhaseEvent: Sendable, Equatable {
    public let type: MoonPhaseType
    public let name: String
    public let emoji: String
    public let time: Date
}

private let DEG = Double.pi / 180
private let DAY_MS = 86_400_000.0
private let J2000_JD = 2_451_545.0
private let UNIX_EPOCH_JD = 2_440_587.5

/// Same double-mod idiom as the engine's `mod360`.
private func norm360(_ deg: Double) -> Double {
    ((deg.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360)
}

/// TT−UT in seconds, Espenak & Meeus 2005–2050 polynomial.
private func deltaTSeconds(_ utcMs: Double) -> Double {
    let y = 1970 + utcMs / 31_556_952_000
    let t = y - 2000
    return 62.92 + 0.32217 * t + 0.005589 * t * t
}

/// Julian centuries of Terrestrial Time since J2000.0 for a UTC instant.
/// (Computes JD directly from epoch ms — unlike the tide engine's
/// calendar-field JD. Both are kept as-is.)
private func centuriesTT(_ utcMs: Double) -> Double {
    let jd = (utcMs + deltaTSeconds(utcMs) * 1000) / DAY_MS + UNIX_EPOCH_JD
    return (jd - J2000_JD) / 36525
}

// MARK: - Sun (NOAA solar calculator)

/// Geometric geocentric ecliptic longitude of the Sun (Meeus ch.25), degrees.
private func sunLongitude(_ T: Double) -> Double {
    let L0 = 280.46646 + T * (36000.76983 + T * 0.0003032)
    let M = (357.52911 + T * (35999.05029 - T * 0.0001537)) * DEG
    let C =
        (1.914602 - T * (0.004817 + T * 0.000014)) * sin(M) +
        (0.019993 - T * 0.000101) * sin(2 * M) +
        0.000289 * sin(3 * M)
    return norm360(L0 + C)
}

/// Solar declination (radians) and equation of time (minutes).
private func solarCoords(_ T: Double) -> (declRad: Double, eqTimeMin: Double) {
    let L0 = norm360(280.46646 + T * (36000.76983 + T * 0.0003032))
    let M = norm360(357.52911 + T * (35999.05029 - T * 0.0001537))
    let e = 0.016708634 - T * (0.000042037 + T * 0.0000001267)
    let Mr = M * DEG
    let C =
        (1.914602 - T * (0.004817 + T * 0.000014)) * sin(Mr) +
        (0.019993 - T * 0.000101) * sin(2 * Mr) +
        0.000289 * sin(3 * Mr)
    let omega = (125.04 - 1934.136 * T) * DEG
    let lambda = (L0 + C - 0.00569 - 0.00478 * sin(omega)) * DEG
    let eps0 = 23 + (26 + (21.448 - T * (46.815 + T * (0.00059 - T * 0.001813))) / 60) / 60
    let eps = (eps0 + 0.00256 * cos(omega)) * DEG
    let declRad = asin(sin(eps) * sin(lambda))
    let y = tan(eps / 2) * tan(eps / 2)
    let L0r = L0 * DEG
    let eqTimeMin =
        (4 / DEG) *
        (y * sin(2 * L0r) -
            2 * e * sin(Mr) +
            4 * e * y * sin(Mr) * cos(2 * L0r) -
            0.5 * y * y * sin(4 * L0r) -
            1.25 * e * e * sin(2 * Mr))
    return (declRad, eqTimeMin)
}

private let ZENITH_COS = cos(90.833 * DEG)

/// Sunrise or sunset (UTC ms, fractional) attributed to the UTC day starting
/// at `utcMidnightMs`, or nil when the sun never crosses the horizon.
private func solarEventUtcMs(
    utcMidnightMs: Double,
    latitude: Double,
    longitude: Double,
    rise: Bool
) -> Double? {
    let latR = latitude * DEG
    var minutes = 720 - 4 * longitude
    for _ in 0 ..< 3 {
        let coords = solarCoords(centuriesTT(utcMidnightMs + minutes * 60_000))
        let cosHa = (ZENITH_COS - sin(latR) * sin(coords.declRad)) / (cos(latR) * cos(coords.declRad))
        if cosHa < -1 || cosHa > 1 {
            return nil
        }
        let haDeg = acos(cosHa) / DEG
        minutes = 720 - 4 * (longitude + (rise ? haDeg : -haDeg)) - coords.eqTimeMin
    }
    return utcMidnightMs + minutes * 60_000
}

/// First matching event in `[startMs, endMs)`, truncated to whole ms like the
/// JS `Date` wrap.
private func solarEventInWindow(
    startMs: Double,
    endMs: Double,
    latitude: Double,
    longitude: Double,
    rise: Bool
) -> Double? {
    let firstMidnight = (startMs / DAY_MS).rounded(.down) * DAY_MS
    var m = firstMidnight
    while m < endMs {
        if let t = solarEventUtcMs(utcMidnightMs: m, latitude: latitude, longitude: longitude, rise: rise),
           t >= startMs, t < endMs {
            return t.rounded(.towardZero)
        }
        m += DAY_MS
    }
    return nil
}

/// Sunrise, sunset and day length within the civil day in `timeZone`.
public func getSunTimes(
    _ day: CalendarDay,
    latitude: Double = StHelier.latitude,
    longitude: Double = StHelier.longitude,
    timeZone: TimeZone = StHelier.timeZone
) -> SunTimes {
    let bounds = dayBoundsUtc(day, timeZone: timeZone)
    let startMs = bounds.start.msSinceEpoch
    let endMs = bounds.end.msSinceEpoch
    let sunriseMs = solarEventInWindow(startMs: startMs, endMs: endMs, latitude: latitude, longitude: longitude, rise: true)
    let sunsetMs = solarEventInWindow(startMs: startMs, endMs: endMs, latitude: latitude, longitude: longitude, rise: false)

    var dayLength: DayLength?
    if let sunriseMs, let sunsetMs {
        let diff = sunsetMs - sunriseMs
        dayLength = DayLength(
            hours: Int((diff / 3_600_000).rounded(.down)),
            minutes: Int((diff.truncatingRemainder(dividingBy: 3_600_000) / 60_000).rounded())
        )
    }

    return SunTimes(
        sunrise: sunriseMs.map { Date(msSinceEpoch: $0) },
        sunset: sunsetMs.map { Date(msSinceEpoch: $0) },
        dayLength: dayLength
    )
}

/// Sunrise, sunset and day length for the civil day `date` falls on in `timeZone`.
public func getSunTimes(
    on date: Date,
    latitude: Double = StHelier.latitude,
    longitude: Double = StHelier.longitude,
    timeZone: TimeZone = StHelier.timeZone
) -> SunTimes {
    getSunTimes(calendarDayOf(date, timeZone: timeZone), latitude: latitude, longitude: longitude, timeZone: timeZone)
}

// MARK: - Moon longitude (Meeus ch.47 main periodic terms)

/// `[D, M, M', F, coefficient in 1e-6 degrees]` for Σl (Meeus table 47.A).
/// Terms with |M| = 1 are scaled by E, |M| = 2 by E².
private let MOON_L_TERMS: [(d: Double, m: Double, mp: Double, f: Double, coef: Double)] = [
    (0, 0, 1, 0, 6288774),
    (2, 0, -1, 0, 1274027),
    (2, 0, 0, 0, 658314),
    (0, 0, 2, 0, 213618),
    (0, 1, 0, 0, -185116),
    (0, 0, 0, 2, -114332),
    (2, 0, -2, 0, 58793),
    (2, -1, -1, 0, 57066),
    (2, 0, 1, 0, 53322),
    (2, -1, 0, 0, 45758),
    (0, 1, -1, 0, -40923),
    (1, 0, 0, 0, -34720),
    (0, 1, 1, 0, -30383),
    (2, 0, 0, -2, 15327),
    (0, 0, 1, 2, -12528),
    (0, 0, 1, -2, 10980),
    (4, 0, -1, 0, 10675),
    (0, 0, 3, 0, 10034),
    (4, 0, -2, 0, 8548),
    (2, 1, -1, 0, -7888),
    (2, 1, 0, 0, -6766),
    (1, 0, -1, 0, -5163),
    (1, 1, 0, 0, 4987),
    (2, -1, 1, 0, 4036),
    (2, 0, 2, 0, 3994),
    (4, 0, 0, 0, 3861),
    (2, 0, -3, 0, 3665),
    (0, 1, -2, 0, -2689),
    (2, 0, -1, 2, -2602),
    (2, -1, -2, 0, 2390),
    (1, 0, 1, 0, -2348),
    (2, -2, 0, 0, 2236),
    (0, 1, 2, 0, -2120),
    (0, 2, 0, 0, -2069),
    (2, -2, -1, 0, 2048),
    (2, 0, 1, -2, -1773),
    (2, 0, 0, 2, -1595),
    (4, -1, -1, 0, 1215),
    (0, 0, 2, 2, -1110),
    (3, 0, -1, 0, -892),
    (2, 1, 1, 0, -810),
    (4, -1, -2, 0, 759),
    (0, 2, -1, 0, -713),
    (2, 2, -1, 0, -700),
    (2, 1, -2, 0, 691),
    (2, -1, 0, -2, 596),
    (4, 0, 1, 0, 549),
    (0, 0, 4, 0, 537),
    (4, -1, 0, 0, 520),
    (1, 0, -2, 0, -487),
    (2, 1, 0, -2, -399),
    (0, 0, 2, -2, -381),
    (1, 1, 1, 0, 351),
    (3, 0, -2, 0, -340),
    (4, 0, -3, 0, 330),
    (2, -1, 2, 0, 327),
    (0, 2, 1, 0, -323),
    (1, 1, -1, 0, 299),
    (2, 0, 3, 0, 294),
]

/// Geocentric ecliptic longitude of the Moon (Meeus ch.47), degrees.
private func moonLongitude(_ T: Double) -> Double {
    let T2 = T * T
    let T3 = T2 * T
    let T4 = T3 * T
    let Lp = 218.3164477 + 481267.88123421 * T - 0.0015786 * T2 + T3 / 538841 - T4 / 65_194_000
    let D = (297.8501921 + 445267.1114034 * T - 0.0018819 * T2 + T3 / 545868 - T4 / 113_065_000) * DEG
    let M = (357.5291092 + 35999.0502909 * T - 0.0001536 * T2 + T3 / 24_490_000) * DEG
    let Mp = (134.9633964 + 477198.8675055 * T + 0.0087414 * T2 + T3 / 69699 - T4 / 14_712_000) * DEG
    let F = (93.272095 + 483202.0175233 * T - 0.0036539 * T2 - T3 / 3_526_000 + T4 / 863_310_000) * DEG
    let A1 = (119.75 + 131.849 * T) * DEG
    let A2 = (53.09 + 479264.29 * T) * DEG
    let E = 1 - 0.002516 * T - 0.0000074 * T2
    let E2 = E * E

    var sum = 0.0
    for term in MOON_L_TERMS {
        let scale = term.m == 1 || term.m == -1 ? E : term.m == 2 || term.m == -2 ? E2 : 1
        sum += term.coef * scale * sin(term.d * D + term.m * M + term.mp * Mp + term.f * F)
    }
    sum += 3958 * sin(A1) + 1962 * sin(Lp * DEG - F) + 318 * sin(A2)

    return norm360(Lp + sum / 1e6)
}

/// Moon phase for an instant.
public func getMoonPhase(_ date: Date) -> MoonPhaseInfo {
    let T = centuriesTT(date.msSinceEpoch)
    let phaseAngle = norm360(moonLongitude(T) - sunLongitude(T))
    let illumination = Int((50 * (1 - cos(phaseAngle * DEG))).rounded())

    // Tight ranges for major phases (~1 day = ~12°), rest are transitional.
    let name: String
    let emoji: String
    if phaseAngle < 6 || phaseAngle >= 354 {
        name = "New Moon"
        emoji = "\u{1F311}"
    } else if phaseAngle < 84 {
        name = "Waxing Crescent"
        emoji = "\u{1F312}"
    } else if phaseAngle < 96 {
        name = "First Quarter"
        emoji = "\u{1F313}"
    } else if phaseAngle < 174 {
        name = "Waxing Gibbous"
        emoji = "\u{1F314}"
    } else if phaseAngle < 186 {
        name = "Full Moon"
        emoji = "\u{1F315}"
    } else if phaseAngle < 264 {
        name = "Waning Gibbous"
        emoji = "\u{1F316}"
    } else if phaseAngle < 276 {
        name = "Last Quarter"
        emoji = "\u{1F317}"
    } else {
        name = "Waning Crescent"
        emoji = "\u{1F318}"
    }

    return MoonPhaseInfo(phaseAngle: phaseAngle, name: name, emoji: emoji, illumination: illumination)
}

// MARK: - Moon quadratures (Meeus ch.49 "Phases of the Moon")

private let PHASE_META: [(type: MoonPhaseType, name: String, emoji: String)] = [
    (.new, "New Moon", "\u{1F311}"),
    (.firstQuarter, "First Quarter", "\u{1F313}"),
    (.full, "Full Moon", "\u{1F315}"),
    (.lastQuarter, "Last Quarter", "\u{1F317}"),
]

/// Correction series shared by new and full moon; the first 16 coefficients
/// differ between the two, the tail is common (Meeus p.351).
private let NEW_MOON_COEFFS: [Double] = [
    -0.4072, 0.17241, 0.01608, 0.01039, 0.00739, -0.00514, 0.00208, -0.00111,
    -0.00057, 0.00056, -0.00042, 0.00042, 0.00038, -0.00024, -0.00017, -0.00007,
]
private let FULL_MOON_COEFFS: [Double] = [
    -0.40614, 0.17302, 0.01614, 0.01043, 0.00734, -0.00515, 0.00209, -0.00111,
    -0.00057, 0.00056, -0.00042, 0.00042, 0.00038, -0.00024, -0.00017, -0.00007,
]

/// JDE (TT) of quadrature `quarter` (0 new, 1 first, 2 full, 3 last) of the
/// given integer lunation, converted to a UTC ms timestamp (fractional).
private func quadratureUtcMs(lunation: Int, quarter: Int) -> Double {
    let k = Double(lunation) + Double(quarter) / 4
    let T = k / 1236.85
    let T2 = T * T
    let T3 = T2 * T
    let T4 = T3 * T

    var jde = 2451550.09766 + 29.530588861 * k + 0.00015437 * T2 - 0.00000015 * T3 + 0.00000000073 * T4

    let E = 1 - 0.002516 * T - 0.0000074 * T2
    let E2 = E * E
    let M = (2.5534 + 29.1053567 * k - 0.0000014 * T2 - 0.00000011 * T3) * DEG
    let Mp = (201.5643 + 385.81693528 * k + 0.0107582 * T2 + 0.00001238 * T3 - 0.000000058 * T4) * DEG
    let F = (160.7108 + 390.67050284 * k - 0.0016118 * T2 - 0.00000227 * T3 + 0.000000011 * T4) * DEG
    let O = (124.7746 - 1.56375588 * k + 0.0020672 * T2 + 0.00000215 * T3) * DEG

    if quarter == 0 || quarter == 2 {
        let c = quarter == 0 ? NEW_MOON_COEFFS : FULL_MOON_COEFFS
        jde +=
            c[0] * sin(Mp) +
            c[1] * E * sin(M) +
            c[2] * sin(2 * Mp) +
            c[3] * sin(2 * F) +
            c[4] * E * sin(Mp - M) +
            c[5] * E * sin(Mp + M) +
            c[6] * E2 * sin(2 * M) +
            c[7] * sin(Mp - 2 * F) +
            c[8] * sin(Mp + 2 * F) +
            c[9] * E * sin(2 * Mp + M) +
            c[10] * sin(3 * Mp) +
            c[11] * E * sin(M + 2 * F) +
            c[12] * E * sin(M - 2 * F) +
            c[13] * E * sin(2 * Mp - M) +
            c[14] * sin(O) +
            c[15] * sin(Mp + 2 * M) +
            0.00004 * sin(2 * Mp - 2 * F) +
            0.00004 * sin(3 * M) +
            0.00003 * sin(Mp + M - 2 * F) +
            0.00003 * sin(2 * Mp + 2 * F) -
            0.00003 * sin(Mp + M + 2 * F) +
            0.00003 * sin(Mp - M + 2 * F) -
            0.00002 * sin(Mp - M - 2 * F) -
            0.00002 * sin(3 * Mp + M) +
            0.00002 * sin(4 * Mp)
    } else {
        jde +=
            -0.62801 * sin(Mp) +
            0.17172 * E * sin(M) -
            0.01183 * E * sin(Mp + M) +
            0.00862 * sin(2 * Mp) +
            0.00804 * sin(2 * F) +
            0.00454 * E * sin(Mp - M) +
            0.00204 * E2 * sin(2 * M) -
            0.0018 * sin(Mp - 2 * F) -
            0.0007 * sin(Mp + 2 * F) -
            0.0004 * sin(3 * Mp) -
            0.00034 * E * sin(2 * Mp - M) +
            0.00032 * E * sin(M + 2 * F) +
            0.00032 * E * sin(M - 2 * F) -
            0.00028 * E2 * sin(Mp + 2 * M) +
            0.00027 * E * sin(2 * Mp + M) -
            0.00017 * sin(O) -
            0.00005 * sin(Mp - M - 2 * F) +
            0.00004 * sin(2 * Mp + 2 * F) -
            0.00004 * sin(Mp + M + 2 * F) +
            0.00004 * sin(Mp - 2 * M) +
            0.00003 * sin(Mp + M - 2 * F) +
            0.00003 * sin(3 * M) +
            0.00002 * sin(2 * Mp - 2 * F) +
            0.00002 * sin(Mp - M + 2 * F) -
            0.00002 * sin(3 * Mp + M)
        let W =
            0.00306 -
            0.00038 * E * cos(M) +
            0.00026 * cos(Mp) -
            0.00002 * cos(Mp - M) +
            0.00002 * cos(Mp + M) +
            0.00002 * cos(2 * F)
        jde += quarter == 1 ? W : -W
    }

    // Additional corrections for planetary perturbations (all phases).
    let A: [(coef: Double, angle: Double)] = [
        (0.000325, 299.77 + 0.107408 * k - 0.009173 * T2),
        (0.000165, 251.88 + 0.016321 * k),
        (0.000164, 251.83 + 26.651886 * k),
        (0.000126, 349.42 + 36.412478 * k),
        (0.00011, 84.66 + 18.206239 * k),
        (0.000062, 141.74 + 53.303771 * k),
        (0.00006, 207.14 + 2.453732 * k),
        (0.000056, 154.84 + 7.30686 * k),
        (0.000047, 34.52 + 27.261239 * k),
        (0.000042, 207.19 + 0.121824 * k),
        (0.00004, 291.34 + 1.844379 * k),
        (0.000037, 161.72 + 24.198154 * k),
        (0.000035, 239.56 + 25.513099 * k),
        (0.000023, 331.55 + 3.592518 * k),
    ]
    for term in A {
        jde += term.coef * sin(term.angle * DEG)
    }

    let ttMs = (jde - UNIX_EPOCH_JD) * DAY_MS
    return ttMs - deltaTSeconds(ttMs) * 1000
}

/// Exact times of the four principal moon phases within `[start, end]`
/// (inclusive both ends). `end` defaults to 30 days after `start`.
public func getMoonPhaseEvents(from start: Date, to end: Date? = nil) -> [MoonPhaseEvent] {
    let startMs = start.msSinceEpoch
    let endMs = end?.msSinceEpoch ?? startMs + 30 * DAY_MS

    // Approximate lunation number at `start` (Meeus 49.2), backed off by one
    // so quarters of the preceding lunation that fall inside the range are
    // found. `floor`, not trunc — matters pre-2000.
    let yearFrac = 2000 + (startMs / DAY_MS + UNIX_EPOCH_JD - J2000_JD) / 365.25
    var lunation = Int(((yearFrac - 2000) * 12.3685).rounded(.down)) - 1

    var events: [MoonPhaseEvent] = []
    while quadratureUtcMs(lunation: lunation, quarter: 0) <= endMs {
        for quarter in 0 ..< 4 {
            let t = quadratureUtcMs(lunation: lunation, quarter: quarter)
            if t >= startMs, t <= endMs {
                let meta = PHASE_META[quarter]
                events.append(MoonPhaseEvent(
                    type: meta.type,
                    name: meta.name,
                    emoji: meta.emoji,
                    time: Date(msSinceEpoch: t.rounded(.towardZero))
                ))
            }
        }
        lunation += 1
    }

    events.sort { $0.time < $1.time }
    return events
}

/// Principal moon phase events of a month, keyed by the civil day-of-month
/// the event falls on in `timeZone`. `month` is 1-based.
public func getMonthMoonPhaseEvents(
    year: Int,
    month: Int,
    timeZone: TimeZone = StHelier.timeZone
) -> [Int: MoonPhaseEvent] {
    let first = CalendarDay(year: year, month: month, day: 1)
    let nextFirst = month == 12
        ? CalendarDay(year: year + 1, month: 1, day: 1)
        : CalendarDay(year: year, month: month + 1, day: 1)
    let start = dayBoundsUtc(first, timeZone: timeZone).start
    let end = dayBoundsUtc(nextFirst, timeZone: timeZone).start

    let events = getMoonPhaseEvents(from: start, to: Date(msSinceEpoch: end.msSinceEpoch - 1))
    var eventsByDay: [Int: MoonPhaseEvent] = [:]
    for event in events {
        eventsByDay[calendarDayOf(event.time, timeZone: timeZone).day] = event
    }
    return eventsByDay
}
