import WidgetKit

/// Timeline providers (design doc §9). One reload per day: the full entry plan
/// comes from `EntryPlanner.makeTimeline` — :00/:30 local grid + exact extreme
/// and sun instants + 6-entry hourly slack tail past next midnight, deduped
/// within 90 s, window-midpoint display instants, `.after(next local midnight
/// + 60 s)`; error path → single §10 tile entry, `.after(now + 15 min)`.
///
/// Placeholder/snapshot contexts return a single sane entry fast (no full-day
/// plan) — the widget gallery must never wait on ~60 model assemblies.

struct DialTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TideEntry {
        .make(at: EngineProvider.clock.now)
    }

    func snapshot(for configuration: DialConfigIntent, in context: Context) async -> TideEntry {
        .make(at: EngineProvider.clock.now, config: configuration.widgetConfig)
    }

    func timeline(for configuration: DialConfigIntent, in context: Context) async -> Timeline<TideEntry> {
        EntryPlanner.makeTimeline(now: EngineProvider.clock.now, config: configuration.widgetConfig)
    }
}

struct ChartTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TideEntry {
        .make(at: EngineProvider.clock.now)
    }

    func snapshot(for configuration: ChartConfigIntent, in context: Context) async -> TideEntry {
        .make(at: EngineProvider.clock.now, config: configuration.widgetConfig)
    }

    func timeline(for configuration: ChartConfigIntent, in context: Context) async -> Timeline<TideEntry> {
        EntryPlanner.makeTimeline(now: EngineProvider.clock.now, config: configuration.widgetConfig)
    }
}

struct RectTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TideEntry {
        .make(at: EngineProvider.clock.now)
    }

    func snapshot(for configuration: RectConfigIntent, in context: Context) async -> TideEntry {
        .make(at: EngineProvider.clock.now, config: configuration.widgetConfig)
    }

    func timeline(for configuration: RectConfigIntent, in context: Context) async -> Timeline<TideEntry> {
        EntryPlanner.makeTimeline(now: EngineProvider.clock.now, config: configuration.widgetConfig)
    }
}

/// Static provider for the Glance widget (circular + inline; no options).
struct GlanceTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> TideEntry {
        .make(at: EngineProvider.clock.now)
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (TideEntry) -> Void) {
        completion(.make(at: EngineProvider.clock.now))
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<TideEntry>) -> Void) {
        completion(EntryPlanner.makeTimeline(now: EngineProvider.clock.now, config: .default))
    }
}
