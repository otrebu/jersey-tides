import Foundation
import Testing
import WidgetKit

@testable import JerseyTides

/// Design doc §9 gates: entry budget (40–70) with exact counts on normal +
/// both 2026 DST days, ascending order, every extreme instant present, 90-s
/// dedupe, slack tail across midnight, window-midpoint display instants, and
/// the single-entry error path.
struct EntryPlannerTests {
    private let engine = SyntheticEngine()

    private func plan(_ year: Int, _ month: Int, _ dayOfMonth: Int) -> (day: CalendarDay, entries: [Date]) {
        let day = CalendarDay(year: year, month: month, day: dayOfMonth)
        let now = TideTime.date(day, hour: 12, minute: 0)
        return (day, EntryPlanner.planEntries(day: day, engine: engine, now: now))
    }

    // MARK: Entry counts (§9 budget)

    @Test func normalDayEntryCount() {
        let (_, entries) = plan(2026, 7, 17) // 24 h day
        // 48 grid + 4 extremes + 2 sun − 0 dedupes + 6 slack.
        #expect(entries.count == 60)
        #expect((40...70).contains(entries.count))
    }

    @Test func springForwardDayEntryCount() {
        let (day, entries) = plan(2026, 3, 29) // EU spring-forward, 23 h day
        #expect(TideTime.dayBounds(day).duration == 23 * 3600)
        // 46 grid + 4 extremes + 2 sun − 0 dedupes + 6 slack.
        #expect(entries.count == 58)
        #expect((40...70).contains(entries.count))
    }

    @Test func fallBackDayEntryCount() {
        let (day, entries) = plan(2026, 10, 25) // EU fall-back, 25 h day
        #expect(TideTime.dayBounds(day).duration == 25 * 3600)
        // 50 grid + 4 extremes + 2 sun − 0 dedupes + 6 slack.
        #expect(entries.count == 62)
        #expect((40...70).contains(entries.count))
    }

    // MARK: Ordering

    @Test func entriesSortedAscendingAndUnique() {
        for (year, month, dayOfMonth) in [(2026, 7, 17), (2026, 3, 29), (2026, 10, 25)] {
            let (_, entries) = plan(year, month, dayOfMonth)
            #expect(zip(entries, entries.dropFirst()).allSatisfy { $0 < $1 })
        }
    }

    // MARK: Exact instants

    @Test func everyExtremeInstantPresent() {
        for (year, month, dayOfMonth) in [(2026, 7, 17), (2026, 3, 29), (2026, 10, 25)] {
            let (day, entries) = plan(year, month, dayOfMonth)
            let extremes = engine.dayExtremes(day)
            #expect(!extremes.isEmpty)
            for extreme in extremes {
                #expect(entries.contains(extreme.time))
            }
        }
    }

    @Test func sunInstantsPresent() {
        let (day, entries) = plan(2026, 7, 17)
        let sun = engine.sunTimes(day)
        #expect(entries.contains(sun!.sunrise!))
        #expect(entries.contains(sun!.sunset!))
    }

    // MARK: Dedupe (§9: exact within 90 s drops the GRID entry)

    @Test func noPairCloserThanDedupeTolerance() {
        for (year, month, dayOfMonth) in [(2026, 7, 17), (2026, 3, 29), (2026, 10, 25)] {
            let (_, entries) = plan(year, month, dayOfMonth)
            for (a, b) in zip(entries, entries.dropFirst()) {
                #expect(b.timeIntervalSince(a) > EntryPlanner.dedupeTolerance)
            }
        }
    }

    @Test func exactInstantNearGridDropsGridEntry() {
        // Engine with a HW 30 s after a :30 grid instant → that grid entry
        // must vanish while the exact instant stays.
        let day = CalendarDay(year: 2026, month: 7, day: 17)
        let gridInstant = TideTime.date(day, hour: 14, minute: 30)
        let extremeInstant = gridInstant.addingTimeInterval(30)
        let stub = FixedExtremesEngine(
            base: engine,
            dayExtremes: [TideExtreme(time: extremeInstant, height: 11.0, kind: .high)]
        )
        let entries = EntryPlanner.planEntries(
            day: day, engine: stub, now: TideTime.date(day, hour: 12, minute: 0)
        )
        #expect(entries.contains(extremeInstant))
        #expect(!entries.contains(gridInstant))
        // The neighboring grid instants survive.
        #expect(entries.contains(TideTime.date(day, hour: 14, minute: 0)))
        #expect(entries.contains(TideTime.date(day, hour: 15, minute: 0)))
    }

    // MARK: Slack tail (§9: 6 hourly entries past next midnight)

    @Test func slackTailCrossesMidnight() {
        let (day, entries) = plan(2026, 7, 17)
        let midnight = TideTime.dayBounds(day).end
        let tail = entries.filter { $0 >= midnight }
        #expect(tail.count == 6)
        #expect(tail == (0..<6).map { midnight.addingTimeInterval(Double($0) * 3600) })
        // Slack entries land in the NEW local day.
        #expect(TideTime.calendarDay(of: tail[0]) == TideTime.addDays(day, 1))
    }

    // MARK: Display instant (§9 staleness: window midpoint, clamped)

    @Test func displayInstantIsMidpointClampedToFifteenMinutes() {
        let base = Date(timeIntervalSince1970: 1_784_000_000)
        // Standard 30-min grid window → +15 min.
        #expect(
            EntryPlanner.displayInstant(entryDate: base, nextEntryDate: base.addingTimeInterval(1800))
                == base.addingTimeInterval(900)
        )
        // Short post-dedupe window (90 s) → true midpoint (+45 s).
        #expect(
            EntryPlanner.displayInstant(entryDate: base, nextEntryDate: base.addingTimeInterval(90))
                == base.addingTimeInterval(45)
        )
        // Long slack window (1 h) → still +15 min, never beyond.
        #expect(
            EntryPlanner.displayInstant(entryDate: base, nextEntryDate: base.addingTimeInterval(3600))
                == base.addingTimeInterval(900)
        )
        // Last entry (no successor) → +15 min.
        #expect(
            EntryPlanner.displayInstant(entryDate: base, nextEntryDate: nil)
                == base.addingTimeInterval(900)
        )
    }

    // MARK: Full timeline assembly

    @Test func timelineEntriesCarryOwnDayModels() {
        let day = CalendarDay(year: 2026, month: 7, day: 17)
        let now = TideTime.date(day, hour: 12, minute: 0)
        let timeline = EntryPlanner.makeTimeline(engine: engine, now: now)
        #expect(timeline.entries.count == 60)
        #expect(timeline.policy == .after(TideTime.dayBounds(day).end.addingTimeInterval(60)))
        // Every entry has a model for the day of its display instant.
        for entry in timeline.entries {
            #expect(entry.dayModel != nil)
            #expect(entry.dayModel?.day == TideTime.calendarDay(of: entry.displayInstant))
        }
        // Entries past midnight build the NEW day's model.
        let midnight = TideTime.dayBounds(day).end
        let tomorrow = TideTime.addDays(day, 1)
        let crossed = timeline.entries.filter { $0.date >= midnight }
        #expect(crossed.count == 6)
        #expect(crossed.allSatisfy { $0.dayModel?.day == tomorrow })
    }

    // MARK: Error path (§9/§10: exactly one entry, retry +15 min)

    @Test func errorPathEmitsExactlyOneEntry() {
        let now = TideTime.date(CalendarDay(year: 2026, month: 7, day: 17), hour: 12, minute: 0)
        let timeline = EntryPlanner.makeTimeline(engine: BrokenEngine(), now: now)
        #expect(timeline.entries.count == 1)
        #expect(timeline.entries.first?.dayModel == nil)
        #expect(timeline.policy == .after(now.addingTimeInterval(15 * 60)))
    }
}

// MARK: - Test engines

/// Wraps a real engine but pins the day's extremes (dedupe scenarios).
private struct FixedExtremesEngine: TideEngine {
    let base: SyntheticEngine
    let dayExtremes: [TideExtreme]

    var stationName: String { base.stationName }
    var engineVersion: String { base.engineVersion }
    func levelAt(_ instant: Date) -> Double { base.levelAt(instant) }
    func slopeAt(_ instant: Date) -> Double { base.slopeAt(instant) }
    func extremes(from: Date, to: Date) -> [TideExtreme] {
        dayExtremes.filter { $0.time >= from && $0.time < to }
    }
    func dayExtremes(_ day: CalendarDay) -> [TideExtreme] { dayExtremes }
    func timeline(_ day: CalendarDay, samplesPerHour: Int) -> [TimelinePoint] {
        base.timeline(day, samplesPerHour: samplesPerHour)
    }
    func sunTimes(_ day: CalendarDay) -> SunTimes? { nil }
    func moonPhase(at instant: Date) -> MoonPhase { base.moonPhase(at: instant) }
    func moonEvents(around instant: Date) -> [MoonEvent] { [] }
}

/// Produces no tide data at all — forces the §10 error path.
private struct BrokenEngine: TideEngine {
    let stationName = "St Helier"
    let engineVersion = "broken 0.0"
    func levelAt(_ instant: Date) -> Double { .nan }
    func slopeAt(_ instant: Date) -> Double { .nan }
    func extremes(from: Date, to: Date) -> [TideExtreme] { [] }
    func dayExtremes(_ day: CalendarDay) -> [TideExtreme] { [] }
    func timeline(_ day: CalendarDay, samplesPerHour: Int) -> [TimelinePoint] { [] }
    func sunTimes(_ day: CalendarDay) -> SunTimes? { nil }
    func moonPhase(at instant: Date) -> MoonPhase {
        MoonPhase(ageDays: 0, name: "new moon", systemImageName: "moonphase.new.moon")
    }
    func moonEvents(around instant: Date) -> [MoonEvent] { [] }
}
