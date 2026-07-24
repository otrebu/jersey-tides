import SwiftUI
import WidgetKit

/// Accessory family views (design doc §6): rectangular Text/Curve, circular
/// Gauge (+ fallback band), inline. `AccessoryWidgetBackground()` on; vibrant
/// hierarchy is pure opacity tiers via `.primary`/`.secondary` — no custom
/// colors pushed against the material (§2.1).

// MARK: - accessoryRectangular

/// accessoryRectangular — honors `config.rectStyle` (Text default / Curve).
struct RectAccessoryView: View {
    let entry: TideEntry

    var body: some View {
        Group {
            if let model = entry.dayModel {
                switch entry.config.rectStyle {
                case .text:
                    RectTextContent(model: model, units: entry.config.units)
                case .curve:
                    RectCurveContent(
                        model: model, now: entry.displayInstant, units: entry.config.units
                    )
                }
            } else {
                ErrorTileView(family: .accessoryRectangular)
            }
        }
        .containerBackground(for: .widget) { AccessoryWidgetBackground() }
        .widgetURL(entry.dayModel?.day.deepLinkURL)
    }
}

/// Text style (§6): `8.4 m ▲` title3 semibold · next extreme caption2 primary ·
/// following extreme caption2 secondary (true material dimming).
private struct RectTextContent: View {
    let model: TideDayModel
    let units: HeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            heroLine
            if let next = model.nextExtreme {
                Text(Self.extremeText(next, units: units))
                    .font(.caption2)
                    .monospacedDigit()
            }
            if let following = model.followingExtreme {
                Text(Self.extremeText(following, units: units))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WidgetVoice.summary(model, units: units))
    }

    @ViewBuilder
    private var heroLine: some View {
        if let height = model.currentHeight {
            heroText(height: height)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
        }
    }

    /// `8.4 m ▲` — arrow is an SF symbol, never a text glyph (§3).
    private func heroText(height: Double) -> Text {
        var text = Text(TideFormatters.height(height, unit: units))
        if let rising = model.isRising {
            text = text + Text(verbatim: " ")
                + Text(Image(systemName: WidgetVoice.arrowSymbol(rising: rising)))
                    .font(.system(size: 12, weight: .semibold))
        }
        return text
    }

    static func extremeText(_ extreme: TideExtreme, units: HeightUnit) -> String {
        "\(extreme.isHigh ? "HW" : "LW") \(TideFormatters.time(extreme.time))"
            + " · \(TideFormatters.height(extreme.height, unit: units))"
    }
}

/// Curve style: the full DAY curve — the Scriptable widget's familiar sinus —
/// with HW/LW legend markers and the now dot, behind a single
/// `HW 14:32 · 11.2 m` next-extreme caption line.
private struct RectCurveContent: View {
    let model: TideDayModel
    let now: Date
    let units: HeightUnit

    var body: some View {
        ZStack(alignment: .topLeading) {
            TideCurveView(model: model, style: .rect)
            if let next = model.nextExtreme {
                Text(RectTextContent.extremeText(next, units: units))
                    .font(.caption2)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WidgetVoice.summary(model, units: units))
    }
}

// MARK: - accessoryCircular

/// accessoryCircular — real `Gauge` over the day's LW…HW band with caption2
/// min/max labels; fallback ±1 m band around the current height, divisor
/// floored at 0.1 (§6).
struct CircularAccessoryView: View {
    let entry: TideEntry

    private var units: HeightUnit { entry.config.units }

    var body: some View {
        Group {
            if let model = entry.dayModel, let height = model.currentHeight {
                gauge(model: model, height: height)
            } else {
                ErrorTileView(family: .accessoryCircular)
            }
        }
        .containerBackground(for: .widget) { AccessoryWidgetBackground() }
        .widgetURL(entry.dayModel?.day.deepLinkURL)
    }

    private func gauge(model: TideDayModel, height: Double) -> some View {
        let band = gaugeBand(height: height, heights: model.extremes.map(\.height))
        let rising = model.isRising ?? true
        return Gauge(value: min(max(height, band.low), band.high), in: band.low...band.high) {
            Image(systemName: rising ? "arrow.up" : "arrow.down")
        } currentValueLabel: {
            Text(TideFormatters.heightValue(height, unit: units))
                .fontWeight(.medium)
                .monospacedDigit()
        } minimumValueLabel: {
            Text(TideFormatters.heightValue(band.low, unit: units))
                .font(.caption2)
                .minimumScaleFactor(0.6)
        } maximumValueLabel: {
            Text(TideFormatters.heightValue(band.high, unit: units))
                .font(.caption2)
                .minimumScaleFactor(0.6)
        }
        .gaugeStyle(.accessoryCircular)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WidgetVoice.spokenTrend(height, rising: rising, unit: units))
    }

    /// Day LW…HW band; when day extremes are unavailable, ±1 m around the
    /// current height. Divisor (band width) floored at 0.1 — same rule as the
    /// Scriptable widget.
    private func gaugeBand(height: Double, heights: [Double]) -> (low: Double, high: Double) {
        let low = heights.min() ?? (height - 1)
        var high = heights.max() ?? (height + 1)
        if high - low < 0.1 { high = low + 0.1 }
        return (low, high)
    }
}

// MARK: - accessoryInline

/// accessoryInline — arrow symbol + `HW 14:32 · 11.2 m`; with no extreme in
/// horizon, arrow + bare level (§6).
struct InlineAccessoryView: View {
    let entry: TideEntry

    private var units: HeightUnit { entry.config.units }

    var body: some View {
        Group {
            if let model = entry.dayModel {
                let arrow = WidgetVoice.arrowSymbol(rising: model.isRising ?? true)
                if let next = model.nextExtreme {
                    Label(RectTextContent.extremeText(next, units: units), systemImage: arrow)
                        .monospacedDigit()
                        .accessibilityLabel(WidgetVoice.summary(model, units: units))
                } else if let height = model.currentHeight {
                    Label(TideFormatters.height(height, unit: units), systemImage: arrow)
                        .monospacedDigit()
                        .accessibilityLabel(
                            WidgetVoice.spokenTrend(
                                height, rising: model.isRising ?? true, unit: units
                            )
                        )
                }
            } else {
                ErrorTileView(family: .accessoryInline)
            }
        }
        .widgetURL(entry.dayModel?.day.deepLinkURL)
    }
}

// MARK: - Glance dispatcher

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
