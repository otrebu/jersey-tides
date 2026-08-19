import SwiftUI
import WidgetKit

/// systemMedium "the schedule" — the next four turnings as stations on a line
/// (widget canvas concept #3): triangle above the hairline, time and height
/// below, countdown on the first. For planning the next ~24 h without reading
/// a curve.
///
/// Rendering-mode contract §2.1: the first station (triangle + time) is the
/// accent group; no `dawn` element at this size.
struct ScheduleMediumView: View {
    let entry: TideEntry

    private var units: HeightUnit { entry.config.units }

    var body: some View {
        Group {
            if let model = entry.dayModel, !stations.isEmpty {
                schedule(model)
            } else {
                ErrorTileView(family: .systemMedium)
            }
        }
        .containerBackground(Color.sky, for: .widget)
        .widgetURL(entry.dayModel?.day.deepLinkURL)
    }

    // MARK: Data

    private struct Station: Identifiable {
        let id: Date
        let extreme: TideExtreme
        /// `THU` when the station falls on a different local day than today.
        let dayTag: String?
        let isFirst: Bool
    }

    /// The next four extremes from the display instant (engine facade is
    /// pure + offline; the lookup is a handful of harmonic evaluations).
    private var stations: [Station] {
        let now = entry.displayInstant
        let today = TideTime.calendarDay(of: now)
        return EngineProvider.engine
            .extremes(from: now, to: now.addingTimeInterval(28 * 3600))
            .prefix(4)
            .enumerated()
            .map { index, extreme in
                let day = TideTime.calendarDay(of: extreme.time)
                return Station(
                    id: extreme.time,
                    extreme: extreme,
                    dayTag: day == today
                        ? nil : TideFormatters.weekday(day).prefix(3).uppercased(),
                    isFirst: index == 0
                )
            }
    }

    // MARK: Layout

    private func schedule(_ model: TideDayModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("St Helier · Jersey").engravingStyle()
                Spacer()
                Text(TideFormatters.mediumDate(model.day)).metaStyle()
            }
            stationRow
                .frame(maxHeight: .infinity)
                .padding(.top, 4)
            Rectangle().fill(Color.hairline).frame(height: 0.5)
            footer(model)
                .padding(.top, 5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WidgetVoice.summary(model, units: units))
    }

    private var stationRow: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(stations) { station in
                stationColumn(station)
                    .frame(maxWidth: .infinity)
            }
        }
        // The timeline: one hairline through the triangle row.
        .background(alignment: .top) {
            Rectangle()
                .fill(Color.hairline)
                .frame(height: 0.5)
                .padding(.horizontal, 4)
                .offset(y: 20)
        }
    }

    private func stationColumn(_ station: Station) -> some View {
        let extreme = station.extreme
        return VStack(spacing: 1) {
            Text(station.dayTag ?? " ")
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(.seaTertiary)
                .frame(height: 11)
            Image(systemName: WidgetVoice.arrowSymbol(rising: extreme.isHigh))
                .font(.system(size: 11))
                .foregroundStyle(station.isFirst ? Color.sea : .seaTertiary)
                .frame(height: 17)
                .widgetAccentable(station.isFirst)
            Text(TideFormatters.time(extreme.time))
                .font(.system(size: 17, weight: .light))
                .monospacedDigit()
                .foregroundStyle(station.isFirst ? Color.sea : .seaSecondary)
                .widgetAccentable(station.isFirst)
                .padding(.top, 4)
            Text(TideFormatters.height(extreme.height, unit: units))
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.seaSecondary)
            Text(
                station.isFirst
                    ? TideFormatters.countdown(to: extreme.time, from: entry.displayInstant)
                    : " "
            )
            .font(.caption2)
            .monospacedDigit()
            .foregroundStyle(.seaSecondary)
            .frame(height: 12)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.85)
    }

    /// `now 7.9 ▲ rising`
    private func footer(_ model: TideDayModel) -> some View {
        HStack(spacing: 4) {
            if let height = model.currentHeight, let rising = model.isRising {
                Text("now \(TideFormatters.heightValue(height, unit: units))")
                Image(systemName: WidgetVoice.arrowSymbol(rising: rising))
                    .font(.system(size: 8))
                Text(rising ? "rising" : "falling")
            }
        }
        .font(.caption)
        .monospacedDigit()
        .foregroundStyle(.seaSecondary)
    }
}
