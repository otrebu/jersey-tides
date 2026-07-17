import SwiftUI
import WidgetKit

/// systemSmall "the dial" — typography only, no curve (design doc §6).
/// Honors `config.emphasis` (Next tide / Now) + `config.units`.
///
/// // CHUNK F FILLS THIS — placeholder layout; both emphases, VoiceOver
/// labels, rendering-mode contract §2.1.
struct DialSmallView: View {
    let entry: TideEntry

    var body: some View {
        Group {
            if let model = entry.dayModel {
                VStack(alignment: .leading, spacing: 4) {
                    Text("St Helier").engravingStyle()
                    if let next = model.nextExtreme {
                        Text(next.isHigh ? "HW" : "LW")
                            .font(TideTypography.unit(parentSize: 40))
                            .foregroundStyle(.seaSecondary)
                        Text(TideFormatters.time(next.time))
                            .font(TideTypography.dial2(size: 40))
                            .foregroundStyle(.sea)
                            .widgetAccentable()
                        Text(TideFormatters.height(next.height, unit: entry.config.units))
                            .font(.system(size: 17, weight: .light))
                            .foregroundStyle(.seaSecondary)
                    }
                    Rectangle().fill(Color.hairline).frame(height: 0.5)
                    if let height = model.currentHeight, let rising = model.isRising {
                        Text("now \(TideFormatters.heightValue(height, unit: entry.config.units)) \(rising ? "▲" : "▼")")
                            .font(.footnote)
                            .foregroundStyle(.seaSecondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ErrorTileView(family: .systemSmall)
            }
        }
        .containerBackground(Color.sky, for: .widget)
        .widgetURL(entry.dayModel?.day.deepLinkURL)
    }
}
