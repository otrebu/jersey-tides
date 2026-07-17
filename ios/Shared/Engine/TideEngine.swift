import Foundation

// MARK: - Calendar day + time math (Europe/Jersey)

/// A calendar day in the station's local time zone (Europe/Jersey).
///
/// The day — not the clock hour — is the app's paging unit; all conversions to
/// instants go through `TideTime` so 23/25-hour DST days stay exact.
struct CalendarDay: Hashable, Codable, Comparable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    static func < (lhs: CalendarDay, rhs: CalendarDay) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

/// UTC instants of a local day's start and end (`start` = local midnight,
/// `end` = next local midnight). 23/25 hours on DST transition days.
struct DayBounds: Equatable, Sendable {
    let start: Date
    let end: Date

    var duration: TimeInterval { end.timeIntervalSince(start) }
}

/// Station-local calendar math — DST-correct by construction (Foundation).
/// Never lay anything out against wall-clock hours; use these bounds.
enum TideTime {
    /// Europe/Jersey — the station's civil time zone.
    static let timeZone = TimeZone(identifier: "Europe/Jersey")!

    /// Gregorian calendar pinned to the station time zone.
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }()

    /// The local calendar day containing an instant.
    static func calendarDay(of instant: Date) -> CalendarDay {
        let components = calendar.dateComponents([.year, .month, .day], from: instant)
        return CalendarDay(year: components.year!, month: components.month!, day: components.day!)
    }

    /// The day `delta` local days away (negative = past).
    static func addDays(_ day: CalendarDay, _ delta: Int) -> CalendarDay {
        let shifted = calendar.date(byAdding: .day, value: delta, to: startOfDay(day))!
        return calendarDay(of: shifted)
    }

    /// True local-midnight UTC bounds of a day (23/25 h on DST days).
    static func dayBounds(_ day: CalendarDay) -> DayBounds {
        let start = startOfDay(day)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return DayBounds(start: start, end: end)
    }

    /// Signed whole-day distance `to − from` in local days.
    static func daysBetween(_ from: CalendarDay, _ to: CalendarDay) -> Int {
        calendar.dateComponents([.day], from: startOfDay(from), to: startOfDay(to)).day!
    }

    /// A wall-clock instant on the given local day (DST resolved by Foundation).
    static func date(_ day: CalendarDay, hour: Int, minute: Int) -> Date {
        let components = DateComponents(
            year: day.year, month: day.month, day: day.day, hour: hour, minute: minute
        )
        return calendar.date(from: components)!
    }

    private static func startOfDay(_ day: CalendarDay) -> Date {
        let components = DateComponents(year: day.year, month: day.month, day: day.day)
        return calendar.startOfDay(for: calendar.date(from: components)!)
    }
}

// MARK: - Engine DTOs

enum TideKind: String, Codable, Sendable {
    case high
    case low
}

/// One high- or low-water event: exact instant + height in metres above chart datum.
struct TideExtreme: Hashable, Codable, Sendable {
    let time: Date
    let height: Double
    let kind: TideKind

    var isHigh: Bool { kind == .high }
}

/// One curve sample: instant + height in metres above chart datum.
struct TimelinePoint: Equatable, Codable, Sendable {
    let time: Date
    let height: Double
}

/// Sun events for one local day. Fields are nullable per the engine contract;
/// consumers skip ticks/rows silently when absent (design doc §10).
struct SunTimes: Equatable, Sendable {
    let sunrise: Date?
    let sunset: Date?
    let dayLength: TimeInterval?
}

enum MoonEventKind: String, Codable, CaseIterable, Sendable {
    case newMoon
    case firstQuarter
    case fullMoon
    case lastQuarter

    /// SF Symbol used in the Fortnight sheet and header captions.
    var systemImageName: String {
        switch self {
        case .newMoon: "moonphase.new.moon"
        case .firstQuarter: "moonphase.first.quarter"
        case .fullMoon: "moonphase.full.moon"
        case .lastQuarter: "moonphase.last.quarter"
        }
    }

    /// Lowercase caption noun ("full moon in 2 d").
    var captionName: String {
        switch self {
        case .newMoon: "new moon"
        case .firstQuarter: "first quarter"
        case .fullMoon: "full moon"
        case .lastQuarter: "last quarter"
        }
    }
}

/// A quarter-phase event instant.
struct MoonEvent: Equatable, Sendable {
    let date: Date
    let kind: MoonEventKind
}

/// Moon phase at an instant (header glyph + accessibility).
struct MoonPhase: Equatable, Sendable {
    /// Age in days since the preceding new moon, `0..<29.53`.
    let ageDays: Double
    /// Human name ("waxing gibbous").
    let name: String
    /// SF Symbol name ("moonphase.waxing.gibbous").
    let systemImageName: String
}

// MARK: - Facade

/// The engine facade all UI code depends on — never TidesCore directly
/// (implementation plan §1 "parallelism seam", design doc §12).
///
/// Backed by `SyntheticEngine` until the TidesCore port lands; the swap point
/// is `EngineProvider.engine`.
protocol TideEngine: Sendable {
    /// Station display name ("St Helier").
    var stationName: String { get }
    /// Engine/version line for the About footer.
    var engineVersion: String { get }

    /// Sea level in metres above chart datum.
    func levelAt(_ instant: Date) -> Double
    /// d(level)/dt in metres per hour; `> 0` means rising.
    func slopeAt(_ instant: Date) -> Double
    /// All extremes in `from..<to`, time-ascending, alternating high/low.
    func extremes(from: Date, to: Date) -> [TideExtreme]
    /// Extremes within the local day's bounds (3–5 at St Helier).
    func dayExtremes(_ day: CalendarDay) -> [TideExtreme]
    /// Evenly spaced samples across the local day, endpoints inclusive
    /// (`samplesPerHour: 6` → ~145 points; 139/151 on DST days).
    func timeline(_ day: CalendarDay, samplesPerHour: Int) -> [TimelinePoint]
    /// Sun events for the local day, or nil when unavailable.
    func sunTimes(_ day: CalendarDay) -> SunTimes?
    /// Moon phase at an instant.
    func moonPhase(at instant: Date) -> MoonPhase
    /// Quarter-phase events within roughly ±1 lunation of `instant`, sorted.
    func moonEvents(around instant: Date) -> [MoonEvent]
}
