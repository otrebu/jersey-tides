import SwiftUI
import WidgetKit

/// systemMedium "the chart room" (design doc §6): fixed 116 pt left column
/// (station, date, level 28 pt thin, next two extremes) · hairline divider ·
/// TideCurveView(.medium).
///
/// // CHUNK F FILLS THIS — placeholder layout.
struct ChartMediumView: View {
    let entry: TideEntry

    var body: some View {
        Group {
            if let model = entry.dayModel {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("St Helier").engravingStyle()
                        Text(TideFormatters.shortDate(model.day)).metaStyle()
                        if let height = model.currentHeight {
                            Text(TideFormatters.height(height, unit: entry.config.units))
                                .font(TideTypography.dial2(size: 28))
                                .foregroundStyle(.sea)
                                .widgetAccentable()
                        }
                        if let next = model.nextExtreme {
                            Text("\(next.isHigh ? "HW" : "LW") \(TideFormatters.time(next.time))")
                                .tableStyle()
                                .foregroundStyle(.sea)
                        }
                        if let following = model.followingExtreme {
                            Text("\(following.isHigh ? "HW" : "LW") \(TideFormatters.time(following.time))")
                                .tableStyle()
                                .foregroundStyle(.seaSecondary)
                        }
                    }
                    .frame(width: 116, alignment: .leading)
                    Rectangle().fill(Color.hairline).frame(width: 0.5)
                    TideCurveView(model: model, style: .medium)
                }
            } else {
                ErrorTileView(family: .systemMedium)
            }
        }
        .containerBackground(Color.sky, for: .widget)
        .widgetURL(entry.dayModel?.day.deepLinkURL)
    }
}
