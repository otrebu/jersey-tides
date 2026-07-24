import Foundation
import TidesCore

/// The real engine: adapts the `TideEngine` facade onto the TidesCore SwiftPM
/// package (fixture-parity Swift port of `packages/core`) per design doc §12.
///
/// Naming note: TidesCore exports `CalendarDay`/`TideExtreme`/`TimelinePoint`/
/// `SunTimes` types that collide with this module's facade DTOs — unqualified
/// names here resolve to the facade's (current module wins), and TidesCore
/// values cross the seam through the `on: Date` overloads + type inference, so
/// the shadowed names never need qualifying.
struct TidesCoreEngine: TideEngine {
    private let station: Station

    init(station: Station = StHelier.station) {
        self.station = station
    }

    /// "St Helier" — definition name without the ", Jersey" suffix (the
    /// island is already the About row's context: "Station: St Helier").
    var stationName: String {
        station.definition.name.components(separatedBy: ",")[0]
    }

    /// The npm `@u-b/tides-core` version this port tracks (About footer:
    /// "engine v0.1.0").
    var engineVersion: String {
        TidesCore.trackingVersion
    }

    // MARK: Levels

    func levelAt(_ instant: Date) -> Double {
        station.levelAt(instant)
    }

    func slopeAt(_ instant: Date) -> Double {
        station.slopeAt(instant)
    }

    // MARK: Extremes + timeline

    func extremes(from: Date, to: Date) -> [TideExtreme] {
        station.extremes(from: from, to: to).map {
            TideExtreme(time: $0.time, height: $0.height, kind: $0.type == .high ? .high : .low)
        }
    }

    func dayExtremes(_ day: CalendarDay) -> [TideExtreme] {
        station.dayExtremes(on: noon(day)).map {
            TideExtreme(time: $0.time, height: $0.height, kind: $0.type == .high ? .high : .low)
        }
    }

    func timeline(_ day: CalendarDay, samplesPerHour: Int) -> [TimelinePoint] {
        station.timeline(on: noon(day), pointsPerHour: samplesPerHour)
            .map { TimelinePoint(time: $0.time, height: $0.height) }
    }

    // MARK: Almanac

    func sunTimes(_ day: CalendarDay) -> SunTimes? {
        let sun = getSunTimes(on: noon(day))
        var dayLength: TimeInterval?
        if let sunrise = sun.sunrise, let sunset = sun.sunset {
            dayLength = sunset.timeIntervalSince(sunrise)
        }
        return SunTimes(sunrise: sun.sunrise, sunset: sun.sunset, dayLength: dayLength)
    }

    func moonPhase(at instant: Date) -> MoonPhase {
        let info = getMoonPhase(instant)
        // Phase angle (0–360°, 0 = new) → age through the mean synodic month.
        let ageDays = info.phaseAngle / 360 * 29.530588861
        let symbolName: String
        switch info.name {
        case "New Moon": symbolName = "moonphase.new.moon"
        case "Waxing Crescent": symbolName = "moonphase.waxing.crescent"
        case "First Quarter": symbolName = "moonphase.first.quarter"
        case "Waxing Gibbous": symbolName = "moonphase.waxing.gibbous"
        case "Full Moon": symbolName = "moonphase.full.moon"
        case "Waning Gibbous": symbolName = "moonphase.waning.gibbous"
        case "Last Quarter": symbolName = "moonphase.last.quarter"
        default: symbolName = "moonphase.waning.crescent"
        }
        return MoonPhase(
            ageDays: ageDays,
            name: info.name.lowercased(),
            systemImageName: symbolName
        )
    }

    func moonEvents(around instant: Date) -> [MoonEvent] {
        // ±1 lunation window (facade contract); already time-sorted.
        let halfWindow: TimeInterval = 30 * 86_400
        return getMoonPhaseEvents(
            from: instant.addingTimeInterval(-halfWindow),
            to: instant.addingTimeInterval(halfWindow)
        )
        .map { event in
            let kind: MoonEventKind
            switch event.type {
            case .new: kind = .newMoon
            case .firstQuarter: kind = .firstQuarter
            case .full: kind = .fullMoon
            case .lastQuarter: kind = .lastQuarter
            }
            return MoonEvent(date: event.time, kind: kind)
        }
    }

    // MARK: Helpers

    /// Noon local on the facade day — always inside the same civil day (DST
    /// shifts touch only the early morning), so the `on: Date` TidesCore
    /// overloads resolve to the identical calendar day.
    private func noon(_ day: CalendarDay) -> Date {
        TideTime.date(day, hour: 12, minute: 0)
    }
}
