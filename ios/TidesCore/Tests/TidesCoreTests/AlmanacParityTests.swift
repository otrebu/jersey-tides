import Foundation
import Testing
@testable import TidesCore

/// Golden replay of almanac.json: 16 sun days (2026 equinoxes/solstices plus
/// month firsts, default St Helier coordinates) within 1 s with exactly-equal
/// day lengths, and the 50 moon phase events of 2026 within 1 s.
struct AlmanacParityTests {
    struct AlmanacFixture: Decodable {
        struct SunEntry: Decodable {
            struct DayRef: Decodable {
                let year: Int
                let month: Int
                let day: Int
            }

            struct Length: Decodable {
                let hours: Int
                let minutes: Int
            }

            let day: DayRef
            let tz: String
            let sunrise: String?
            let sunset: String?
            let dayLength: Length?
        }

        struct MoonEvent: Decodable {
            let type: String
            let utc: String
        }

        let sun: [SunEntry]
        let moonEvents: [MoonEvent]
    }

    @Test func reproducesEverySunTime() throws {
        let fixture: AlmanacFixture = try Fixtures.load("almanac.json")
        #expect(fixture.sun.count == 16)
        for entry in fixture.sun {
            #expect(entry.tz == "Europe/Jersey")
            let day = CalendarDay(year: entry.day.year, month: entry.day.month, day: entry.day.day)
            let got = getSunTimes(day)
            expectNullableInstant(got.sunrise, entry.sunrise, "sunrise \(day)")
            expectNullableInstant(got.sunset, entry.sunset, "sunset \(day)")
            #expect(got.dayLength?.hours == entry.dayLength?.hours, "day length hours \(day)")
            #expect(got.dayLength?.minutes == entry.dayLength?.minutes, "day length minutes \(day)")
            #expect((got.dayLength == nil) == (entry.dayLength == nil), "day length nil \(day)")
        }
    }

    @Test func reproducesEvery2026MoonPhaseEvent() throws {
        let fixture: AlmanacFixture = try Fixtures.load("almanac.json")
        #expect(fixture.moonEvents.count == 50)
        let got = getMoonPhaseEvents(
            from: Fixtures.date("2026-01-01T00:00:00.000Z"),
            to: Fixtures.date("2026-12-31T23:59:59.999Z")
        )
        #expect(got.count == fixture.moonEvents.count)
        guard got.count == fixture.moonEvents.count else { return }
        for (index, want) in fixture.moonEvents.enumerated() {
            let g = got[index]
            #expect(g.type.rawValue == want.type, "moon event \(index)")
            #expect(
                abs(g.time.msSinceEpoch - Fixtures.ms(want.utc)) <= Fixtures.timeEpsMs,
                "moon event \(index): got \(g.time), want \(want.utc)"
            )
        }
    }

    /// `getMoonPhase` at each golden quadrature instant reads the matching
    /// principal phase: full ≈ fully lit, new ≈ dark, quarters ≈ half lit.
    /// Guards the `illumination`/`name` fields the redesign's moon row surfaces.
    @Test func moonPhaseIlluminationMatchesEvents() throws {
        let fixture: AlmanacFixture = try Fixtures.load("almanac.json")
        for event in fixture.moonEvents {
            let phase = getMoonPhase(Fixtures.date(event.utc))
            switch event.type {
            case "full":
                #expect(phase.name == "Full Moon", "at \(event.utc)")
                #expect(phase.illumination >= 99, "full illumination at \(event.utc)")
            case "new":
                #expect(phase.name == "New Moon", "at \(event.utc)")
                #expect(phase.illumination <= 1, "new illumination at \(event.utc)")
            case "first_quarter", "last_quarter":
                #expect(abs(phase.illumination - 50) <= 2, "quarter illumination at \(event.utc)")
            default:
                Issue.record("unexpected moon event type \(event.type)")
            }
        }
    }

    private func expectNullableInstant(_ got: Date?, _ want: String?, _ label: String) {
        guard let want else {
            #expect(got == nil, "\(label): expected nil")
            return
        }
        guard let got else {
            Issue.record("\(label): got nil, want \(want)")
            return
        }
        #expect(
            abs(got.msSinceEpoch - Fixtures.ms(want)) <= Fixtures.timeEpsMs,
            "\(label): got \(got), want \(want)"
        )
    }
}
