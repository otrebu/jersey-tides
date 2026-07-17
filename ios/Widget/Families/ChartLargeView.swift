import SwiftUI
import WidgetKit

/// systemLarge "the full instrument" (design doc §6): header, hero 34 pt,
/// TideCurveView(.large), 4-column table with swing, OVER caption, SUN row,
/// TOMORROW line + ghost sparkline (Glass graft #4).
///
/// // CHUNK F FILLS THIS — placeholder layout.
struct ChartLargeView: View {
    let entry: TideEntry

    var body: some View {
        Group {
            if let model = entry.dayModel {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("St Helier · Jersey").engravingStyle()
                        Spacer()
                        Text(TideFormatters.mediumDate(model.day)).metaStyle()
                    }
                    if let height = model.currentHeight, let rising = model.isRising {
                        Text("\(TideFormatters.height(height, unit: entry.config.units)) \(rising ? "▲" : "▼")")
                            .font(TideTypography.dial2(size: 34))
                            .foregroundStyle(.sea)
                            .widgetAccentable()
                    }
                    TideCurveView(model: model, style: .large)
                        .frame(height: 170)
                    ForEach(model.rows, id: \.extreme) { row in
                        HStack(spacing: 16) {
                            Text(row.extreme.isHigh ? "HW" : "LW").engravingStyle()
                            Text(TideFormatters.time(row.extreme.time)).tableStyle()
                            Spacer()
                            Text(TideFormatters.heightValue(row.extreme.height, unit: entry.config.units))
                                .tableStyle()
                            if let swing = row.swing {
                                Text(TideFormatters.swing(swing))
                                    .tableStyle()
                                    .foregroundStyle(.seaSecondary)
                            }
                        }
                        .foregroundStyle(.sea)
                    }
                    if let tomorrow = model.tomorrow {
                        HStack {
                            Text("Tomorrow").engravingStyle()
                            if let firstHigh = tomorrow.firstHigh {
                                Text("HW \(TideFormatters.time(firstHigh.time)) · \(TideFormatters.height(firstHigh.height, unit: entry.config.units))")
                                    .metaStyle()
                            }
                        }
                        Sparkline(samples: tomorrow.samples, bounds: tomorrow.bounds)
                            .frame(height: 20)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ErrorTileView(family: .systemLarge)
            }
        }
        .containerBackground(Color.sky, for: .widget)
        .widgetURL(entry.dayModel?.day.deepLinkURL)
    }
}
