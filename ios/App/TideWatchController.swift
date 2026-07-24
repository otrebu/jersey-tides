import ActivityKit
import Foundation

/// App-side lifecycle for the "Tide Watch" Live Activity. One activity at a
/// time, tracking the run from the previous extreme to the next. The activity
/// needs no updates while it runs (system timers carry it); the app rolls it
/// forward to the next run on foreground once the extreme has passed.
@MainActor
final class TideWatchController: ObservableObject {
    @Published private(set) var isWatching = false

    private var activity: Activity<TideWatchAttributes>?

    /// Adopt any activity that survived an app relaunch.
    func adoptExisting() {
        activity = Activity<TideWatchAttributes>.activities.first
        isWatching = activity != nil
    }

    func toggle(engine: any TideEngine, now: Date, units: HeightUnit) {
        if isWatching { stop() } else { start(engine: engine, now: now, units: units) }
    }

    func start(engine: any TideEngine, now: Date, units: HeightUnit) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled,
              let state = Self.runState(engine: engine, now: now, units: units) else { return }
        activity = try? Activity.request(
            attributes: Self.attributes(engine: engine, now: now),
            content: .init(state: state, staleDate: state.nextTime.addingTimeInterval(15 * 60))
        )
        isWatching = activity != nil
    }

    /// Attributes carry the day-curve snapshot for the expanded island:
    /// normalized 30-min heights + extreme marks across the local day.
    private static func attributes(
        engine: any TideEngine, now: Date
    ) -> TideWatchAttributes {
        let day = TideTime.calendarDay(of: now)
        let bounds = TideTime.dayBounds(day)
        let samples = engine.timeline(day, samplesPerHour: 2)
        let extremes = engine.dayExtremes(day)
        let heights = samples.map(\.height) + extremes.map(\.height)
        let lo = heights.min() ?? 0
        let hi = heights.max() ?? 1
        let span = max(hi - lo, 0.1)
        return TideWatchAttributes(
            stationName: "St Helier · Jersey",
            curveHeights: samples.map { ($0.height - lo) / span },
            curveMarks: extremes.map {
                TideWatchAttributes.CurveMark(
                    fraction: $0.time.timeIntervalSince(bounds.start) / bounds.duration,
                    level: ($0.height - lo) / span,
                    isHigh: $0.isHigh
                )
            }
        )
    }

    func stop() {
        // Capture only the Sendable id; re-fetch inside the task (Activity
        // itself is non-Sendable and cannot cross the await).
        let id = activity?.id
        activity = nil
        isWatching = false
        Task {
            guard let id else { return }
            for live in Activity<TideWatchAttributes>.activities where live.id == id {
                await live.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    /// On foreground: if the watched extreme has passed, restart the activity
    /// on the current run. Restart (not update) so the attributes' day-curve
    /// snapshot is rebuilt — it can never go stale across a midnight rollover.
    func rollForwardIfNeeded(engine: any TideEngine, now: Date, units: HeightUnit) {
        guard let activity, activity.content.state.nextTime <= now else { return }
        stop()
        start(engine: engine, now: now, units: units)
    }

    /// The current flood/ebb run: previous extreme → next extreme around `now`,
    /// plus the next high water at or beyond the next extreme (the lock card's
    /// hero even when a low comes first). The 30 h forward window always
    /// contains it — St Helier extremes sit ~6.2 h apart. `units` is baked
    /// into the state: the extension can't read the app's defaults (no App
    /// Group), and the setting can't change without the app foregrounding —
    /// the same moment every other absolute here gets rebuilt.
    private static func runState(
        engine: any TideEngine, now: Date, units: HeightUnit
    ) -> TideWatchAttributes.ContentState? {
        let window = engine.extremes(
            from: now.addingTimeInterval(-15 * 3600),
            to: now.addingTimeInterval(30 * 3600)
        )
        guard let nextIndex = window.firstIndex(where: { $0.time > now }),
              nextIndex > 0 else { return nil }
        let next = window[nextIndex]
        let prev = window[nextIndex - 1]
        guard let nextHigh = window[nextIndex...].first(where: { $0.isHigh })
        else { return nil }
        return TideWatchAttributes.ContentState(
            nextTime: next.time,
            nextHeight: next.height,
            nextIsHigh: next.isHigh,
            prevTime: prev.time,
            prevHeight: prev.height,
            nextHighTime: nextHigh.time,
            nextHighHeight: nextHigh.height,
            unit: units
        )
    }
}
