import SwiftUI

/// One day's face inside the pager (design doc §5.1, redesign mockup v2).
///
/// TODAY: an accent `TODAY` eyebrow + big date, subtle station/toolbar row, a
/// 7-day dot navigator, a NOW-water-level hero (big height + rising/falling
/// pill over an animated wave band) with a next-event line, the full-bleed
/// curve, a full-bleed extremes table, the SUN day-band, and the MOON row.
///
/// NON-TODAY pages swap the top for a big date header + `‹ Today` chip and drop
/// the hero + next-event line (the model carries `nowInstant == nil`); they keep
/// the dots, curve, table, SUN and MOON sections.
struct DayPage: View {
    let model: TideDayModel
    let isToday: Bool
    /// Signed day offset from today (0 = today) — drives the dot navigator's
    /// window + the relative-day eyebrow.
    var dayOffset: Int = 0
    /// Whether this page is the selected pager page — pauses the hero wave's
    /// per-frame redraw when the today page is swiped off-screen.
    var isActivePage: Bool = true
    /// App options (design doc §7 table 1); defaults keep pinned call sites
    /// compiling.
    var units: HeightUnit = .metres
    var timeFormat: TimeFormatOption = .system
    /// Sun events toggle (§7 #3) — hides curve ticks/times only; the SUN
    /// block is always present (redesign brief: "sunrise and sunset should
    /// always be present").
    var showsSun: Bool = true
    var onGearTap: () -> Void = {}
    var onTodayTap: () -> Void = {}
    /// Moon-row tap → the Fortnight (springs + moon events) overview (§5.2).
    var onSpringsTap: () -> Void = {}
    /// Page to a signed day offset (dot navigator).
    var onSelectOffset: (Int) -> Void = { _ in }
    /// Tide Watch Live Activity toggle — today page only; nil hides the button.
    var isWatching: Bool = false
    var onWatchTap: (() -> Void)?

    /// Dial hero size — 84 pt scaled with Dynamic Type, clamped 64–96 (§3).
    @ScaledMetric(relativeTo: .largeTitle) private var dialSize: CGFloat = 84
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// First-launch trim draw (§11): once, then never again.
    @AppStorage("hasPlayedCurveIntro") private var hasPlayedCurveIntro = false
    @State private var curveProgress: CGFloat = 1
    /// Mirrors the scrub overlay's ScrubEngaged preference — freezes this
    /// page's vertical scroll while a scrub hold owns the touch, so the
    /// readout drag can't also rubber-band the page.
    @State private var scrubEngaged = false

    private let margin: CGFloat = 24
    /// Vertical rhythm between the page's stacked sections (mockup `.app` gap).
    private let sectionSpacing: CGFloat = 20

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: sectionSpacing) {
                header
                dots
                if isToday {
                    heroToday
                }
                curve
                tidesBlock
                sunBlock
                moonRow
            }
            .padding(margin)
        }
        .background(Color.sky.ignoresSafeArea())
        .scrollDisabled(scrubEngaged)
        .onPreferenceChange(ScrubEngagedPreferenceKey.self) { scrubEngaged = $0 }
        .onAppear(perform: playCurveIntroIfNeeded)
    }

    // MARK: Header — station/toolbar row, eyebrow, big date

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Text("St Helier · Jersey").engravingStyle()
                Spacer()
                if isToday {
                    if let onWatchTap {
                        watchButton(onWatchTap)
                    }
                    gearButton
                } else {
                    todayChip
                }
            }
            if isToday {
                Text("Today")
                    .font(TideTypography.engraving)
                    .textCase(.uppercase)
                    .tracking(1.4)
                    .foregroundStyle(.dawn) // accent eyebrow
                Text(TideFormatters.fullDate(model.day))
                    .font(dateTitleFont)
                    .foregroundStyle(.sea)
            } else {
                Text(relativeLabel).engravingStyle()
                Text(TideFormatters.weekday(model.day))
                    .font(dateTitleFont)
                    .foregroundStyle(.sea)
                Text(TideFormatters.dayMonth(model.day) + yearSuffix).metaStyle()
            }
        }
    }

    /// Big date / weekday header — `.title` at light weight (mockup 27 pt/300).
    private var dateTitleFont: Font {
        .system(.title, design: .default).weight(.light)
    }

    /// `Tomorrow` / `Yesterday` / `In N days` / `N days ago` (mockup
    /// `relativeLabel`), easing into rounded months/years far out — the big
    /// date underneath stays exact. Non-today only, so the 0 case never shows.
    private var relativeLabel: String {
        switch dayOffset {
        case 1: return "Tomorrow"
        case -1: return "Yesterday"
        default: break
        }
        let days = abs(dayOffset)
        let phrase: String
        switch days {
        case ..<61: phrase = "\(days) days"
        case ..<700: phrase = "\(Int((Double(days) / 30.437).rounded())) months"
        default: phrase = "\(Int((Double(days) / 365.25).rounded())) years"
        }
        return dayOffset > 0 ? "In \(phrase)" : "\(phrase) ago"
    }

    /// `" 2027"` appended to the non-today subtitle once the page has scrolled
    /// into another year; empty inside the current year. Today is recovered
    /// from this page's own offset, keeping the view clock-free.
    private var yearSuffix: String {
        let todayYear = TideTime.addDays(model.day, -dayOffset).year
        return model.day.year == todayYear ? "" : " \(model.day.year)"
    }

    private func watchButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: isWatching ? "water.waves" : "water.waves.slash")
                .imageScale(.small)
                .foregroundStyle(isWatching ? .sea : .seaSecondary)
                .contentTransition(.symbolEffect(.replace))
        }
        .accessibilityLabel(isWatching ? "Stop Tide Watch" : "Start Tide Watch")
    }

    private var gearButton: some View {
        Button(action: onGearTap) {
            Image(systemName: "gear")
                .imageScale(.small)
                .foregroundStyle(.seaSecondary)
        }
        .accessibilityLabel("Settings")
    }

    /// `‹ TODAY` return chip — capsule with `.glassEffect()` (min OS 26, §5.1).
    private var todayChip: some View {
        Button(action: onTodayTap) {
            Text("‹ Today")
                .font(TideTypography.engraving)
                .textCase(.uppercase)
                .tracking(1.4)
                .foregroundStyle(.sea)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .glassEffect()
        .accessibilityLabel("Back to today")
    }

    // MARK: Day dots — 7-day window navigator (mockup `dotsEl`)

    private var dots: some View {
        let radius = 3
        let count = radius * 2 + 1 // 7-day window
        // Rolling window that always contains the current page; clamped so the
        // 7 dots stay inside the ±pageRadius pager bounds.
        let start = min(
            max(dayOffset - radius, -DeepLink.pageRadius),
            DeepLink.pageRadius - (count - 1)
        )
        return HStack(spacing: 9) {
            ForEach(0..<count, id: \.self) { index in
                dot(offset: start + index)
            }
        }
        .padding(.top, 2)
    }

    private func dot(offset: Int) -> some View {
        let isCurrent = offset == dayOffset
        let isTodayDot = offset == 0
        let color: Color = isCurrent ? (isTodayDot ? .dawn : .sea) : .seaTertiary
        return Button {
            onSelectOffset(offset)
        } label: {
            Capsule()
                .fill(color)
                .frame(width: isCurrent ? 22 : 7, height: 7)
                .overlay {
                    // Today marker (when not the current pill): a haloing ring.
                    if isTodayDot, !isCurrent {
                        Circle()
                            .strokeBorder(Color.seaTertiary, lineWidth: 1.5)
                            .frame(width: 13, height: 13)
                    }
                }
                .frame(height: 16) // enlarge the vertical hit target
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(dotAccessibilityLabel(offset: offset, isCurrent: isCurrent))
    }

    private func dotAccessibilityLabel(offset: Int, isCurrent: Bool) -> String {
        let dotDay = TideTime.addDays(model.day, offset - dayOffset)
        let label = "\(TideFormatters.weekday(dotDay)) \(TideFormatters.dayMonth(dotDay))"
        return isCurrent ? "\(label), selected" : label
    }

    // MARK: Hero — NOW water level (today only)

    @ViewBuilder
    private var heroToday: some View {
        if let height = model.currentHeight, let rising = model.isRising,
           let next = model.nextExtreme, let now = model.nowInstant {
            VStack(alignment: .leading, spacing: 2) {
                Text("Now · water level").engravingStyle()
                HStack(alignment: .center, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(TideFormatters.heightValue(height, unit: units))
                            .font(TideTypography.dial(size: clampedDialSize))
                            .foregroundStyle(.sea)
                            .contentTransition(.numericText())
                        Text(TideFormatters.unitSymbol(units))
                            .font(TideTypography.unit(parentSize: clampedDialSize))
                            .foregroundStyle(.seaSecondary)
                    }
                    trendPill(rising: rising)
                }
                nextEventLine(next: next, now: now)
                    .padding(.top, 6)
            }
            .padding(.horizontal, margin)
            .padding(.top, 6)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(WaveBand(rising: rising, isActive: isActivePage)) // full-bleed wave behind the number
            .padding(.horizontal, -margin)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                heroAccessibilityLabel(height: height, rising: rising, next: next, now: now)
            )
        }
    }

    /// `▲ RISING` / `▼ FALLING` capsule — dawn triangle + engraved caption on a
    /// faint `sea` chip (mockup `.trend`).
    private func trendPill(rising: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: rising ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                .font(.system(size: 8))
                .foregroundStyle(.dawn)
            Text(rising ? "Rising" : "Falling")
                .font(TideTypography.engraving)
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(.seaSecondary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.sea.opacity(0.06)))
        .overlay(Capsule().strokeBorder(Color.sea.opacity(0.16), lineWidth: 0.5))
        .accessibilityHidden(true) // the hero label already states the trend
    }

    /// `Next high water 7.9 m · 15:11 · in 1 h 26 m` (mockup `.hero-next`):
    /// the event bold in `sea`, the rest `seaSecondary`, dot separators tertiary.
    private func nextEventLine(next: TideExtreme, now: Date) -> some View {
        let label = next.isHigh ? "high water" : "low water"
        let heightStr = TideFormatters.height(next.height, unit: units)
        let timeStr = TideFormatters.time(next.time, format: timeFormat)
        let countdown = TideFormatters.countdown(to: next.time, from: now)
        return (
            Text("Next ").foregroundStyle(.seaSecondary)
                + Text("\(label) \(heightStr)").foregroundStyle(.sea).fontWeight(.medium)
                + Text(" · ").foregroundStyle(.seaTertiary)
                + Text(timeStr).foregroundStyle(.seaSecondary)
                + Text(" · ").foregroundStyle(.seaTertiary)
                + Text(countdown).foregroundStyle(.seaSecondary)
        )
        .font(TideTypography.table)
        .contentTransition(.numericText())
    }

    private func heroAccessibilityLabel(
        height: Double, rising: Bool, next: TideExtreme, now: Date
    ) -> String {
        let level = TideFormatters.height(height, unit: units)
        let trend = rising ? "rising" : "falling"
        let kind = next.isHigh ? "high water" : "low water"
        let nextHeight = TideFormatters.height(next.height, unit: units)
        let nextTime = TideFormatters.time(next.time, format: timeFormat)
        let countdown = TideFormatters.countdown(to: next.time, from: now)
        return "Now \(level), \(trend). Next \(kind) \(nextHeight) at \(nextTime), \(countdown)."
    }

    private var clampedDialSize: CGFloat {
        min(max(dialSize, 64), 96)
    }

    // MARK: Curve — full-bleed, 200 pt

    private var curve: some View {
        TideCurveView(model: model, style: curveStyle)
            .overlay(
                TideScrubOverlay(
                    model: model, style: curveStyle, units: units, timeFormat: timeFormat
                )
            )
            .frame(height: 200)
            // Reveal mask BEFORE the negative padding: applied after, the
            // mask's GeometryReader sizes to the padded (354 pt) frame and
            // permanently clips the 24 pt full-bleed overhang — cutting the
            // curve stroke and any extreme label near the screen edges.
            .modifier(CurveIntroReveal(progress: curveProgress, crossfade: reduceMotion))
            .padding(.horizontal, -margin) // full-bleed to the screen edges
            .animation(.easeInOut(duration: 0.18), value: model.day) // §11 crossfade
    }

    private var curveStyle: CurveStyle {
        var style = CurveStyle.app
        style.showsSunTicks = showsSun
        style.showsSunTimes = showsSun
        return style
    }

    /// §11 first-launch-only draw: left→right reveal, 0.6 s easeOut, persisted.
    /// Reduce Motion → crossfade instead.
    private func playCurveIntroIfNeeded() {
        guard isToday, !hasPlayedCurveIntro else { return }
        hasPlayedCurveIntro = true
        curveProgress = 0
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.6)) {
                curveProgress = 1
            }
        }
    }

    // MARK: Tides — full-bleed extremes table

    private var tidesBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tides").engravingStyle()
            ExtremesTable(
                rows: model.rows,
                nowInstant: model.nowInstant,
                units: units,
                timeFormat: timeFormat,
                contentInset: margin
            )
            .padding(.horizontal, -margin) // full-bleed rows + highlight
        }
    }

    // MARK: Sun — day-band + summary row (mockup `sunEl`)

    @ViewBuilder
    private var sunBlock: some View {
        if let sun = model.sun,
           let band = DaylightBand(sun: sun, now: model.nowInstant, timeFormat: timeFormat),
           let row = DaylightSummaryRow(sun: sun, timeFormat: timeFormat) {
            VStack(alignment: .leading, spacing: 9) {
                Text("Sun").engravingStyle()
                band.padding(.horizontal, -margin) // full-bleed 24 h track
                row
            }
        }
    }

    // MARK: Moon — phase row (tap opens the Fortnight overview)

    private var moonRow: some View {
        Button(action: onSpringsTap) {
            MoonPhaseRow(
                name: model.moonPhase.name.capitalized,
                illuminatedFraction: model.moonPhase.illumination,
                waxing: model.moonPhase.phaseFraction < 0.5
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the fortnight overview")
    }
}

/// Left→right reveal for the first-launch curve draw; opacity crossfade under
/// Reduce Motion (§11).
private struct CurveIntroReveal: ViewModifier {
    let progress: CGFloat
    let crossfade: Bool

    func body(content: Content) -> some View {
        if crossfade {
            content.opacity(progress)
        } else {
            content.mask(alignment: .leading) {
                GeometryReader { geo in
                    Rectangle()
                        .frame(width: geo.size.width * progress)
                }
            }
        }
    }
}
