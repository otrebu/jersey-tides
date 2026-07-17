import Foundation

/// Timezone-correct calendar-day handling.
///
/// Port of `packages/core/src/time.ts`. All UTC↔local conversion flows
/// through `tzOffsetMinutes` — in Swift that is `TimeZone.secondsFromGMT(for:)`
/// over the same IANA tzdb the TS Intl implementation reads. Day arithmetic
/// and the two-pass DST fixup are ported as-is; `Calendar` day logic is
/// deliberately NOT used, so behaviour matches the TS contract bit-for-bit at
/// DST transitions.

/// A civil calendar date (proleptic Gregorian), independent of timezone.
public struct CalendarDay: Hashable, Sendable, Codable {
    public let year: Int
    /// 1–12.
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }
}

extension Date {
    /// Unix epoch milliseconds, rounded onto the integer grid JS `Date`s live
    /// on (sub-ms noise from `TimeInterval` seconds is irrelevant at the 1 s
    /// parity tolerance).
    var msSinceEpoch: Double {
        (timeIntervalSince1970 * 1000).rounded()
    }

    init(msSinceEpoch ms: Double) {
        self.init(timeIntervalSince1970: ms / 1000)
    }
}

/// Civil date from days since 1970-01-01 (Howard Hinnant's algorithm,
/// proleptic Gregorian — same arithmetic as JS `Date.UTC` field rollover).
func civilFromDays(_ daysSinceEpoch: Int) -> (year: Int, month: Int, day: Int) {
    let z = daysSinceEpoch + 719468
    let era = (z >= 0 ? z : z - 146096) / 146097
    let doe = z - era * 146097
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
    let mp = (5 * doy + 2) / 153
    let day = doy - (153 * mp + 2) / 5 + 1
    let month = mp < 10 ? mp + 3 : mp - 9
    let year = yoe + era * 400 + (month <= 2 ? 1 : 0)
    return (year, month, day)
}

/// Days since 1970-01-01 for a civil date (inverse of `civilFromDays`).
/// `day` may fall outside the month; it rolls over like JS `Date.UTC`.
func daysFromCivil(year: Int, month: Int, day: Int) -> Int {
    let y = month <= 2 ? year - 1 : year
    let era = (y >= 0 ? y : y - 399) / 400
    let yoe = y - era * 400
    let mp = (month + 9) % 12
    let doy = (153 * mp + 2) / 5 + day - 1
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
    return era * 146097 + doe - 719468
}

/// UTC calendar day of an epoch-ms instant.
private func civilDay(fromMs ms: Double) -> CalendarDay {
    let days = Int((ms / 86_400_000).rounded(.down))
    let civil = civilFromDays(days)
    return CalendarDay(year: civil.year, month: civil.month, day: civil.day)
}

/// Offset of `timeZone` from UTC at the instant `utc`, in whole minutes
/// (positive east of Greenwich). The single timezone primitive everything
/// else builds on.
public func tzOffsetMinutes(utc: Date, timeZone: TimeZone) -> Int {
    timeZone.secondsFromGMT(for: utc) / 60
}

/// Calendar day that the instant `date` falls on in `timeZone`.
public func calendarDayOf(_ date: Date, timeZone: TimeZone) -> CalendarDay {
    let shiftedMs = date.msSinceEpoch + Double(tzOffsetMinutes(utc: date, timeZone: timeZone)) * 60_000
    return civilDay(fromMs: shiftedMs)
}

/// Local midnight as a UTC epoch-ms instant, with the two-pass offset fixup:
/// guess with the offset at the naive instant, recompute at the guess, adjust
/// if a DST transition moved the offset between the two.
private func localMidnightUtcMs(_ day: CalendarDay, timeZone: TimeZone) -> Double {
    let naive = Double(daysFromCivil(year: day.year, month: day.month, day: day.day)) * 86_400_000
    let offsetAtGuess = tzOffsetMinutes(utc: Date(msSinceEpoch: naive), timeZone: timeZone)
    var ts = naive - Double(offsetAtGuess) * 60_000
    let offsetAtResult = tzOffsetMinutes(utc: Date(msSinceEpoch: ts), timeZone: timeZone)
    if offsetAtResult != offsetAtGuess {
        ts = naive - Double(offsetAtResult) * 60_000
    }
    return ts
}

/// UTC instants of local midnight and the next local midnight in `timeZone`.
/// DST-transition days span 23 h or 25 h.
public func dayBoundsUtc(_ day: CalendarDay, timeZone: TimeZone) -> (start: Date, end: Date) {
    (
        start: Date(msSinceEpoch: localMidnightUtcMs(day, timeZone: timeZone)),
        end: Date(msSinceEpoch: localMidnightUtcMs(addDays(day, 1), timeZone: timeZone))
    )
}

/// True when both instants fall on the same calendar day in `timeZone`.
public func sameCalendarDay(_ a: Date, _ b: Date, timeZone: TimeZone) -> Bool {
    calendarDayOf(a, timeZone: timeZone) == calendarDayOf(b, timeZone: timeZone)
}

/// Shift a calendar day by whole days (pure calendar arithmetic, no timezone).
public func addDays(_ day: CalendarDay, _ delta: Int) -> CalendarDay {
    let civil = civilFromDays(daysFromCivil(year: day.year, month: day.month, day: day.day) + delta)
    return CalendarDay(year: civil.year, month: civil.month, day: civil.day)
}
