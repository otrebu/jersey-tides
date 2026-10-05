import SwiftUI

/// Wrist face for one station day. Crown scrolls the page; the chevrons step
/// ±`radius` days. Complication taps (`jerseytides://day/…`) land on that day
/// when it is inside the window.
struct WatchPager: View {
    static let radius = 3

    @State private var dayOffset = 0

    var body: some View {
        TimelineView(.everyMinute) { _ in
            WatchDayPage(dayOffset: dayOffset, onStep: step)
        }
        .background(Color.sky)
        .sensoryFeedback(.selection, trigger: dayOffset)
        .onOpenURL { url in
            guard let day = DeepLink.parse(url) else { return }
            let today = TideTime.calendarDay(of: EngineProvider.clock.now)
            dayOffset = min(
                max(DeepLink.pageOffset(for: day, today: today), -Self.radius),
                Self.radius
            )
        }
    }

    private func step(_ delta: Int) {
        dayOffset = min(max(dayOffset + delta, -Self.radius), Self.radius)
    }
}

private struct WatchDayPage: View {
    let dayOffset: Int
    let onStep: (Int) -> Void

    private let units: HeightUnit = .metres

    var body: some View {
        let now = EngineProvider.clock.now
        let today = TideTime.calendarDay(of: now)
        let day = TideTime.addDays(today, dayOffset)
        let model = TideDayModel.make(day: day, now: dayOffset == 0 ? now : nil)
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                header(model: model)
                hero(model: model, now: now)
                TideCurveView(model: model, style: .watch)
                    .frame(height: 76)
                extremes(model: model)
                sunLine(model: model)
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 8)
        }
        .accessibilityElement(children: .contain)
    }

    private func header(model: TideDayModel) -> some View {
        HStack(spacing: 4) {
            stepButton(systemName: "chevron.left", delta: -1)
            VStack(spacing: 1) {
                Text("St Helier").engravingStyle()
                Text(eyebrow)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(dayOffset == 0 ? Color.dawn : Color.seaSecondary)
                if dayOffset != 0 {
                    Button("Today") { onStep(-dayOffset) }
                        .font(.caption2)
                        .buttonStyle(.plain)
                        .foregroundStyle(.sea)
                }
            }
            .frame(maxWidth: .infinity)
            stepButton(systemName: "chevron.right", delta: 1)
        }
    }

    private var eyebrow: String {
        switch dayOffset {
        case 0: "Today"
        case 1: "Tomorrow"
        case -1: "Yesterday"
        default:
            dayOffset > 0 ? "In \(dayOffset) days" : "\(-dayOffset) days ago"
        }
    }

    private func stepButton(systemName: String, delta: Int) -> some View {
        let enabled = abs(dayOffset + delta) <= WatchPager.radius
        return Button {
            onStep(delta)
        } label: {
            Image(systemName: systemName)
                .font(.caption.weight(.semibold))
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .disabled(!enabled)
        .accessibilityLabel(delta < 0 ? "Previous day" : "Next day")
    }

    @ViewBuilder
    private func hero(model: TideDayModel, now: Date) -> some View {
        if dayOffset == 0, let height = model.currentHeight {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(TideFormatters.height(height, unit: units))
                        .font(.system(size: 34, weight: .ultraLight))
                        .monospacedDigit()
                        .foregroundStyle(.sea)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    if let rising = model.isRising {
                        Image(systemName: WidgetVoice.arrowSymbol(rising: rising))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.sea)
                            .accessibilityLabel(rising ? "Rising" : "Falling")
                    }
                }
                if let next = model.nextExtreme {
                    Text(nextLine(next, now: now))
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.seaSecondary)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(WidgetVoice.summary(model, units: units))
        } else {
            Text(TideFormatters.weekday(model.day))
                .font(.title3.weight(.light))
                .foregroundStyle(.sea)
            Text(TideFormatters.dayMonth(model.day))
                .font(.caption)
                .foregroundStyle(.seaSecondary)
        }
    }

    private func nextLine(_ extreme: TideExtreme, now: Date) -> String {
        let kind = extreme.isHigh ? "HW" : "LW"
        return "\(kind) \(TideFormatters.time(extreme.time)) · \(TideFormatters.countdown(to: extreme.time, from: now))"
    }

    private func extremes(model: TideDayModel) -> some View {
        VStack(spacing: 3) {
            ForEach(model.extremes, id: \.time) { extreme in
                let isNext = extreme.time == model.nextExtreme?.time
                HStack(spacing: 6) {
                    Text(extreme.isHigh ? "HW" : "LW")
                        .frame(width: 22, alignment: .leading)
                    Text(TideFormatters.time(extreme.time))
                    Spacer(minLength: 4)
                    Text(TideFormatters.height(extreme.height, unit: units))
                }
                .font(.caption2.monospacedDigit())
                .foregroundStyle(isNext ? Color.sea : Color.seaSecondary)
            }
        }
    }

    @ViewBuilder
    private func sunLine(model: TideDayModel) -> some View {
        if let sun = model.sun, let rise = sun.sunrise, let set = sun.sunset {
            Text("\(TideFormatters.time(rise)) – \(TideFormatters.time(set))")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.dawn)
                .accessibilityLabel("Sunrise \(TideFormatters.time(rise)), sunset \(TideFormatters.time(set))")
        }
    }
}
