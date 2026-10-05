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
        #if os(watchOS)
        wrist
        #else
        phone
        #endif
    }

    #if os(watchOS)
    /// Wrist Siri card is one column wide. Time is the glance; height and
    /// countdown sit under it so a 40 mm face does not truncate the row.
    private var wrist: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(extreme.isHigh ? "HIGH WATER" : "LOW WATER")
                .engravingStyle()
            Text(TideFormatters.time(extreme.time, format: timeFormat))
                .font(TideTypography.dial2(size: 28))
                .foregroundStyle(.sea)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text("\(TideFormatters.height(extreme.height, unit: units)) · \(TideFormatters.countdown(to: extreme.time, from: now))")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.seaSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    #else
    private var phone: some View {
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
    #endif
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
        #if os(watchOS)
        wrist
        #else
        phone
        #endif
    }

    #if os(watchOS)
    private var wrist: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(rising ? "RISING" : "FALLING")
                .engravingStyle()
            Text(TideFormatters.height(level, unit: units))
                .font(TideTypography.dial2(size: 28))
                .foregroundStyle(.sea)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text("\(next.isHigh ? "HW" : "LW") \(TideFormatters.time(next.time, format: timeFormat)) · \(TideFormatters.height(next.height, unit: units))")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.seaSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    #else
    private var phone: some View {
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
    #endif
}
