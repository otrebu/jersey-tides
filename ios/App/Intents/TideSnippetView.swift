import SwiftUI

/// Siri snippet card for a coming extreme. Static render — the countdown is
/// frozen at the instant Siri asked, which is exactly what the dialog says.
struct TideExtremeSnippetView: View {
    let stationName: String
    let extreme: TideExtreme
    let now: Date
    let units: HeightUnit
    let timeFormat: TimeFormatOption

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(stationName.uppercased())
                Spacer()
                Text(extreme.isHigh ? "NEXT HIGH WATER" : "NEXT LOW WATER")
            }
            .engravingStyle()

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: WidgetVoice.arrowSymbol(rising: extreme.isHigh))
                    .imageScale(.small)
                    .foregroundStyle(.seaSecondary)
                Text(TideFormatters.time(extreme.time, format: timeFormat))
                    .font(TideTypography.dial2(size: 34))
                    .foregroundStyle(.sea)
                Text(TideFormatters.height(extreme.height, unit: units))
                    .font(.footnote)
                    .foregroundStyle(.seaSecondary)
                Spacer()
                Text(TideFormatters.countdown(to: extreme.time, from: now))
                    .metaStyle()
            }
        }
        .padding(16)
    }
}

/// Siri snippet card for the current level + where it's heading.
struct TideNowSnippetView: View {
    let stationName: String
    let level: Double
    let rising: Bool
    let next: TideExtreme
    let units: HeightUnit
    let timeFormat: TimeFormatOption

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(stationName.uppercased())
                Spacer()
                Text(rising ? "TIDE RISING" : "TIDE FALLING")
            }
            .engravingStyle()

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(TideFormatters.height(level, unit: units))
                    .font(TideTypography.dial2(size: 34))
                    .foregroundStyle(.sea)
                Image(systemName: WidgetVoice.arrowSymbol(rising: rising))
                    .imageScale(.small)
                    .foregroundStyle(.seaSecondary)
                Spacer()
                Text("\(next.isHigh ? "HW" : "LW") \(TideFormatters.time(next.time, format: timeFormat)) · \(TideFormatters.height(next.height, unit: units))")
                    .metaStyle()
            }
        }
        .padding(16)
    }
}
