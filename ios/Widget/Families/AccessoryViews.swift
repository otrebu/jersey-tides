import SwiftUI
import WidgetKit

/// Accessory family views (design doc §6): rectangular Text/Curve, circular
/// Gauge (+ fallback band), inline. Vibrant hierarchy is pure opacity tiers.
///
/// // CHUNK F FILLS THIS — placeholder layouts.

/// accessoryRectangular — honors `config.rectStyle` (Text default / Curve).
struct RectAccessoryView: View {
    let entry: TideEntry

    var body: some View {
        Group {
            if let model = entry.dayModel,
               let height = model.currentHeight,
               let rising = model.isRising {
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(TideFormatters.height(height, unit: entry.config.units)) \(rising ? "▲" : "▼")")
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                    if let next = model.nextExtreme {
                        Text("\(next.isHigh ? "HW" : "LW") \(TideFormatters.time(next.time)) · \(TideFormatters.height(next.height, unit: entry.config.units))")
                            .font(.caption2)
                    }
                    if let following = model.followingExtreme {
                        Text("\(following.isHigh ? "HW" : "LW") \(TideFormatters.time(following.time)) · \(TideFormatters.height(following.height, unit: entry.config.units))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ErrorTileView(family: .accessoryRectangular)
            }
        }
        .containerBackground(for: .widget) { AccessoryWidgetBackground() }
        .widgetURL(entry.dayModel?.day.deepLinkURL)
    }
}

/// accessoryCircular — real Gauge over the day's LW…HW band; ±1 m fallback.
struct CircularAccessoryView: View {
    let entry: TideEntry

    var body: some View {
        Group {
            if let model = entry.dayModel, let height = model.currentHeight {
                let heights = model.extremes.map(\.height)
                let lower = min(heights.min() ?? (height - 1), height)
                let upper = max(heights.max() ?? (height + 1), lower + 0.1)
                Gauge(value: height, in: lower...upper) {
                    Image(systemName: (model.isRising ?? true) ? "arrow.up" : "arrow.down")
                } currentValueLabel: {
                    Text(TideFormatters.heightValue(height, unit: entry.config.units))
                        .fontWeight(.medium)
                        .monospacedDigit()
                }
                .gaugeStyle(.accessoryCircular)
            } else {
                ErrorTileView(family: .accessoryCircular)
            }
        }
        .containerBackground(for: .widget) { AccessoryWidgetBackground() }
        .widgetURL(entry.dayModel?.day.deepLinkURL)
    }
}

/// accessoryInline — arrow symbol + `HW 14:32 · 11.2 m`; bare level fallback.
struct InlineAccessoryView: View {
    let entry: TideEntry

    var body: some View {
        Group {
            if let model = entry.dayModel {
                let arrow = (model.isRising ?? true) ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill"
                if let next = model.nextExtreme {
                    Label(
                        "\(next.isHigh ? "HW" : "LW") \(TideFormatters.time(next.time)) · \(TideFormatters.height(next.height, unit: entry.config.units))",
                        systemImage: arrow
                    )
                    .monospacedDigit()
                } else if let height = model.currentHeight {
                    Label(TideFormatters.height(height, unit: entry.config.units), systemImage: arrow)
                        .monospacedDigit()
                }
            } else {
                ErrorTileView(family: .accessoryInline)
            }
        }
        .widgetURL(entry.dayModel?.day.deepLinkURL)
    }
}

/// Dispatcher for the Glance widget (circular + inline share one static config).
struct GlanceView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TideEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            InlineAccessoryView(entry: entry)
        default:
            CircularAccessoryView(entry: entry)
        }
    }
}
