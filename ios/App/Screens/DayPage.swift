import SwiftUI

/// One day's face inside the pager (design doc §5.1): Engraving station header
/// + gear, Meta date, springs/moon line, hero (next tide + countdown on today;
/// the day's first HW elsewhere), full-bleed curve, 4-column extremes table,
/// SUN row, TOMORROW tap-to-page row.
///
/// Non-today pages hero the day's first HW, drop the now marker (the model
/// carries `nowInstant == nil`), and show the `‹ TODAY` return chip.
struct DayPage: View {
    let model: TideDayModel
    let isToday: Bool
    /// App options (design doc §7 table 1); defaults keep the pinned
    /// `DayPage(model:isToday:)` call sites compiling.
    var units: HeightUnit = .metres
    var timeFormat: TimeFormatOption = .system
    /// Sun events toggle (§7 #3) — hides curve ticks/times and the SUN row.
    var showsSun: Bool = true
    var onGearTap: () -> Void = {}
    var onTodayTap: () -> Void = {}
    var onSpringsTap: () -> Void = {}
    var onTomorrowTap: () -> Void = {}
    /// Tide Watch Live Activity toggle — today page only; nil hides the button.
    var isWatching: Bool = false
    var onWatchTap: (() -> Void)?

    /// Dial hero size — 84 pt scaled with Dynamic Type, clamped 64–96 (§3).
    @ScaledMetric(relativeTo: .largeTitle) private var dialSize: CGFloat = 84
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// First-launch trim draw (§11): once, then never again.
    @AppStorage("hasPlayedCurveIntro") private var hasPlayedCurveIntro = false
    @State private var curveProgress: CGFloat = 1

    private let margin: CGFloat = 24

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: margin) {
                header
                hero
                curve
                tableBlock
            }
            .padding(margin)
        }
        .background(Color.sky.ignoresSafeArea())
        .onAppear(perform: playCurveIntroIfNeeded)
    }

    // MARK: Header — station, gear, date, springs/moon line

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Text("St Helier · Jersey").engravingStyle()
                Spacer()
                if !isToday {
                    todayChip
                }
                if isToday, let onWatchTap {
                    Button(action: onWatchTap) {
                        Image(systemName: isWatching ? "water.waves" : "water.waves.slash")
                            .imageScale(.small)
                            .foregroundStyle(isWatching ? .sea : .seaSecondary)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .accessibilityLabel(isWatching ? "Stop Tide Watch" : "Start Tide Watch")
                }
                Button(action: onGearTap) {
                    Image(systemName: "gear")
                        .imageScale(.small)
                        .foregroundStyle(.seaSecondary)
                }
                .accessibilityLabel("Settings")
            }
            Text(TideFormatters.fullDate(model.day)).metaStyle()
            springsLine
        }
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

    /// `● SPRINGS · full moon in 2 d` — Meta; moon glyph in dawn. Tap opens
    /// the Fortnight sheet (§5.2). Omitted entirely when there is nothing to say.
    @ViewBuilder
    private var springsLine: some View {
        let label = model.springs.map { $0 == .springs ? "SPRINGS" : "NEAPS" }
        let caption = [label, model.moonCaption].compactMap(\.self).joined(separator: " · ")
        if !caption.isEmpty {
            Button(action: onSpringsTap) {
                HStack(spacing: 6) {
                    if let symbol = model.moonSymbolName {
                        Image(systemName: symbol)
                            .imageScale(.small)
                            .foregroundStyle(.dawn)
                    }
                    Text(caption).metaStyle()
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Fortnight overview. \(caption.capitalized)")
        }
    }

    // MARK: Hero

    @ViewBuilder
    private var hero: some View {
        if isToday {
            todayHero
        } else {
            firstHighHero
        }
    }

    /// NEXT HIGH WATER · 14:32 · 11.2 m · in 2 h 08 m · now 8.4 m ▲ rising.
    @ViewBuilder
    private var todayHero: some View {
        if let next = model.nextExtreme, let now = model.nowInstant {
            VStack(alignment: .leading, spacing: 4) {
                Text(next.isHigh ? "Next high water" : "Next low water")
                    .engravingStyle()
                Text(TideFormatters.time(next.time, format: timeFormat))
                    .font(TideTypography.dial(size: clampedDialSize))
                    .foregroundStyle(.sea)
                    .contentTransition(.numericText())
                Text(
                    "\(TideFormatters.height(next.height, unit: units)) · \(TideFormatters.countdown(to: next.time, from: now))"
                )
                .tableStyle()
                .foregroundStyle(.seaSecondary)
                .contentTransition(.numericText())
                nowLine
                    .padding(.top, 8)
            }
            .accessibilityElement(children: .combine)
        }
    }

    /// `now 8.4 m ▲ rising` — Meta, sea; arrow SF symbol at small scale (§3).
    @ViewBuilder
    private var nowLine: some View {
        if let height = model.currentHeight, let rising = model.isRising {
            HStack(spacing: 5) {
                Text("now \(TideFormatters.height(height, unit: units))")
                    .contentTransition(.numericText())
                Image(systemName: rising ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .imageScale(.small)
                    .scaleEffect(0.6)
                Text(rising ? "rising" : "falling")
            }
            .font(TideTypography.meta)
            .foregroundStyle(.sea)
            .accessibilityLabel(
                "Now \(TideFormatters.height(height, unit: units)), \(rising ? "rising" : "falling")"
            )
        }
    }

    /// Non-today hero: the day's first HW as `HW 03:02` in Dial, no countdown.
    @ViewBuilder
    private var firstHighHero: some View {
        if let first = model.extremes.first(where: \.isHigh) ?? model.extremes.first {
            VStack(alignment: .leading, spacing: 4) {
                Text(first.isHigh ? "High water" : "Low water").engravingStyle()
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(first.isHigh ? "HW" : "LW")
                        .font(TideTypography.unit(parentSize: clampedDialSize))
                        .foregroundStyle(.seaSecondary)
                    Text(TideFormatters.time(first.time, format: timeFormat))
                        .font(TideTypography.dial(size: clampedDialSize))
                        .foregroundStyle(.sea)
                        .contentTransition(.numericText())
                }
                Text(TideFormatters.height(first.height, unit: units))
                    .tableStyle()
                    .foregroundStyle(.seaSecondary)
            }
            .accessibilityElement(children: .combine)
        }
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

    // MARK: Table block — TODAY · extremes · SUN · TOMORROW

    private var tableBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isToday ? "Today" : TideFormatters.shortDate(model.day))
                .engravingStyle()
            ExtremesTable(
                rows: model.rows,
                nowInstant: model.nowInstant,
                units: units,
                timeFormat: timeFormat
            )
            if showsSun {
                sunRow
            }
            tomorrowRow
        }
    }

    /// `SUN 06:04 → 21:12 · 15 h 08` — Meta, two small dawn tick glyphs inline.
    @ViewBuilder
    private var sunRow: some View {
        if let sun = model.sun, let sunrise = sun.sunrise, let sunset = sun.sunset {
            HStack(spacing: 6) {
                Text("SUN")
                    .font(TideTypography.engraving)
                    .tracking(1.4)
                    .foregroundStyle(.seaSecondary)
                sunTick
                Text(TideFormatters.time(sunrise, format: timeFormat))
                Text("→").foregroundStyle(.seaTertiary)
                sunTick
                Text(TideFormatters.time(sunset, format: timeFormat))
                if let length = sun.dayLength {
                    Text("· \(TideFormatters.dayLength(length))")
                }
            }
            .font(TideTypography.meta)
            .foregroundStyle(.seaSecondary)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "Sunrise \(TideFormatters.time(sunrise, format: timeFormat)), sunset \(TideFormatters.time(sunset, format: timeFormat))"
            )
        }
    }

    /// 1 pt dawn vertical, 7 pt tall — the curve's sun tick, quoted inline (§5.1).
    private var sunTick: some View {
        Rectangle()
            .fill(Color.dawn)
            .frame(width: 1, height: 7)
    }

    /// `TOMORROW  HW 03:02 · LW 09:15` — Meta seaSecondary; tap = page forward.
    @ViewBuilder
    private var tomorrowRow: some View {
        if let tomorrow = model.tomorrow {
            let parts = [
                tomorrow.firstHigh.map { "HW \(TideFormatters.time($0.time, format: timeFormat))" },
                tomorrow.firstLow.map { "LW \(TideFormatters.time($0.time, format: timeFormat))" },
            ].compactMap(\.self)
            if !parts.isEmpty {
                Button(action: onTomorrowTap) {
                    HStack(spacing: 12) {
                        Text("Tomorrow").engravingStyle()
                        Text(parts.joined(separator: " · "))
                            .metaStyle()
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Tomorrow: \(parts.joined(separator: ", ")). Opens tomorrow's page.")
            }
        }
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
