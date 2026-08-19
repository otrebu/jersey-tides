import SwiftUI
import WidgetKit

/// systemLarge "the fortnight" — 14 daily max-HW bars: the springs–neaps
/// breathing cycle, quarter/new moon marks in `dawn`, next springs called out
/// (widget canvas concept #5). Unique to a computed-offline app — no API
/// horizon to run into.
///
/// Rendering-mode contract §2.1: today's bar is the accent group; `dawn`
/// elements (moon glyphs, header caption glyph) fall back to `seaSecondary`
/// in accented mode, same rule as ChartLargeView.
struct FortnightLargeView: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    let entry: TideEntry

    private var units: HeightUnit { entry.config.units }
    private var dawnOrDropped: Color {
        renderingMode == .accented ? .seaSecondary : .dawn
    }

    var body: some View {
        Group {
            if let model = entry.dayModel {
                fortnight(model)
            } else {
                ErrorTileView(family: .systemLarge)
            }
        }
        .containerBackground(Color.sky, for: .widget)
        .widgetURL(entry.dayModel?.day.deepLinkURL)
    }

    // MARK: Data

    private struct DayBar: Identifiable {
        let id: Int
        let day: CalendarDay
        let letter: String
        let maxHigh: Double
        let isToday: Bool
        let moonEvent: MoonEventKind?
    }

    /// Today + 13 days: each day's highest HW, plus any quarter-phase event
    /// falling on it. Engine facade only — pure, offline, milliseconds.
    private func bars(_ model: TideDayModel) -> [DayBar] {
        let engine = EngineProvider.engine
        let today = model.day
        let events = engine.moonEvents(around: entry.displayInstant)
        return (0..<14).map { offset in
            let day = TideTime.addDays(today, offset)
            let highs = engine.dayExtremes(day).filter(\.isHigh).map(\.height)
            let event = events.first { TideTime.calendarDay(of: $0.date) == day }
            return DayBar(
                id: offset,
                day: day,
                letter: String(TideFormatters.weekday(day).prefix(1)).uppercased(),
                maxHigh: highs.max() ?? 0,
                isToday: offset == 0,
                moonEvent: event?.kind
            )
        }
    }

    // MARK: Layout

    private func fortnight(_ model: TideDayModel) -> some View {
        let bars = self.bars(model)
        let peakIndex = bars.indices.max { bars[$0].maxHigh < bars[$1].maxHigh }
        let top = max(12.0, (bars.map(\.maxHigh).max() ?? 12).rounded(.up))
        return VStack(alignment: .leading, spacing: 0) {
            header(model)
            chart(bars: bars, peakIndex: peakIndex, top: top)
                .frame(maxHeight: .infinity)
                .padding(.top, 12)
            Rectangle().fill(Color.hairline).frame(height: 0.5)
                .padding(.trailing, Self.axisGutter)
            letterRow(bars)
                .padding(.top, 5)
                .padding(.trailing, Self.axisGutter)
            footer(bars: bars, peakIndex: peakIndex)
                .padding(.top, 8)
                .padding(.trailing, Self.axisGutter)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary(bars: bars, peakIndex: peakIndex))
    }

    /// Right-hand metre-scale gutter width.
    private static let axisGutter: CGFloat = 22
    /// Chart floor, metres above datum — bars grow from here so the
    /// springs–neaps swing fills the plot instead of hiding atop a tall base.
    private static let floorHeight: Double = 6

    @ViewBuilder
    private func header(_ model: TideDayModel) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("St Helier · Jersey").engravingStyle()
            Spacer()
            Text(TideFormatters.mediumDate(model.day)).metaStyle()
        }
        HStack(spacing: 5) {
            Spacer()
            if let springs = model.springs {
                Text(springs == .springs ? "SPRINGS" : "NEAPS").metaStyle()
                Text(verbatim: "·").metaStyle()
            }
            Image(systemName: model.moonPhase.systemImageName)
                .font(.caption2)
                .foregroundStyle(dawnOrDropped)
            Text(model.moonPhase.name).metaStyle()
        }
        .padding(.top, 2)
    }

    private func chart(bars: [DayBar], peakIndex: Int?, top: Double) -> some View {
        GeometryReader { proxy in
            let plotHeight = proxy.size.height
            ZStack(alignment: .bottomLeading) {
                gridlines(top: top, plotHeight: plotHeight, width: proxy.size.width)
                HStack(alignment: .bottom, spacing: 7) {
                    ForEach(bars) { bar in
                        barColumn(
                            bar,
                            isPeak: bar.id == peakIndex,
                            top: top,
                            plotHeight: plotHeight
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.trailing, Self.axisGutter)
            }
        }
    }

    /// Hairlines + right labels every 2 m from 8 up to the scale top.
    private func gridlines(top: Double, plotHeight: CGFloat, width: CGFloat) -> some View {
        let marks = stride(from: 8.0, through: top, by: 2.0)
        return ForEach(Array(marks), id: \.self) { metres in
            let y = plotHeight * (1 - fraction(of: metres, top: top))
            Rectangle()
                .fill(Color.hairline)
                .frame(width: max(0, width - Self.axisGutter), height: 0.5)
                .position(x: (width - Self.axisGutter) / 2, y: y)
            Text(TideFormatters.heightValue(metres, unit: units))
                .font(.system(size: 10))
                .monospacedDigit()
                .foregroundStyle(.seaTertiary)
                .position(x: width - Self.axisGutter / 2 + 3, y: y)
        }
    }

    private func barColumn(
        _ bar: DayBar, isPeak: Bool, top: Double, plotHeight: CGFloat
    ) -> some View {
        VStack(spacing: 2) {
            if isPeak {
                Text(TideFormatters.heightValue(bar.maxHigh, unit: units))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.seaSecondary)
                    .fixedSize()
            }
            UnevenRoundedRectangle(topLeadingRadius: 2, topTrailingRadius: 2)
                .fill(bar.isToday ? Color.sea : (isPeak ? .seaSecondary : .seaTertiary))
                .frame(height: max(2, plotHeight * fraction(of: bar.maxHigh, top: top)))
                .widgetAccentable(bar.isToday)
        }
    }

    private func letterRow(_ bars: [DayBar]) -> some View {
        HStack(spacing: 7) {
            ForEach(bars) { bar in
                VStack(spacing: 3) {
                    Text(bar.letter)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(bar.isToday ? Color.sea : .seaTertiary)
                    Group {
                        if let event = bar.moonEvent {
                            Image(systemName: event.systemImageName)
                                .font(.system(size: 8))
                                .foregroundStyle(dawnOrDropped)
                        } else {
                            Color.clear
                        }
                    }
                    .frame(height: 9)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func footer(bars: [DayBar], peakIndex: Int?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("daily max high water").metaStyle()
            Spacer()
            if let peakIndex, bars.indices.contains(peakIndex), peakIndex != 0 {
                let peak = bars[peakIndex]
                Text(
                    "springs \(TideFormatters.weekday(peak.day).prefix(3)) \(peak.day.day)"
                        + " · \(TideFormatters.height(peak.maxHigh, unit: units))"
                )
                .metaStyle()
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.85)
    }

    private func fraction(of metres: Double, top: Double) -> Double {
        let span = top - Self.floorHeight
        guard span > 0 else { return 0 }
        return min(max((metres - Self.floorHeight) / span, 0), 1)
    }

    private func accessibilitySummary(bars: [DayBar], peakIndex: Int?) -> String {
        var parts: [String] = ["Fourteen days of maximum high water."]
        if let first = bars.first {
            parts.append(
                "Today \(WidgetVoice.spokenHeight(first.maxHigh, unit: units))."
            )
        }
        if let peakIndex, bars.indices.contains(peakIndex), peakIndex != 0 {
            let peak = bars[peakIndex]
            parts.append(
                "Springs \(TideFormatters.weekday(peak.day)) the \(peak.day.day), "
                    + "\(WidgetVoice.spokenHeight(peak.maxHigh, unit: units))."
            )
        }
        return parts.joined(separator: " ")
    }
}
