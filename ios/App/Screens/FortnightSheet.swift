import SwiftUI

/// Screen 2 — the Fortnight sheet (design doc §5.2): 14 rows (today + 13),
/// date + compact extremes, a 3 pt range bar on a fixed 12.5 m scale so bars
/// are comparable across days, moon-event glyphs in dawn (Almanac graft #5c),
/// tap-to-page. Presented with medium/large detents over `.thinMaterial`.
struct FortnightSheet: View {
    let startDay: CalendarDay
    /// Dismiss + page Today to the tapped day.
    let onSelect: (CalendarDay) -> Void

    @EnvironmentObject private var settings: SettingsStore

    /// Fixed range-bar scale (§5.2): `width = dayRange / 12.5 m × maxBarWidth`.
    private static let barScaleMetres = 12.5

    private let rows: [FortnightRow]

    init(startDay: CalendarDay, onSelect: @escaping (CalendarDay) -> Void) {
        self.startDay = startDay
        self.onSelect = onSelect
        self.rows = Self.buildRows(startDay: startDay, engine: EngineProvider.engine)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(rows, id: \.day) { row in
                    if row.day != rows.first?.day {
                        Rectangle()
                            .fill(Color.hairline)
                            .frame(height: 0.5)
                    }
                    rowView(row)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .scrollContentBackground(.hidden)
    }

    private func rowView(_ row: FortnightRow) -> some View {
        Button {
            onSelect(row.day)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(TideFormatters.shortDate(row.day))
                        .metaStyle(row.isToday ? .sea : .seaSecondary)
                    if let event = row.moonEvent {
                        Image(systemName: event.systemImageName)
                            .font(.caption2)
                            .foregroundStyle(.dawn)
                    }
                    Spacer(minLength: 0)
                }
                // Table voice, one size down so 4-extreme days fit one line
                // without per-row scale jumps.
                Text(compactExtremes(row))
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.sea)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                rangeBar(range: row.range)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText(row))
    }

    /// `HW 02:11 10.8 · LW 08:24 2.3 · …` — Table voice.
    private func compactExtremes(_ row: FortnightRow) -> String {
        row.extremes.map { extreme in
            let tag = extreme.isHigh ? "HW" : "LW"
            let time = TideFormatters.time(extreme.time, format: settings.timeFormat)
            let height = TideFormatters.heightValue(extreme.height, unit: settings.units)
            return "\(tag) \(time) \(height)"
        }
        .joined(separator: " · ")
    }

    /// 3 pt bar, `sea @ 25%`, width on the fixed 12.5 m scale.
    private func rangeBar(range: Double) -> some View {
        GeometryReader { geo in
            Rectangle()
                .fill(Color.sea.opacity(0.25))
                .frame(
                    width: geo.size.width * min(max(range, 0) / Self.barScaleMetres, 1),
                    height: 3
                )
        }
        .frame(height: 3)
    }

    private func accessibilityText(_ row: FortnightRow) -> String {
        var parts = [TideFormatters.shortDate(row.day)]
        if let event = row.moonEvent {
            parts.append(event.captionName)
        }
        parts.append(compactExtremes(row))
        parts.append("range \(TideFormatters.height(row.range, unit: settings.units))")
        return parts.joined(separator: ", ")
    }

    // MARK: Row assembly

    private struct FortnightRow {
        let day: CalendarDay
        let isToday: Bool
        let extremes: [TideExtreme]
        let range: Double
        let moonEvent: MoonEventKind?
    }

    private static func buildRows(
        startDay: CalendarDay, engine: any TideEngine
    ) -> [FortnightRow] {
        // Quarter-phase events across the sheet's span, keyed by local day.
        let midSpan = TideTime.date(TideTime.addDays(startDay, 7), hour: 12, minute: 0)
        var eventsByDay: [CalendarDay: MoonEventKind] = [:]
        for event in engine.moonEvents(around: midSpan) {
            eventsByDay[TideTime.calendarDay(of: event.date)] = event.kind
        }
        return (0..<14).map { offset in
            let day = TideTime.addDays(startDay, offset)
            let extremes = engine.dayExtremes(day)
            let heights = extremes.map(\.height)
            let range = (heights.max() ?? 0) - (heights.min() ?? 0)
            return FortnightRow(
                day: day,
                isToday: offset == 0,
                extremes: extremes,
                range: range,
                moonEvent: eventsByDay[day]
            )
        }
    }
}
