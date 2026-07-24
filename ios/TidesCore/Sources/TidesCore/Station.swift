import Foundation

/// Station wrapper (datum + civil-day queries) and the St Helier station data.
///
/// Port of `packages/core/src/station.ts` and
/// `packages/core/src/stations/st-helier{.data,}.ts`.

/// A tide station: harmonic constants plus datum and civil-day metadata.
public struct StationDefinition: Sendable {
    public let id: String
    public let name: String
    public let latitude: Double
    public let longitude: Double
    /// Timezone the station's calendar days are reckoned in.
    public let timeZone: TimeZone
    /// Chart datum offset in metres (added to predictor output).
    public let datum: Double
    public let constituents: [HarmonicConstant]

    public init(
        id: String,
        name: String,
        latitude: Double,
        longitude: Double,
        timeZone: TimeZone,
        datum: Double,
        constituents: [HarmonicConstant]
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.timeZone = timeZone
        self.datum = datum
        self.constituents = constituents
    }
}

/// A high or low water with datum-inclusive height.
public struct TideExtreme: Sendable {
    public let time: Date
    public let height: Double
    public let type: TideExtremeType
}

/// Instantaneous tide state.
public struct CurrentTide: Sendable {
    public let height: Double
    public let rising: Bool
    public let nextExtreme: TideExtreme?
}

/// One point of a day's tide curve.
public struct TimelinePoint: Sendable {
    public let time: Date
    public let height: Double
}

/// A tide station bound to its predictor.
public struct Station: Sendable {
    public let definition: StationDefinition
    let predictor: Predictor

    public init(_ definition: StationDefinition) throws {
        self.definition = definition
        predictor = try Predictor(constants: definition.constituents)
    }

    /// Tide height above chart datum in metres.
    public func levelAt(_ t: Date) -> Double {
        definition.datum + predictor.levelAt(ms: t.msSinceEpoch)
    }

    /// d(height)/dt in metres/hour (no datum — it's a derivative).
    public func slopeAt(_ t: Date) -> Double {
        predictor.slopeAt(ms: t.msSinceEpoch)
    }

    /// All high/low extremes in `[from, to)`.
    public func extremes(from: Date, to: Date) -> [TideExtreme] {
        predictor.extremes(startMs: from.msSinceEpoch, endMs: to.msSinceEpoch).map(withDatum)
    }

    /// Extremes for a calendar day in the station's timezone.
    public func dayExtremes(_ day: CalendarDay) -> [TideExtreme] {
        let bounds = dayBoundsUtc(day, timeZone: definition.timeZone)
        let startMs = bounds.start.msSinceEpoch
        let endMs = bounds.end.msSinceEpoch
        // Pad the search window so an extreme falling exactly at midnight is
        // still bracketed by the slope-sign scan, then filter back to the day.
        let padMs = 60.0 * 60 * 1000
        return predictor.extremes(startMs: startMs - padMs, endMs: endMs + padMs)
            .filter { $0.time.msSinceEpoch >= startMs && $0.time.msSinceEpoch < endMs }
            .map(withDatum)
    }

    /// Extremes for the calendar day `date` falls on in the station's timezone.
    public func dayExtremes(on date: Date) -> [TideExtreme] {
        dayExtremes(calendarDayOf(date, timeZone: definition.timeZone))
    }

    /// Height, direction and next extreme (searched over today + tomorrow).
    public func currentLevel(now: Date = Date()) -> CurrentTide {
        let height = levelAt(now)
        let today = calendarDayOf(now, timeZone: definition.timeZone)
        let candidates = dayExtremes(today) + dayExtremes(addDays(today, 1))
        let nextExtreme = candidates.first { $0.time > now }
        return CurrentTide(
            height: height,
            rising: nextExtreme?.type == .high,
            nextExtreme: nextExtreme
        )
    }

    /// Evenly spaced heights across a calendar day in the station's timezone
    /// (end-inclusive: a 24 h day at 6/hour yields 145 points).
    public func timeline(_ day: CalendarDay, pointsPerHour: Int = 6) -> [TimelinePoint] {
        let bounds = dayBoundsUtc(day, timeZone: definition.timeZone)
        let startMs = bounds.start.msSinceEpoch
        let endMs = bounds.end.msSinceEpoch
        let intervalMs = (60.0 / Double(pointsPerHour)) * 60 * 1000
        var points: [TimelinePoint] = []
        var t = startMs
        while t <= endMs {
            points.append(TimelinePoint(
                time: Date(msSinceEpoch: t),
                height: definition.datum + predictor.levelAt(ms: t)
            ))
            t += intervalMs
        }
        return points
    }

    /// Timeline for the calendar day `date` falls on in the station's timezone.
    public func timeline(on date: Date, pointsPerHour: Int = 6) -> [TimelinePoint] {
        timeline(calendarDayOf(date, timeZone: definition.timeZone), pointsPerHour: pointsPerHour)
    }

    private func withDatum(_ e: Extreme) -> TideExtreme {
        TideExtreme(time: e.time, height: definition.datum + e.level, type: e.type)
    }
}

/// St Helier, Jersey — coordinates (PSMSL 1795), chart datum and the fitted
/// harmonic constants.
public enum StHelier {
    public static let latitude = 49.183
    public static let longitude = -2.117

    /// Chart datum offset (metres above LAT — Lowest Astronomical Tide).
    public static let datum = 6.0887

    public static let timeZone = TimeZone(identifier: "Europe/Jersey")!

    /// Harmonic constituents for St Helier — fitted to official gov.je / NOC
    /// tide tables against THIS engine's V+u/f conventions (see
    /// st-helier.data.ts provenance). Values are verbatim; do not "correct".
    public static let constituents: [HarmonicConstant] = [
        // Semi-diurnal
        HarmonicConstant(name: "M2", amplitude: 3.338, phaseGMT: 180.01),
        HarmonicConstant(name: "S2", amplitude: 1.2763, phaseGMT: 229.34),
        HarmonicConstant(name: "N2", amplitude: 0.6662, phaseGMT: 163.01),
        HarmonicConstant(name: "K2", amplitude: 0.3371, phaseGMT: 232.9),
        HarmonicConstant(name: "L2", amplitude: 0.0928, phaseGMT: 190.2),
        HarmonicConstant(name: "T2", amplitude: 0.0686, phaseGMT: 226.37),
        HarmonicConstant(name: "R2", amplitude: 0.0131, phaseGMT: 263.41),
        HarmonicConstant(name: "2N2", amplitude: 0.0675, phaseGMT: 153.82),
        HarmonicConstant(name: "MU2", amplitude: 0.2575, phaseGMT: 190.22),
        HarmonicConstant(name: "NU2", amplitude: 0.0884, phaseGMT: 146.68),
        HarmonicConstant(name: "LAM2", amplitude: 0.0705, phaseGMT: 159.47),
        HarmonicConstant(name: "2SM2", amplitude: 0.0624, phaseGMT: 38.2),
        HarmonicConstant(name: "MA2", amplitude: 0.0275, phaseGMT: 87.7),
        HarmonicConstant(name: "MB2", amplitude: 0.0087, phaseGMT: 264.85),
        HarmonicConstant(name: "MSN2", amplitude: 0.0326, phaseGMT: 359.78),
        HarmonicConstant(name: "MNS2", amplitude: 0.0454, phaseGMT: 126.97),
        HarmonicConstant(name: "MKS2", amplitude: 0.0489, phaseGMT: 283.3),
        HarmonicConstant(name: "2MN2", amplitude: 0.0123, phaseGMT: 273.05),
        // Diurnal
        HarmonicConstant(name: "K1", amplitude: 0.0842, phaseGMT: 98.02),
        HarmonicConstant(name: "O1", amplitude: 0.0728, phaseGMT: 346.26),
        HarmonicConstant(name: "P1", amplitude: 0.0368, phaseGMT: 89.38),
        HarmonicConstant(name: "Q1", amplitude: 0.0241, phaseGMT: 306.83),
        HarmonicConstant(name: "J1", amplitude: 0.0043, phaseGMT: 119.98),
        HarmonicConstant(name: "M1", amplitude: 0.0025, phaseGMT: 347.21),
        HarmonicConstant(name: "S1", amplitude: 0.0044, phaseGMT: 69.52),
        HarmonicConstant(name: "OO1", amplitude: 0.0023, phaseGMT: 171.05),
        HarmonicConstant(name: "2Q1", amplitude: 0.002, phaseGMT: 239.65),
        HarmonicConstant(name: "RHO", amplitude: 0.0042, phaseGMT: 307.49),
        // Ter-diurnal
        HarmonicConstant(name: "M3", amplitude: 0.0253, phaseGMT: 171.39),
        HarmonicConstant(name: "MK3", amplitude: 0.0112, phaseGMT: 244.84),
        HarmonicConstant(name: "2MK3", amplitude: 0.0064, phaseGMT: 127.18),
        HarmonicConstant(name: "MO3", amplitude: 0.0056, phaseGMT: 109.83),
        HarmonicConstant(name: "SO3", amplitude: 0.0023, phaseGMT: 247.7),
        HarmonicConstant(name: "SK3", amplitude: 0.0079, phaseGMT: 276.91),
        // Quarter-diurnal
        HarmonicConstant(name: "M4", amplitude: 0.2102, phaseGMT: 282.09),
        HarmonicConstant(name: "MN4", amplitude: 0.0442, phaseGMT: 272.12),
        HarmonicConstant(name: "MS4", amplitude: 0.1523, phaseGMT: 327.41),
        HarmonicConstant(name: "S4", amplitude: 0.0148, phaseGMT: 351.81),
        HarmonicConstant(name: "MK4", amplitude: 0.035, phaseGMT: 343.22),
        HarmonicConstant(name: "SN4", amplitude: 0.0112, phaseGMT: 4.1),
        HarmonicConstant(name: "SK4", amplitude: 0.0056, phaseGMT: 65.02),
        // Fifth-diurnal
        HarmonicConstant(name: "2MK5", amplitude: 0.0016, phaseGMT: 348.14),
        HarmonicConstant(name: "2MO5", amplitude: 0.0028, phaseGMT: 61.77),
        // Sixth-diurnal
        HarmonicConstant(name: "M6", amplitude: 0.0649, phaseGMT: 322.25),
        HarmonicConstant(name: "S6", amplitude: 0.005, phaseGMT: 280.14),
        HarmonicConstant(name: "2MS6", amplitude: 0.0283, phaseGMT: 18.55),
        HarmonicConstant(name: "2MN6", amplitude: 0.0426, phaseGMT: 301.04),
        HarmonicConstant(name: "MSN6", amplitude: 0.0152, phaseGMT: 328.5),
        HarmonicConstant(name: "2SM6", amplitude: 0.0015, phaseGMT: 120.28),
        HarmonicConstant(name: "MSK6", amplitude: 0.0098, phaseGMT: 11.46),
        // Seventh-diurnal
        HarmonicConstant(name: "3MK7", amplitude: 0.001, phaseGMT: 216.12),
        HarmonicConstant(name: "3MO7", amplitude: 0.0029, phaseGMT: 290.28),
        // Eighth-diurnal and higher
        HarmonicConstant(name: "M8", amplitude: 0.0201, phaseGMT: 92.56),
        HarmonicConstant(name: "3MS8", amplitude: 0.0306, phaseGMT: 129.29),
        HarmonicConstant(name: "2MS8", amplitude: 0.0114, phaseGMT: 170.49),
        HarmonicConstant(name: "2MSN8", amplitude: 0.0043, phaseGMT: 94.82),
        HarmonicConstant(name: "M10", amplitude: 0.0083, phaseGMT: 101.33),
        // Long period
        HarmonicConstant(name: "SA", amplitude: 0.0619, phaseGMT: 219.79),
        HarmonicConstant(name: "SSA", amplitude: 0.0262, phaseGMT: 114.75),
        HarmonicConstant(name: "MM", amplitude: 0.0182, phaseGMT: 185.25),
        HarmonicConstant(name: "MF", amplitude: 0.0146, phaseGMT: 187.17),
        HarmonicConstant(name: "MSF", amplitude: 0.0061, phaseGMT: 203.53),
    ]

    public static let definition = StationDefinition(
        id: "st-helier",
        name: "St Helier, Jersey",
        latitude: latitude,
        longitude: longitude,
        timeZone: timeZone,
        datum: datum,
        constituents: constituents
    )

    /// The ready-to-use St Helier station. Every constituent name is in the
    /// catalog, so construction cannot fail.
    public static let station = try! Station(definition)
}
