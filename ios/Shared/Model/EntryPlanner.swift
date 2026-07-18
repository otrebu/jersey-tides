import Foundation
import WidgetKit

/// Pure entry planning for widget timelines (design doc §9): :00/:30 grid
/// across the local day + exact extreme instants + sunrise/sunset + 6-entry
/// hourly slack tail past next midnight, deduped within 90 s of grid entries.
/// Budget: 40–70 entries/day (≈ 58–62 typical).
enum EntryPlanner {
    /// Exact instants within this distance of a grid instant drop the GRID
    /// entry (never the exact one) — design doc §9 dedupe.
    static let dedupeTolerance: TimeInterval = 90

    /// Hourly slack entries at/after next local midnight, covering a delayed
    /// reload (each renders the NEW day correctly — design doc §9).
    static let slackEntryCount = 6

    /// All entry instants for the local day containing `now`, sorted ascending.
    static func planEntries(day: CalendarDay, engine: any TideEngine, now: Date) -> [Date] {
        let bounds = TideTime.dayBounds(day)

        // 1. Grid: :00/:30 each local hour, midnight → next midnight
        //    (48 normal / 46 spring-forward / 50 fall-back). Jersey's DST
        //    offset changes are whole hours, so a 30-min UTC step from local
        //    midnight stays on local :00/:30 across transitions.
        var grid: [Date] = []
        var t = bounds.start
        while t < bounds.end {
            grid.append(t)
            t = t.addingTimeInterval(30 * 60)
        }

        // 2. Exact instants: every extreme (3–5) + sunrise + sunset.
        var exact = engine.dayExtremes(day).map(\.time)
        if let sun = engine.sunTimes(day) {
            if let sunrise = sun.sunrise { exact.append(sunrise) }
            if let sunset = sun.sunset { exact.append(sunset) }
        }
        exact = exact.filter { $0 >= bounds.start && $0 < bounds.end }

        // 3. Dedupe: an exact instant within 90 s of a grid instant drops the
        //    grid entry (exact times always win — they are the truth).
        let kept = grid.filter { gridInstant in
            !exact.contains { abs($0.timeIntervalSince(gridInstant)) <= dedupeTolerance }
        }

        // 4. Slack tail: 6 hourly entries from next local midnight onward, so
        //    a delayed reload still flips the widget to the new day at 00:00.
        let slack = (0..<slackEntryCount).map { bounds.end.addingTimeInterval(Double($0) * 3600) }

        // Sorted ascending, unique.
        var seen = Set<Date>()
        return (kept + exact + slack)
            .sorted()
            .filter { seen.insert($0).inserted }
    }

    /// Display instant for an entry (§9 staleness control): the entry-window
    /// midpoint — `entryDate + 15 min` for the standard 30-min grid window,
    /// clamped to the true midpoint when the window is shorter (post-dedupe
    /// windows can be as short as 90 s). Last entry: `+15 min`.
    static func displayInstant(entryDate: Date, nextEntryDate: Date?) -> Date {
        let standardOffset: TimeInterval = 15 * 60
        guard let nextEntryDate, nextEntryDate > entryDate else {
            return entryDate.addingTimeInterval(standardOffset)
        }
        let window = nextEntryDate.timeIntervalSince(entryDate)
        return entryDate.addingTimeInterval(min(standardOffset, window / 2))
    }

    /// Reload instant for a healthy timeline: next local midnight + 60 s.
    static func reloadDate(day: CalendarDay) -> Date {
        TideTime.dayBounds(day).end.addingTimeInterval(60)
    }

    /// Reload instant for the error path: now + 15 min.
    static func errorReloadDate(now: Date) -> Date {
        now.addingTimeInterval(15 * 60)
    }

    /// Builds the full §9 timeline for the day containing `now`. Every entry
    /// carries its own `TideDayModel` for the day of its display instant, so
    /// slack entries past midnight render the NEW day. On failure emits the
    /// single §10 error entry with `.after(now + 15 min)`.
    static func makeTimeline(
        engine: any TideEngine = EngineProvider.engine,
        now: Date,
        config: TideWidgetConfig = .default
    ) -> Timeline<TideEntry> {
        do {
            let day = TideTime.calendarDay(of: now)
            let instants = try validatedPlan(day: day, engine: engine, now: now)
            // One expensive full assembly per calendar day (today + the slack
            // tail's next day), then a cheap `rebased` per entry — keeps entry
            // building at the <1 ms/entry contract instead of running the
            // ±7-day springs scan ~60 times.
            var baseModels: [CalendarDay: TideDayModel] = [:]
            let entries = instants.indices.map { index -> TideEntry in
                let date = instants[index]
                let next = index + 1 < instants.count ? instants[index + 1] : nil
                let instant = displayInstant(entryDate: date, nextEntryDate: next)
                let entryDay = TideTime.calendarDay(of: instant)
                let base = baseModels[entryDay] ?? {
                    let built = TideDayModel.make(
                        day: entryDay, engine: engine, now: instant,
                        markedHeight: config.markedHeight, markedLabel: config.markedLabel
                    )
                    baseModels[entryDay] = built
                    return built
                }()
                return TideEntry(
                    date: date, displayInstant: instant,
                    dayModel: base.rebased(now: instant, engine: engine),
                    config: config
                )
            }
            return Timeline(entries: entries, policy: .after(reloadDate(day: day)))
        } catch {
            return Timeline(
                entries: [.error(at: now, config: config)],
                policy: .after(errorReloadDate(now: now))
            )
        }
    }

    // MARK: - Private

    private enum PlanningError: Error {
        case noTideData
        case emptyPlan
    }

    /// Plans the day and sanity-checks the engine actually produced tide data
    /// (St Helier always has 3–5 extremes; none at all means a broken engine).
    private static func validatedPlan(
        day: CalendarDay, engine: any TideEngine, now: Date
    ) throws -> [Date] {
        guard !engine.dayExtremes(day).isEmpty,
              engine.timeline(day, samplesPerHour: 6).count > 2 else {
            throw PlanningError.noTideData
        }
        let instants = planEntries(day: day, engine: engine, now: now)
        guard !instants.isEmpty else { throw PlanningError.emptyPlan }
        return instants
    }
}
