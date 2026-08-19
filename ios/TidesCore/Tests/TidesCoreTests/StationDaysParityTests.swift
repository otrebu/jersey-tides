import Foundation
import Testing
@testable import TidesCore

/// Golden replay of station-days.json: 25 Europe/Jersey civil days (including
/// all six DST-transition days and the year boundaries) of datum-inclusive
/// St Helier day extremes — exact counts, per-index time within 1 s, height
/// within 1 mm, exact type.
struct StationDaysParityTests {
    struct DayFixture: Decodable {
        struct DayRef: Decodable {
            let year: Int
            let month: Int
            let day: Int
        }

        struct DayExtreme: Decodable {
            let utc: String
            let height: Double
            let type: String
        }

        let day: DayRef
        let tz: String
        let extremes: [DayExtreme]
    }

    @Test func reproducesEveryStationDayExtreme() throws {
        let days: [DayFixture] = try Fixtures.load("station-days.json")
        #expect(days.count == 25)
        for fixture in days {
            #expect(fixture.tz == "Europe/Jersey")
            let day = CalendarDay(year: fixture.day.year, month: fixture.day.month, day: fixture.day.day)
            let got = StHelier.station.dayExtremes(day)
            #expect(got.count == fixture.extremes.count, "day \(day)")
            guard got.count == fixture.extremes.count else { continue }
            for (index, want) in fixture.extremes.enumerated() {
                let g = got[index]
                #expect(
                    abs(g.time.msSinceEpoch - Fixtures.ms(want.utc)) <= Fixtures.timeEpsMs,
                    "day \(day) extreme \(index): got \(g.time), want \(want.utc)"
                )
                #expect(
                    abs(g.height - want.height) <= Fixtures.heightEpsMetres,
                    "day \(day) extreme \(index): got \(g.height), want \(want.height)"
                )
                #expect(g.type.rawValue == want.type, "day \(day) extreme \(index)")
            }
        }
    }

    /// DST-transition civil days are 23 h / 25 h long; ordinary days exactly 24 h.
    @Test func dayBoundsSpanDstTransitions() {
        func hoursIn(_ year: Int, _ month: Int, _ day: Int) -> Double {
            let bounds = dayBoundsUtc(CalendarDay(year: year, month: month, day: day), timeZone: StHelier.timeZone)
            return (bounds.end.msSinceEpoch - bounds.start.msSinceEpoch) / 3_600_000
        }
        // Spring forward (clocks +1h) → 23 h civil day; fall back → 25 h.
        #expect(hoursIn(2025, 3, 30) == 23)
        #expect(hoursIn(2025, 10, 26) == 25)
        #expect(hoursIn(2026, 3, 29) == 23)
        #expect(hoursIn(2026, 10, 25) == 25)
        #expect(hoursIn(2025, 7, 4) == 24)
    }
}
