import SwiftUI
import WidgetKit

/// systemSmall "the gauge" — the day's range as a filled level column (widget
/// canvas concept #2): where the water sits between today's lowest LW and
/// highest HW right now. The strongest single read of the set.
///
/// Rendering-mode contract §2.1: the hero (level + arrow) is the accent
/// group; the column fill joins it so the tint reads as the water.
struct GaugeSmallView: View {
    let entry: TideEntry

    /// Dial-2 small-adjacent hero: 34 pt thin.
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 34

    private var units: HeightUnit { entry.config.units }

    var body: some View {
        Group {
            if let model = entry.dayModel, let height = model.currentHeight {
                gauge(model: model, height: height)
            } else {
                ErrorTileView(family: .systemSmall)
            }
        }
        .containerBackground(Color.sky, for: .widget)
        .widgetURL(entry.dayModel?.day.deepLinkURL)
    }

    // MARK: Layout

    private func gauge(model: TideDayModel, height: Double) -> some View {
        let range = dayRange(model)
        let fraction = fillFraction(height: height, range: range)
        return VStack(alignment: .leading, spacing: 4) {
            Text("St Helier").engravingStyle()
            HStack(alignment: .top, spacing: 12) {
                column(fraction: fraction, range: range)
                hero(model: model, height: height, fraction: fraction)
            }
            .frame(maxHeight: .infinity)
            Rectangle().fill(Color.hairline).frame(height: 0.5)
            footer(model)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WidgetVoice.summary(model, units: units))
    }

    /// The column: day range as the track, current level as the fill,
    /// HW/LW heights labelled beside the ends.
    private func column(fraction: Double, range: ClosedRange<Double>) -> some View {
        HStack(alignment: .top, spacing: 5) {
            GeometryReader { proxy in
                ZStack(alignment: .bottom) {
                    Capsule().fill(Color.seaFillTop)
                    Capsule()
                        .fill(Color.sea)
                        .frame(height: max(10, proxy.size.height * fraction))
                        .widgetAccentable()
                }
            }
            .frame(width: 10)
            VStack(alignment: .leading) {
                Text(TideFormatters.heightValue(range.upperBound, unit: units))
                Spacer(minLength: 2)
                Text(TideFormatters.heightValue(range.lowerBound, unit: units))
            }
            .font(.system(size: 9))
            .monospacedDigit()
            .foregroundStyle(.seaTertiary)
            .padding(.vertical, 1)
        }
    }

    private func hero(model: TideDayModel, height: Double, fraction: Double) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)
            Text("NOW")
                .font(TideTypography.unit(parentSize: heroSize))
                .foregroundStyle(.seaSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(TideFormatters.heightValue(height, unit: units))
                    .font(TideTypography.dial2(size: heroSize))
                    .foregroundStyle(.sea)
                    .contentTransition(.numericText())
                    .widgetAccentable()
                Text(TideFormatters.unitSymbol(units))
                    .font(TideTypography.unit(parentSize: heroSize))
                    .foregroundStyle(.seaSecondary)
                if let rising = model.isRising {
                    Image(systemName: WidgetVoice.arrowSymbol(rising: rising))
                        .font(.system(size: heroSize * 0.32))
                        .imageScale(.small)
                        .foregroundStyle(.sea)
                        .widgetAccentable()
                }
            }
            Text("\(Int((fraction * 100).rounded()))% of range")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.seaSecondary)
                .padding(.top, 3)
            Spacer(minLength: 0)
        }
    }

    /// `HW 23:24 · 8.7` — the next turning under the quoted horizon.
    @ViewBuilder
    private func footer(_ model: TideDayModel) -> some View {
        if let next = model.nextExtreme {
            Text(
                "\(next.isHigh ? "HW" : "LW") \(TideFormatters.time(next.time))"
                    + " · \(TideFormatters.heightValue(next.height, unit: units))"
            )
            .font(.footnote)
            .monospacedDigit()
            .foregroundStyle(.seaSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
        }
    }

    // MARK: Data

    /// Today's tidal range: lowest LW … highest HW (falls back to samples).
    private func dayRange(_ model: TideDayModel) -> ClosedRange<Double> {
        let heights = model.extremes.map(\.height)
        let sampled = model.samples.map(\.height)
        let low = heights.min() ?? sampled.min() ?? 0
        let high = heights.max() ?? sampled.max() ?? 1
        return high > low ? low...high : low...(low + 1)
    }

    private func fillFraction(height: Double, range: ClosedRange<Double>) -> Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return min(max((height - range.lowerBound) / span, 0), 1)
    }
}
