import Foundation
import Testing

@testable import JerseyTides

/// // CHUNK D FILLS THIS — entry count 40–70 on normal AND DST days, sorted,
/// extreme instants present, dedupe within 90 s, error path emits exactly one
/// entry.
struct EntryPlannerTests {
    @Test func scaffoldStubCompiles() {
        let day = CalendarDay(year: 2026, month: 7, day: 17)
        let now = TideTime.date(day, hour: 12, minute: 0)
        let entries = EntryPlanner.planEntries(day: day, engine: SyntheticEngine(), now: now)
        #expect(!entries.isEmpty)
    }
}
