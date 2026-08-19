import SwiftUI
import WidgetKit

/// systemMedium "the chart room" (design doc §6): fixed 116 pt left column
/// (Engraving station · Meta date · current level 28 pt thin with numeric-text
/// transition · next two extremes in Table voice with emphasis) · a 0.5 pt
/// hairline divider — the only divider — · `TideCurveView(.medium)` filling
/// the remainder.
struct ChartMediumView: View {
    let entry: TideEntry

    /// Dial-2 medium hero (§3): 28 pt thin.
    @ScaledMetric(relativeTo: .title) private var heroSize: CGFloat = 28

    private var units: HeightUnit { entry.config.units }

    var body: some View {
        Group {
            if let model = entry.dayModel {
                chartRoom(model)
            } else {
                ErrorTileView(family: .systemMedium)
            }
        }
        .containerBackground(Color.sky, for: .widget)
        .widgetURL(entry.dayModel?.day.deepLinkURL)
    }

    // MARK: Layout

    private func chartRoom(_ model: TideDayModel) -> some View {
        HStack(spacing: 12) {
            leftColumn(model)
                .frame(width: 116, alignment: .leading)
            // The only divider (§6).
            Rectangle().fill(Color.hairline).frame(width: 0.5)
            TideCurveView(model: model, style: .medium)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WidgetVoice.summary(model, units: units))
    }

    private func leftColumn(_ model: TideDayModel) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("St Helier").engravingStyle()
            Text(TideFormatters.mediumDate(model.day)).metaStyle()
            Spacer(minLength: 4)
            if let height = model.currentHeight {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(TideFormatters.heightValue(height, unit: units))
                        .font(TideTypography.dial2(size: heroSize))
                        .foregroundStyle(.sea)
                        .contentTransition(.numericText())
                        .widgetAccentable()
                    Text(TideFormatters.unitSymbol(units))
                        .font(TideTypography.unit(parentSize: heroSize))
                        .foregroundStyle(.seaSecondary)
                }
            }
            Spacer(minLength: 4)
            // Next two extremes, Table voice with emphasis (§6).
            if let next = model.nextExtreme {
                extremeLine(next).foregroundStyle(.sea)
            }
            if let following = model.followingExtreme {
                extremeLine(following).foregroundStyle(.seaSecondary)
            }
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private func extremeLine(_ extreme: TideExtreme) -> some View {
        Text(
            "\(extreme.isHigh ? "HW" : "LW") \(TideFormatters.time(extreme.time))"
                + " · \(TideFormatters.heightValue(extreme.height, unit: units))"
        )
        .tableStyle()
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}
