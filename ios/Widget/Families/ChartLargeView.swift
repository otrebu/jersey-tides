import SwiftUI
import WidgetKit

/// systemLarge "the full instrument" (design doc §6): header rows, 34 pt thin
/// hero, `TideCurveView(.large)` at 170 pt, the same 4-column extremes table as
/// the app (Almanac graft #3), OVER caption (threshold set AND currently
/// above), SUN row, TOMORROW row + 20 pt ghost sparkline (Glass graft #4).
///
/// Rendering-mode contract §2.1: hero accentable; `dawn` text elements (OVER
/// caption, sun ticks) fall back to `seaSecondary` (primary @ 55 %) in
/// accented mode — the tint never fights a second chroma. The moon glyph stays
/// in the default group and desaturates on its own.
struct ChartLargeView: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    let entry: TideEntry

    /// Dial-2 large hero (§3): 34 pt thin.
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 34

    private var units: HeightUnit { entry.config.units }
    /// §2.1: `dawn` is dropped entirely in accented mode.
    private var dawnOrDropped: Color {
        renderingMode == .accented ? .seaSecondary : .dawn
    }

    var body: some View {
        Group {
            if let model = entry.dayModel {
                instrument(model)
            } else {
                ErrorTileView(family: .systemLarge)
            }
        }
        .containerBackground(Color.sky, for: .widget)
        .widgetURL(entry.dayModel?.day.deepLinkURL)
    }

    // MARK: Layout

    private func instrument(_ model: TideDayModel) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            header(model)
            hero(model)
            TideCurveView(model: model, style: .large)
                .frame(minHeight: 120, idealHeight: 170, maxHeight: 170)
            table(model)
            if let threshold = model.threshold, threshold.isOverNow {
                overCaption(threshold)
            }
            sunRow(model)
            tomorrowRow(model)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary(model))
    }

    /// `ST HELIER · JERSEY … Thu 17 July` + right-aligned
    /// `SPRINGS · ● full moon in 2 d` (moon glyph `dawn`).
    @ViewBuilder
    private func header(_ model: TideDayModel) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("St Helier · Jersey").engravingStyle()
            Spacer()
            Text(TideFormatters.mediumDate(model.day)).metaStyle()
        }
        if model.springs != nil || model.moonCaption != nil {
            HStack(spacing: 4) {
                Spacer()
                if let springs = model.springs {
                    Text(springs == .springs ? "SPRINGS" : "NEAPS").metaStyle()
                    if model.moonCaption != nil {
                        Text(verbatim: "·").metaStyle()
                    }
                }
                if let symbol = model.moonSymbolName {
                    Image(systemName: symbol)
                        .font(.caption2)
                        .foregroundStyle(.dawn)
                }
                if let caption = model.moonCaption {
                    Text(caption).metaStyle()
                }
            }
        }
    }

    /// `8.4 m ▲` — 34 pt thin, accentable.
    @ViewBuilder
    private func hero(_ model: TideDayModel) -> some View {
        if let height = model.currentHeight {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(TideFormatters.heightValue(height, unit: units))
                    .font(TideTypography.dial2(size: heroSize))
                    .contentTransition(.numericText())
                Text(TideFormatters.unitSymbol(units))
                    .font(TideTypography.unit(parentSize: heroSize))
                    .foregroundStyle(.seaSecondary)
                if let rising = model.isRising {
                    Image(systemName: WidgetVoice.arrowSymbol(rising: rising))
                        .font(.system(size: heroSize * 0.45))
                        .imageScale(.small)
                }
            }
            .foregroundStyle(.sea)
            .widgetAccentable()
        }
    }

    // MARK: 4-column table (graft #3)

    private func table(_ model: TideDayModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(model.rows.enumerated()), id: \.offset) { index, row in
                if index > 0 {
                    Rectangle().fill(Color.hairline).frame(height: 0.5)
                }
                tableRow(row, index: index, model: model)
            }
        }
    }

    private enum RowEmphasis {
        case past, next, future
    }

    /// §5.1 row emphasis: past `seaTertiary`, the next extreme full `sea`,
    /// later-future `seaSecondary`. The "next" row is the first not-yet-past
    /// row of THIS table's scan — never compared against `model.nextExtreme`,
    /// which comes from a different engine scan and won't be value-equal.
    private func rowEmphasis(index: Int, model: TideDayModel) -> RowEmphasis {
        guard let now = model.nowInstant else { return .future }
        if model.rows[index].extreme.time < now { return .past }
        return index == model.rows.firstIndex(where: { $0.extreme.time >= now }) ? .next : .future
    }

    private func mainColor(_ emphasis: RowEmphasis) -> Color {
        switch emphasis {
        case .past: .seaTertiary
        case .next: .sea
        case .future: .seaSecondary
        }
    }

    /// `HW  02:11   10.8   ↑ 9.2` — tag · time · height (right-aligned
    /// tabular) · swing (`seaSecondary`, text arrows per §3).
    private func tableRow(_ row: ExtremeRow, index: Int, model: TideDayModel) -> some View {
        let emphasis = rowEmphasis(index: index, model: model)
        let dimColor: Color = emphasis == .past ? .seaTertiary : .seaSecondary
        return HStack(spacing: 0) {
            Text(row.extreme.isHigh ? "HW" : "LW")
                .font(TideTypography.engraving)
                .tracking(1.4)
                .foregroundStyle(dimColor)
                .frame(width: 36, alignment: .leading)
            Text(TideFormatters.time(row.extreme.time))
                .tableStyle()
                .foregroundStyle(mainColor(emphasis))
            Spacer(minLength: 8)
            Text(TideFormatters.heightValue(row.extreme.height, unit: units))
                .tableStyle()
                .foregroundStyle(mainColor(emphasis))
                .frame(width: 56, alignment: .trailing)
            Text(row.swing.map { "\($0 >= 0 ? "↑" : "↓") \(TideFormatters.heightValue(abs($0), unit: units))" } ?? "")
                .tableStyle()
                .foregroundStyle(dimColor)
                .frame(width: 64, alignment: .trailing)
        }
        .padding(.vertical, 2)
    }

    // MARK: Footer rows

    /// `OVER CAUSEWAY 9.5 M UNTIL 16:51` — Meta, `dawn`; only when the
    /// threshold is set AND the level is currently above it (§6, §8).
    private func overCaption(_ threshold: ThresholdInfo) -> some View {
        var caption = "OVER"
        if let label = threshold.label, !label.isEmpty {
            caption += " \(label.uppercased())"
        }
        caption += " \(TideFormatters.heightValue(threshold.height, unit: units))"
            + " \(TideFormatters.unitSymbol(units).uppercased())"
        if let until = threshold.overUntil {
            caption += " UNTIL \(TideFormatters.time(until))"
        }
        return Text(caption)
            .font(TideTypography.meta.monospacedDigit())
            .foregroundStyle(dawnOrDropped)
    }

    /// `SUN 06:04 → 21:12 · 15 h 08` — Meta, with two small `dawn` tick glyphs.
    @ViewBuilder
    private func sunRow(_ model: TideDayModel) -> some View {
        if let sun = model.sun, let sunrise = sun.sunrise, let sunset = sun.sunset {
            HStack(spacing: 5) {
                Text("SUN")
                    .font(TideTypography.engraving)
                    .tracking(1.4)
                    .foregroundStyle(.seaSecondary)
                sunTick
                Text(TideFormatters.time(sunrise)).metaStyle()
                Text(verbatim: "→").metaStyle()
                sunTick
                Text(TideFormatters.time(sunset)).metaStyle()
                if let dayLength = sun.dayLength {
                    Text("· \(TideFormatters.dayLength(dayLength))").metaStyle()
                }
            }
        }
    }

    private var sunTick: some View {
        Rectangle().fill(dawnOrDropped).frame(width: 1, height: 7)
    }

    /// `TOMORROW  HW 03:02 · 10.9 m` + the 20 pt ghost sparkline (graft #4).
    @ViewBuilder
    private func tomorrowRow(_ model: TideDayModel) -> some View {
        if let tomorrow = model.tomorrow {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Tomorrow").engravingStyle()
                if let firstHigh = tomorrow.firstHigh {
                    Text(
                        "HW \(TideFormatters.time(firstHigh.time))"
                            + " · \(TideFormatters.height(firstHigh.height, unit: units))"
                    )
                    .metaStyle()
                }
            }
            Sparkline(samples: tomorrow.samples, bounds: tomorrow.bounds)
                .frame(height: 20)
        }
    }

    // MARK: Accessibility

    private func accessibilitySummary(_ model: TideDayModel) -> String {
        var parts: [String] = []
        if let height = model.currentHeight, let rising = model.isRising {
            parts.append(WidgetVoice.spokenTrend(height, rising: rising, unit: units))
        }
        parts.append(
            contentsOf: model.rows.map { WidgetVoice.spokenExtreme($0.extreme, unit: units) }
        )
        if let threshold = model.threshold, threshold.isOverNow {
            var over = "Over \(threshold.label ?? "marked height")"
            if let until = threshold.overUntil {
                over += " until \(TideFormatters.time(until))"
            }
            parts.append(over + ".")
        }
        if let sun = model.sun, let sunrise = sun.sunrise, let sunset = sun.sunset {
            parts.append(
                "Sun \(TideFormatters.time(sunrise)) to \(TideFormatters.time(sunset))."
            )
        }
        return parts.joined(separator: " ")
    }
}
