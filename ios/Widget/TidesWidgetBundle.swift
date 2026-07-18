import SwiftUI
import WidgetKit

/// The four widgets (design doc §6). Kind strings are stable identifiers —
/// never rename them once shipped. Each family view applies
/// `containerBackground(Color.sky)` (accessories: `AccessoryWidgetBackground`)
/// and `.widgetURL(jerseytides://day/…)` itself.
@main
struct TidesWidgetBundle: WidgetBundle {
    var body: some Widget {
        DialWidget()
        ChartWidget()
        RectWidget()
        GlanceWidget()
        TideWatchActivityWidget()
    }
}

/// systemSmall — "the dial" (typography only, no curve).
struct DialWidget: Widget {
    static let kind = "TidesDial"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: Self.kind, intent: DialConfigIntent.self, provider: DialTimelineProvider()
        ) { entry in
            DialSmallView(entry: entry)
        }
        .configurationDisplayName("Dial")
        .description("Next tide — or the level right now — at St Helier.")
        .supportedFamilies([.systemSmall])
    }
}

/// systemMedium + systemLarge — "the chart room" / "the full instrument".
struct ChartWidget: Widget {
    static let kind = "TidesChart"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: Self.kind, intent: ChartConfigIntent.self, provider: ChartTimelineProvider()
        ) { entry in
            ChartWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Chart")
        .description("The day's tide curve and extremes at St Helier.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

/// Dispatches the Chart widget to the right family view.
struct ChartWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TideEntry

    var body: some View {
        switch family {
        case .systemLarge:
            ChartLargeView(entry: entry)
        default:
            ChartMediumView(entry: entry)
        }
    }
}

/// accessoryRectangular — Text / Curve styles.
struct RectWidget: Widget {
    static let kind = "TidesRect"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: Self.kind, intent: RectConfigIntent.self, provider: RectTimelineProvider()
        ) { entry in
            RectAccessoryView(entry: entry)
        }
        .configurationDisplayName("Rectangular")
        .description("Tide level and next extremes on the Lock Screen.")
        .supportedFamilies([.accessoryRectangular])
    }
}

/// accessoryCircular + accessoryInline — static configuration.
struct GlanceWidget: Widget {
    static let kind = "TidesGlance"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: GlanceTimelineProvider()) { entry in
            GlanceView(entry: entry)
        }
        .configurationDisplayName("Glance")
        .description("Current tide level at St Helier.")
        .supportedFamilies([.accessoryCircular, .accessoryInline])
    }
}
