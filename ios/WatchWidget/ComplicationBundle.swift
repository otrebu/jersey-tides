import SwiftUI
import WidgetKit

/// Watch complications. Kinds are distinct from the iPhone widgets — different
/// extension, but don't reuse a shipped kind string. Views and the timeline
/// planner are the iPhone accessory ones: the engine still runs in-process.
@main
struct JerseyTidesWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        WatchGlanceWidget()
        WatchRectWidget()
    }
}

/// Corner, circular, and inline — static config, metres, curve-less glance.
struct WatchGlanceWidget: Widget {
    static let kind = "TidesWatchGlance"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: GlanceTimelineProvider()) { entry in
            GlanceView(entry: entry)
        }
        .configurationDisplayName("Tide")
        .description("Current tide level at St Helier.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline])
    }
}

/// Rectangular slot — text or curve, same intent as the Lock Screen widget.
struct WatchRectWidget: Widget {
    static let kind = "TidesWatchRect"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: Self.kind, intent: RectConfigIntent.self, provider: RectTimelineProvider()
        ) { entry in
            RectAccessoryView(entry: entry)
        }
        .configurationDisplayName("Tide chart")
        .description("Tide level and next extremes at St Helier.")
        .supportedFamilies([.accessoryRectangular])
    }
}
