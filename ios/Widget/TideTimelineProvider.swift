import WidgetKit

/// Timeline providers (design doc §9). Stub behavior: one entry at the current
/// instant, refresh in 30 min.
///
/// // CHUNK D FILLS THIS — EntryPlanner grid (:00/:30) + exact extreme + sun
/// instants + 6-entry slack tail, window-midpoint display instants,
/// `.after(next local midnight + 60 s)`, error path → single entry `+15 min`.
private func stubTimeline(config: TideWidgetConfig) -> Timeline<TideEntry> {
    let now = EngineProvider.clock.now
    let entry = TideEntry.make(at: now, config: config)
    return Timeline(entries: [entry], policy: .after(now.addingTimeInterval(30 * 60)))
}

struct DialTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TideEntry {
        .make(at: EngineProvider.clock.now)
    }

    func snapshot(for configuration: DialConfigIntent, in context: Context) async -> TideEntry {
        .make(at: EngineProvider.clock.now, config: configuration.widgetConfig)
    }

    func timeline(for configuration: DialConfigIntent, in context: Context) async -> Timeline<TideEntry> {
        stubTimeline(config: configuration.widgetConfig) // CHUNK D FILLS THIS
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
        stubTimeline(config: configuration.widgetConfig) // CHUNK D FILLS THIS
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
        stubTimeline(config: configuration.widgetConfig) // CHUNK D FILLS THIS
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
        completion(stubTimeline(config: .default)) // CHUNK D FILLS THIS
    }
}
