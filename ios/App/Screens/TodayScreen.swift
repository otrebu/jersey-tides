import SwiftUI

/// Screen 1 — the instrument face (design doc §5.1): `TabView(.page)` pager
/// hard-bounded ±14 days, hero + countdown, curve, 4-column table, sheets,
/// TODAY chip with `.glassEffect()` + `.sensoryFeedback` soft tick.
///
/// // CHUNK C FILLS THIS — placeholder renders a single-day face so the
/// scaffold runs and screenshots.
struct TodayScreen: View {
    /// Deep-link target set by JerseyTidesApp; consume + clear when honoring.
    @Binding var requestedDay: CalendarDay?

    private let clock = EngineProvider.clock

    var body: some View {
        let now = clock.now
        let model = TideDayModel.make(day: TideTime.calendarDay(of: now), now: now)
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("St Helier · Jersey").engravingStyle()
                Text(TideFormatters.fullDate(model.day)).metaStyle()
                if let springs = model.springs {
                    Text("\(springs == .springs ? "Springs" : "Neaps")\(model.moonCaption.map { " · \($0)" } ?? "")")
                        .metaStyle()
                }
                if let next = model.nextExtreme {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(next.isHigh ? "Next high water" : "Next low water")
                            .engravingStyle()
                        Text(TideFormatters.time(next.time))
                            .font(TideTypography.dial())
                            .foregroundStyle(.sea)
                        Text("\(TideFormatters.height(next.height, unit: .metres)) · \(TideFormatters.countdown(to: next.time, from: now))")
                            .tableStyle()
                            .foregroundStyle(.seaSecondary)
                    }
                }
                if let height = model.currentHeight, let rising = model.isRising {
                    Text("now \(TideFormatters.height(height, unit: .metres)) \(rising ? "▲ rising" : "▼ falling")")
                        .metaStyle(.sea)
                }
                TideCurveView(model: model, style: .app)
                    .frame(height: 200)
                Text("Today").engravingStyle()
                ExtremesTable(rows: model.rows, nowInstant: model.nowInstant, units: .metres)
                Text("Chunk C fills this screen").metaStyle(.seaTertiary)
            }
            .padding(24)
        }
        .background(Color.sky.ignoresSafeArea())
    }
}
