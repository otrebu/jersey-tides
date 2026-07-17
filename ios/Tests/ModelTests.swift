import Foundation
import Testing

@testable import JerseyTides

/// // CHUNK C FILLS THIS — swing column values, springs/neaps rule, threshold
/// crossing, formatter output incl. feet conversion.
struct ModelTests {
    @Test func scaffoldStubCompiles() {
        let day = CalendarDay(year: 2026, month: 7, day: 17)
        let now = TideTime.date(day, hour: 12, minute: 0)
        let model = TideDayModel.make(day: day, engine: SyntheticEngine(), now: now)
        #expect(!model.extremes.isEmpty)
        #expect(model.samples.count == 145)
    }
}
