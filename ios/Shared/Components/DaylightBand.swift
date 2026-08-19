import Foundation
import SwiftUI

/// Daylight band — the Today screen's SUN section (design mockup v2 `sunEl`).
/// A full-bleed 24 h track: a dim night base, a warm daylight span from sunrise
/// → sunset, a shallow arc peaking at solar noon, endpoint pips, and — today
/// only — a sun marker riding the arc at `now`. Pairs above `DaylightSummaryRow`
/// ("06:04 → 21:12 · 15 h 08 of daylight").
///
/// Purely graphical, so it scales with the container width and ignores Dynamic
/// Type (its paired row carries the text). Colours derive from the `dawn`/`sea`
/// tokens at the mockup's opacities, so no new tokens are added to Tokens.swift
/// (keeping widget rendering untouched).
struct DaylightBand: View {
    /// Sunrise instant (absolute; minute-of-day taken in station time).
    let sunrise: Date
    /// Sunset instant.
    let sunset: Date
    /// Current instant for the sun marker; nil hides it (non-today pages).
    let now: Date?
    /// Track height; the mockup's 34 pt design box scales proportionally.
    var height: CGFloat = 34
    /// Time-of-day format for the accessibility value (matches the paired row).
    var timeFormat: TimeFormatOption = .system

    init(sunrise: Date, sunset: Date, now: Date? = nil, height: CGFloat = 34,
         timeFormat: TimeFormatOption = .system) {
        self.sunrise = sunrise
        self.sunset = sunset
        self.now = now
        self.height = height
        self.timeFormat = timeFormat
    }

    /// Convenience over the engine facade's `SunTimes`; nil when either end is
    /// absent (polar edge case — callers skip the band, like the mockup).
    init?(sun: SunTimes, now: Date? = nil, height: CGFloat = 34,
          timeFormat: TimeFormatOption = .system) {
        guard let sunrise = sun.sunrise, let sunset = sun.sunset else { return nil }
        self.init(sunrise: sunrise, sunset: sunset, now: now, height: height,
                  timeFormat: timeFormat)
    }

    // Mockup derivations, anchored to existing tokens (§ Tokens.swift):
    // band-day-a / band-day-b (warm span), band-night (dim base).
    private let dayEdge = Color.dawn.opacity(0.28)
    private let dayNoon = Color.dawn.opacity(0.10)
    private let night = Color.sea.opacity(0.055)

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let s = size.height / 34            // design units → points
            func x(_ minute: Double) -> CGFloat { CGFloat(minute / 1440) * w }

            let sr = minuteOfDay(sunrise)
            let ss = minuteOfDay(sunset)
            let xr = x(sr)
            let xs = x(ss)

            // Rounded bar geometry (mockup y 10, h 14, rx 3).
            let barRect = CGRect(x: 0, y: 10 * s, width: w, height: 14 * s)
            let corner = 3 * s

            // Night base then the warm daylight span (a → b → a across the span).
            context.fill(Path(roundedRect: barRect, cornerRadius: corner), with: .color(night))
            let spanRect = CGRect(x: xr, y: 10 * s, width: max(0, xs - xr), height: 14 * s)
            context.fill(
                Path(roundedRect: spanRect, cornerRadius: corner),
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: dayEdge, location: 0),
                        .init(color: dayNoon, location: 0.5),
                        .init(color: dayEdge, location: 1),
                    ]),
                    startPoint: CGPoint(x: xr, y: 0),
                    endPoint: CGPoint(x: xs, y: 0)
                )
            )

            // Gentle daylight arc peaking at solar noon.
            let noon = (sr + ss) / 2
            var arc = Path()
            arc.move(to: CGPoint(x: xr, y: 17 * s))
            arc.addQuadCurve(
                to: CGPoint(x: xs, y: 17 * s),
                control: CGPoint(x: x(noon), y: 3 * s)
            )
            context.stroke(arc, with: .color(.dawn.opacity(0.55)), lineWidth: 1)

            // Sunrise / sunset endpoint pips (r 2.4).
            for cx in [xr, xs] {
                context.fill(
                    Path(ellipseIn: CGRect(x: cx - 2.4, y: 17 * s - 2.4, width: 4.8, height: 4.8)),
                    with: .color(.dawn)
                )
            }

            // Sun position marker — today only, while the sun is up.
            if let now, now >= sunrise, now <= sunset {
                let fraction = now.timeIntervalSince(sunrise)
                    / sunset.timeIntervalSince(sunrise)
                let sy = (17 - sin(fraction * .pi) * 13) * s
                let cx = x(minuteOfDay(now))
                context.fill(
                    Path(ellipseIn: CGRect(x: cx - 4, y: sy - 4, width: 8, height: 8)),
                    with: .color(.dawn)
                )
                context.stroke(
                    Path(ellipseIn: CGRect(x: cx - 6.5, y: sy - 6.5, width: 13, height: 13)),
                    with: .color(.dawn.opacity(0.5)),
                    lineWidth: 1
                )
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityLabel("Daylight")
        .accessibilityValue(
            "\(TideFormatters.time(sunrise, format: timeFormat)) to \(TideFormatters.time(sunset, format: timeFormat))"
        )
    }

    /// Minutes since local midnight in station time (0…1440).
    private func minuteOfDay(_ date: Date) -> Double {
        let parts = TideTime.calendar.dateComponents([.hour, .minute, .second], from: date)
        return Double((parts.hour ?? 0) * 60 + (parts.minute ?? 0))
            + Double(parts.second ?? 0) / 60
    }
}

/// The sun row beneath the band: a small sun glyph, `sunrise → sunset`, and the
/// day-length line ("15 h 08 of daylight"). Meta voice; Dynamic Type friendly.
struct DaylightSummaryRow: View {
    let sunrise: Date
    let sunset: Date
    let dayLength: TimeInterval?
    var timeFormat: TimeFormatOption = .system

    /// Convenience over `SunTimes`; nil when either end is absent.
    init?(sun: SunTimes, timeFormat: TimeFormatOption = .system) {
        guard let sunrise = sun.sunrise, let sunset = sun.sunset else { return nil }
        self.sunrise = sunrise
        self.sunset = sunset
        self.dayLength = sun.dayLength
        self.timeFormat = timeFormat
    }

    init(sunrise: Date, sunset: Date, dayLength: TimeInterval?, timeFormat: TimeFormatOption = .system) {
        self.sunrise = sunrise
        self.sunset = sunset
        self.dayLength = dayLength
        self.timeFormat = timeFormat
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "sun.max.fill")
                .foregroundStyle(.dawn)
                .imageScale(.small)
            Text(TideFormatters.time(sunrise, format: timeFormat))
                .foregroundStyle(.sea)
            Text("→").foregroundStyle(.seaTertiary)
            Text(TideFormatters.time(sunset, format: timeFormat))
                .foregroundStyle(.sea)
            Spacer(minLength: 8)
            if let dayLength {
                Text("\(TideFormatters.dayLength(dayLength)) of daylight")
                    .foregroundStyle(.seaSecondary)
            }
        }
        .font(TideTypography.meta)
        .monospacedDigit()
    }
}

#Preview("Daylight band — today") {
    let today = TideTime.calendarDay(of: .now)
    let sunrise = TideTime.date(today, hour: 6, minute: 4)
    let sunset = TideTime.date(today, hour: 21, minute: 12)
    let now = TideTime.date(today, hour: 13, minute: 45)
    return VStack(alignment: .leading, spacing: 9) {
        Text("SUN").engravingStyle()
        DaylightBand(sunrise: sunrise, sunset: sunset, now: now)
        DaylightSummaryRow(
            sunrise: sunrise, sunset: sunset,
            dayLength: sunset.timeIntervalSince(sunrise)
        )
    }
    .padding()
    .background(Color.sky)
}

#Preview("Daylight band — non-today (no marker)") {
    let day = TideTime.calendarDay(of: .now)
    let sunrise = TideTime.date(day, hour: 5, minute: 33)
    let sunset = TideTime.date(day, hour: 20, minute: 55)
    return VStack(alignment: .leading, spacing: 9) {
        DaylightBand(sunrise: sunrise, sunset: sunset, now: nil)
        DaylightSummaryRow(
            sunrise: sunrise, sunset: sunset,
            dayLength: sunset.timeIntervalSince(sunrise)
        )
    }
    .padding()
    .background(Color.sky)
    .preferredColorScheme(.dark)
}
