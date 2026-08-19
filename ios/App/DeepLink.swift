import Foundation

/// `jerseytides://day/<ISO-date>` → pager target; the consumer clamps to
/// ±`pageRadius` days.
enum DeepLink {
    static let scheme = "jerseytides"

    /// The pager's hard bound: ±10 years around today. The harmonic engine
    /// evaluates at any instant, so the pager scrolls as far as anyone would
    /// ever want; the bound only keeps the `ForEach` range finite (predictions
    /// this far out are unverifiable against official tables, not invalid).
    static let pageRadius = 3650

    /// Parses `jerseytides://day/2026-07-17`; nil for anything else.
    static func parse(_ url: URL) -> CalendarDay? {
        guard url.scheme?.lowercased() == scheme,
              url.host?.lowercased() == "day" else { return nil }
        let components = url.pathComponents.filter { $0 != "/" }
        guard components.count == 1 else { return nil }
        return calendarDay(fromISO: components[0])
    }

    /// Signed pager offset from today for a deep-linked day, clamped to the
    /// ±`pageRadius` bound.
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
