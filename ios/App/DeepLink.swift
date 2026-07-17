import Foundation

/// `jerseytides://day/<ISO-date>` → pager target; the consumer clamps to
/// ±14 days (design doc §5.4).
enum DeepLink {
    static let scheme = "jerseytides"

    /// The pager's hard bound: ±14 days around today (design doc §5.1).
    static let pageRadius = 14

    /// Parses `jerseytides://day/2026-07-17`; nil for anything else.
    static func parse(_ url: URL) -> CalendarDay? {
        guard url.scheme?.lowercased() == scheme,
              url.host?.lowercased() == "day" else { return nil }
        let components = url.pathComponents.filter { $0 != "/" }
        guard components.count == 1 else { return nil }
        return calendarDay(fromISO: components[0])
    }

    /// Signed pager offset from today for a deep-linked day, clamped to the
    /// ±14-day bound (design doc §5.4 "clamped to ±14").
    static func pageOffset(for day: CalendarDay, today: CalendarDay) -> Int {
        min(max(TideTime.daysBetween(today, day), -pageRadius), pageRadius)
    }

    /// Strict `yyyy-MM-dd` → CalendarDay; rejects impossible dates
    /// (Foundation would roll `2026-02-30` over — the round-trip catches it).
    private static func calendarDay(fromISO iso: String) -> CalendarDay? {
        let parts = iso.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else { return nil }
        let candidate = CalendarDay(year: year, month: month, day: day)
        guard (1...12).contains(month), (1...31).contains(day) else { return nil }
        let roundTrip = TideTime.calendarDay(of: TideTime.date(candidate, hour: 12, minute: 0))
        guard roundTrip == candidate else { return nil }
        return candidate
    }
}
