import Foundation

/// Deterministic stand-in engine — M2 + S2 cosines phased so 2026-07-17 reads
/// as a St Helier springs day (HW ≈ 14:32 local, range ≈ 10.6 m), fixed sun
/// times 06:04/21:12, canned moon events around a 19 Jul 2026 full moon.
///
/// Exists so every UI chunk can build, run and screenshot before the TidesCore
/// port lands (implementation plan §1 "parallelism seam"). Swapped out in
/// `EngineProvider` by the integration chunk. Never imports TidesCore.
struct SyntheticEngine: TideEngine {
    let stationName = "St Helier"
    let engineVersion = "synthetic 0.1"

    /// Mean level above chart datum (m).
    private let meanLevel = 6.1
    /// Constituent amplitudes (m): M2 dominant, S2 the springs/neaps modulator.
    private let amplitudeM2 = 4.1
    private let amplitudeS2 = 1.2
    /// Angular speeds (rad/s): M2 period 12.4206012 h, S2 period 12 h.
    private let omegaM2 = 2 * Double.pi / (12.4206012 * 3600)
    private let omegaS2 = 2 * Double.pi / (12.0 * 3600)
    /// Both constituents crest together here → springs HW 14:32 local, 17 Jul 2026.
    private let referenceCrest = SyntheticEngine.utcDate(2026, 7, 17, 13, 32)

    /// Canned lunation anchor: full moon 19 Jul 2026 02:00 UTC.
    private static let referenceFullMoon = utcDate(2026, 7, 19, 2, 0)
    /// Mean synodic month in days.
    private let synodicDays = 29.530588

    // MARK: Levels

    func levelAt(_ instant: Date) -> Double {
        let dt = instant.timeIntervalSince(referenceCrest)
        return meanLevel + amplitudeM2 * cos(omegaM2 * dt) + amplitudeS2 * cos(omegaS2 * dt)
    }

    func slopeAt(_ instant: Date) -> Double {
        let dt = instant.timeIntervalSince(referenceCrest)
        let perSecond = -amplitudeM2 * omegaM2 * sin(omegaM2 * dt)
            - amplitudeS2 * omegaS2 * sin(omegaS2 * dt)
        return perSecond * 3600
    }

    // MARK: Extremes

    func extremes(from: Date, to: Date) -> [TideExtreme] {
        guard to > from else { return [] }
        var result: [TideExtreme] = []
        let step: TimeInterval = 300
        var t = from
        var previousSlope = slopeAt(from)
        while t < to {
            let next = min(t.addingTimeInterval(step), to)
            let nextSlope = slopeAt(next)
            if previousSlope != 0, (previousSlope > 0) != (nextSlope > 0) {
                let instant = refineExtremum(between: t, and: next, wasRising: previousSlope > 0)
                let kind: TideKind = previousSlope > 0 ? .high : .low
                result.append(TideExtreme(time: instant, height: levelAt(instant), kind: kind))
            }
            previousSlope = nextSlope
            t = next
        }
        return result
    }

    func dayExtremes(_ day: CalendarDay) -> [TideExtreme] {
        let bounds = TideTime.dayBounds(day)
        return extremes(from: bounds.start, to: bounds.end)
    }

    func timeline(_ day: CalendarDay, samplesPerHour: Int) -> [TimelinePoint] {
        let bounds = TideTime.dayBounds(day)
        let step = 3600.0 / Double(max(samplesPerHour, 1))
        var points: [TimelinePoint] = []
        var t = bounds.start
        while t < bounds.end {
            points.append(TimelinePoint(time: t, height: levelAt(t)))
            t = t.addingTimeInterval(step)
        }
        points.append(TimelinePoint(time: bounds.end, height: levelAt(bounds.end)))
        return points
    }

    // MARK: Almanac

    func sunTimes(_ day: CalendarDay) -> SunTimes? {
        let sunrise = TideTime.date(day, hour: 6, minute: 4)
        let sunset = TideTime.date(day, hour: 21, minute: 12)
        return SunTimes(sunrise: sunrise, sunset: sunset, dayLength: sunset.timeIntervalSince(sunrise))
    }

    func moonPhase(at instant: Date) -> MoonPhase {
        let sinceFull = instant.timeIntervalSince(Self.referenceFullMoon) / 86_400
        var age = (sinceFull + synodicDays / 2).truncatingRemainder(dividingBy: synodicDays)
        if age < 0 { age += synodicDays }
        let names = [
            "new moon", "waxing crescent", "first quarter", "waxing gibbous",
            "full moon", "waning gibbous", "last quarter", "waning crescent",
        ]
        let symbols = [
            "moonphase.new.moon", "moonphase.waxing.crescent",
            "moonphase.first.quarter", "moonphase.waxing.gibbous",
            "moonphase.full.moon", "moonphase.waning.gibbous",
            "moonphase.last.quarter", "moonphase.waning.crescent",
        ]
        let index = Int((age / synodicDays * 8).rounded()) % 8
        return MoonPhase(ageDays: age, name: names[index], systemImageName: symbols[index])
    }

    func moonEvents(around instant: Date) -> [MoonEvent] {
        let quarter = synodicDays / 4 * 86_400
        // Quarter sequence walking forward from the reference full moon.
        let kinds: [MoonEventKind] = [.fullMoon, .lastQuarter, .newMoon, .firstQuarter]
        let offset = instant.timeIntervalSince(Self.referenceFullMoon)
        let centerIndex = Int((offset / quarter).rounded())
        var events: [MoonEvent] = []
        for index in (centerIndex - 5)...(centerIndex + 5) {
            let date = Self.referenceFullMoon.addingTimeInterval(Double(index) * quarter)
            let kind = kinds[((index % 4) + 4) % 4]
            events.append(MoonEvent(date: date, kind: kind))
        }
        return events.sorted { $0.date < $1.date }
    }

    // MARK: Helpers

    /// Bisects a slope sign change down to sub-second precision.
    private func refineExtremum(between lower: Date, and upper: Date, wasRising: Bool) -> Date {
        var lo = lower.timeIntervalSinceReferenceDate
        var hi = upper.timeIntervalSinceReferenceDate
        for _ in 0..<40 {
            let mid = (lo + hi) / 2
            let slope = slopeAt(Date(timeIntervalSinceReferenceDate: mid))
            if (slope > 0) == wasRising {
                lo = mid
            } else {
                hi = mid
            }
        }
        return Date(timeIntervalSinceReferenceDate: (lo + hi) / 2)
    }

    private static func utcDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        return calendar.date(from: components)!
    }
}
