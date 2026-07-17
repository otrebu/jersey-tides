import Foundation
import Testing

@testable import JerseyTides

/// Chunk C model + formatter gates: swing column from the padded window,
/// springs/neaps ±7 d 85 %/115 % rule, threshold-crossing bisection ≤ 1 min,
/// formatter output (metres + feet, U+2009 thin space, 12/24 h), deep-link
/// parse + clamp.
struct ModelTests {
    private let engine = SyntheticEngine()
    /// The synthetic springs day: HW ≈ 14:32 local, range ≈ 10.6 m.
    private let springsDay = CalendarDay(year: 2026, month: 7, day: 17)

    // MARK: Swing column (design doc §5.1 graft #3, §8)

    @Test func swingValuesComeFromPaddedWindow() throws {
        let model = TideDayModel.make(day: springsDay, engine: engine)
        let bounds = TideTime.dayBounds(springsDay)
        let padded = engine.extremes(
            from: bounds.start.addingTimeInterval(-15 * 3600), to: bounds.end
        )
        #expect(!model.rows.isEmpty)
        for row in model.rows {
            let previous = try #require(padded.last(where: { $0.time < row.extreme.time }))
            let swing = try #require(row.swing)
            #expect(abs(swing - (row.extreme.height - previous.height)) < 1e-9)
        }
    }

    @Test func firstRowOfDayHasRealPredecessor() {
        // The padded 15 h window exists exactly so this row's swing is non-nil.
        let model = TideDayModel.make(day: springsDay, engine: engine)
        #expect(model.rows.first?.swing != nil)
    }

    @Test func swingSignMatchesKind() throws {
        let model = TideDayModel.make(day: springsDay, engine: engine)
        for row in model.rows {
            let swing = try #require(row.swing)
            #expect(row.extreme.isHigh ? swing > 0 : swing < 0)
        }
    }

    // MARK: Springs/neaps rule (design doc §5.1)

    @Test func springsDayClassifiesAsSprings() {
        // 2026-07-17 is the synthetic engine's constituent-aligned crest: its
        // range is the ±7-day window max, so ≥ 85 % of max ⇒ SPRINGS.
        let model = TideDayModel.make(day: springsDay, engine: engine)
        #expect(model.springs == .springs)
    }

    @Test func minimumRangeDayClassifiesAsNeaps() {
        // The neaps trough sits ~7 d after the springs crest (M2/S2 beat).
        // Find the minimum-range day nearby; it is its own window minimum,
        // so ≤ 115 % of min ⇒ NEAPS.
        func range(_ day: CalendarDay) -> Double {
            let heights = engine.dayExtremes(day).map(\.height)
            return (heights.max() ?? 0) - (heights.min() ?? 0)
        }
        let candidates = (3...11).map { TideTime.addDays(springsDay, $0) }
        let neapsDay = candidates.min { range($0) < range($1) }!
        let model = TideDayModel.make(day: neapsDay, engine: engine)
        #expect(model.springs == .neaps)
    }

    // MARK: Threshold crossing (design doc §8 — bisection ≤ 1 min)

    @Test func thresholdCrossingRefinedToWithinOneMinute() throws {
        // 12:00 UTC on the springs day: level ≈ 9.9 m, above a 9.5 m mark and
        // still rising toward the 14:32 crest.
        let now = TideTime.date(springsDay, hour: 13, minute: 0) // 12:00 UTC (BST)
        let model = TideDayModel.make(
            day: springsDay, engine: engine, now: now, markedHeight: 9.5
        )
        let threshold = try #require(model.threshold)
        #expect(threshold.height == 9.5)
        #expect(threshold.isOverNow)
        let until = try #require(threshold.overUntil)
        #expect(until > now)
        // ≤ 1 min accuracy: one minute either side must straddle the mark.
        #expect(engine.levelAt(until.addingTimeInterval(-60)) >= 9.5)
        #expect(engine.levelAt(until.addingTimeInterval(60)) < 9.5)
    }

    @Test func thresholdBelowNowHasNoOverState() throws {
        let now = TideTime.date(springsDay, hour: 13, minute: 0)
        let model = TideDayModel.make(
            day: springsDay, engine: engine, now: now, markedHeight: 11.9
        )
        let threshold = try #require(model.threshold)
        #expect(!threshold.isOverNow)
        #expect(threshold.overUntil == nil)
    }

    // MARK: Formatters (design doc §3)

    @Test func heightUsesThinSpaceAndOneDecimal() {
        #expect(TideFormatters.height(11.2, unit: .metres) == "11.2\u{2009}m")
        #expect(TideFormatters.height(2.0, unit: .metres) == "2.0\u{2009}m")
    }

    @Test func feetConversionIsDisplaySide() {
        // 11.2 m × 3.28084 = 36.745… → "36.7 ft"
        #expect(TideFormatters.height(11.2, unit: .feet) == "36.7\u{2009}ft")
        #expect(TideFormatters.heightValue(1.0, unit: .feet) == "3.3")
    }

    @Test func swingFormatUsesTextArrows() {
        #expect(TideFormatters.swing(9.16) == "↑ 9.2")
        #expect(TideFormatters.swing(-8.54) == "↓ 8.5")
    }

    @Test func twentyFourHourTimeFormat() {
        let instant = TideTime.date(springsDay, hour: 14, minute: 32)
        #expect(TideFormatters.time(instant, format: .twentyFourHour) == "14:32")
    }

    @Test func twelveHourTimeFormat() {
        let instant = TideTime.date(springsDay, hour: 14, minute: 32)
        let formatted = TideFormatters.time(instant, format: .twelveHour)
        #expect(formatted.contains("2:32"))
        #expect(!formatted.contains("14:32"))
    }

    @Test func countdownFormat() {
        let target = TideTime.date(springsDay, hour: 14, minute: 32)
        #expect(
            TideFormatters.countdown(to: target, from: target.addingTimeInterval(-7680)) == "in 2 h 08 m"
        )
        #expect(
            TideFormatters.countdown(to: target, from: target.addingTimeInterval(-42 * 60)) == "in 42 m"
        )
        #expect(TideFormatters.countdown(to: target, from: target) == "now")
    }

    @Test func dayLengthFormat() {
        #expect(TideFormatters.dayLength(15 * 3600 + 8 * 60) == "15 h 08")
    }

    // MARK: Deep link (design doc §5.4)

    @Test func deepLinkParsesWidgetURL() {
        let day = CalendarDay(year: 2026, month: 7, day: 17)
        #expect(DeepLink.parse(day.deepLinkURL) == day)
        #expect(DeepLink.parse(URL(string: "jerseytides://day/2026-07-17")!) == day)
    }

    @Test func deepLinkRejectsInvalidURLs() {
        #expect(DeepLink.parse(URL(string: "jerseytides://day/2026-02-30")!) == nil)
        #expect(DeepLink.parse(URL(string: "jerseytides://day/not-a-date")!) == nil)
        #expect(DeepLink.parse(URL(string: "jerseytides://fortnight/2026-07-17")!) == nil)
        #expect(DeepLink.parse(URL(string: "https://day/2026-07-17")!) == nil)
        #expect(DeepLink.parse(URL(string: "jerseytides://day")!) == nil)
    }

    @Test func deepLinkOffsetClampsToFourteenDays() {
        let today = CalendarDay(year: 2026, month: 7, day: 17)
        #expect(DeepLink.pageOffset(for: TideTime.addDays(today, 3), today: today) == 3)
        #expect(DeepLink.pageOffset(for: TideTime.addDays(today, -5), today: today) == -5)
        #expect(DeepLink.pageOffset(for: TideTime.addDays(today, 30), today: today) == 14)
        #expect(DeepLink.pageOffset(for: TideTime.addDays(today, -30), today: today) == -14)
    }
}
