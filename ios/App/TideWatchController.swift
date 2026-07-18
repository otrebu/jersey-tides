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

    func toggle(engine: any TideEngine, now: Date) {
        if isWatching { stop() } else { start(engine: engine, now: now) }
    }

    func start(engine: any TideEngine, now: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled,
              let state = Self.runState(engine: engine, now: now) else { return }
        activity = try? Activity.request(
            attributes: TideWatchAttributes(stationName: "St Helier · Jersey"),
            content: .init(state: state, staleDate: state.nextTime.addingTimeInterval(15 * 60))
        )
        isWatching = activity != nil
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

    /// On foreground: if the watched extreme has passed, move the activity to
    /// the next run (the new prev is the extreme just passed).
    func rollForwardIfNeeded(engine: any TideEngine, now: Date) {
        guard let activity, activity.content.state.nextTime <= now,
              let state = Self.runState(engine: engine, now: now) else { return }
        let id = activity.id
        Task {
            for live in Activity<TideWatchAttributes>.activities where live.id == id {
                await live.update(
                    .init(state: state, staleDate: state.nextTime.addingTimeInterval(15 * 60))
                )
            }
        }
    }

    /// The current flood/ebb run: previous extreme → next extreme around `now`.
    private static func runState(
        engine: any TideEngine, now: Date
    ) -> TideWatchAttributes.ContentState? {
        let window = engine.extremes(
            from: now.addingTimeInterval(-15 * 3600),
            to: now.addingTimeInterval(30 * 3600)
        )
        guard let next = window.first(where: { $0.time > now }),
              let prev = window.last(where: { $0.time <= now }) else { return nil }
        return TideWatchAttributes.ContentState(
            nextTime: next.time,
            nextHeight: next.height,
            nextIsHigh: next.isHigh,
            prevTime: prev.time,
            prevHeight: prev.height
        )
    }
}
