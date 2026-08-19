import SwiftUI
import WidgetKit

/// systemMedium "the week" — seven days of shrinking/growing cycles plus each
/// morning's HW (widget canvas concept #4). Shows the springs-to-neaps drift
/// and how HW walks ~50 minutes later every day; today's column carries the
/// full `sea` voice, the rest recede.
///
/// Rendering-mode contract §2.1: today's column (strip + time) is the accent
/// group; no `dawn` element at this size.
struct WeekMediumView: View {
    let entry: TideEntry

    private var units: HeightUnit { entry.config.units }

    var body: some View {
        Group {
            if entry.dayModel != nil {
                week
            } else {
                ErrorTileView(family: .systemMedium)
            }
        }
        .containerBackground(Color.sky, for: .widget)
        .widgetURL(entry.dayModel?.day.deepLinkURL)
    }

    // MARK: Data

    private struct DayColumn: Identifiable {
        let id: Int
        let dow: String
        let isToday: Bool
        let samples: [TimelinePoint]
        let bounds: DayBounds
        /// First HW of the day — the "morning" high water.
        let morningHigh: TideExtreme?
    }

    /// Today + six days out, straight from the engine facade (pure, offline).
    private var columns: [DayColumn] {
        let engine = EngineProvider.engine
        let today = TideTime.calendarDay(of: entry.displayInstant)
        return (0..<7).map { offset in
            let day = TideTime.addDays(today, offset)
            return DayColumn(
                id: offset,
                dow: TideFormatters.weekday(day).prefix(3).uppercased(),
                isToday: offset == 0,
                samples: engine.timeline(day, samplesPerHour: 4),
                bounds: TideTime.dayBounds(day),
                morningHigh: engine.dayExtremes(day).first(where: \.isHigh)
            )
        }
    }

    // MARK: Layout

    private var week: some View {
        let columns = self.columns
        // One shared Y domain across the whole week so the springs→neaps
        // amplitude change is visible (per-day normalization would draw
        // every day at full height).
        let heights = columns.flatMap { $0.samples.map(\.height) }
        let domain = (heights.min() ?? 0)...(heights.max() ?? 1)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("St Helier · Jersey").engravingStyle()
                Spacer()
                Text("morning HW").metaStyle()
            }
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(columns) { column in
                    dayColumn(column, domain: domain)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary(columns))
    }

    private func dayColumn(_ column: DayColumn, domain: ClosedRange<Double>) -> some View {
        VStack(spacing: 3) {
            Text(column.dow)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(column.isToday ? Color.sea : .seaTertiary)
            SparkStrip(
                samples: column.samples,
                bounds: column.bounds,
                domain: domain,
                color: column.isToday ? .sea : .seaTertiary,
                lineWidth: column.isToday ? 1.8 : 1.2
            )
            .frame(height: 22)
            .widgetAccentable(column.isToday)
            if let high = column.morningHigh {
                Text(TideFormatters.time(high.time))
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(column.isToday ? Color.sea : .seaSecondary)
                    .widgetAccentable(column.isToday)
                Text(TideFormatters.heightValue(high.height, unit: units))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.seaTertiary)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }

    private func accessibilitySummary(_ columns: [DayColumn]) -> String {
        let parts = columns.compactMap { column -> String? in
            guard let high = column.morningHigh else { return nil }
            return "\(column.dow) high water \(TideFormatters.time(high.time)), "
                + WidgetVoice.spokenHeight(high.height, unit: units)
        }
        return parts.isEmpty
            ? "Tide data unavailable" : "Week of morning high waters. " + parts.joined(separator: ". ")
    }
}

/// Minimal day-curve polyline — the Week strip's own voice (the shared
/// `Sparkline` variants carry ghost/rolling semantics this view doesn't want).
private struct SparkStrip: View {
    let samples: [TimelinePoint]
    let bounds: DayBounds
    /// Shared week-wide height domain — NOT this day's own range.
    let domain: ClosedRange<Double>
    let color: Color
    let lineWidth: CGFloat

    var body: some View {
        Canvas { context, size in
            let inset: CGFloat = 2
            let plotHeight = size.height - inset * 2
            let span = domain.upperBound - domain.lowerBound
            var path = Path()
            for (index, sample) in samples.enumerated() {
                let xFraction = sample.time.timeIntervalSince(bounds.start) / bounds.duration
                let yFraction = span > 0 ? (sample.height - domain.lowerBound) / span : 0.5
                let point = CGPoint(
                    x: size.width * xFraction,
                    y: inset + plotHeight * (1 - yFraction)
                )
                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            context.stroke(
                path, with: .color(color),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )
        }
        .accessibilityHidden(true)
    }
}
