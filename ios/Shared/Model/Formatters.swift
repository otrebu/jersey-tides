import Foundation

/// App-side time format option (design doc §7 #2). Widgets always follow system.
enum TimeFormatOption: String, Codable, CaseIterable, Sendable {
    case system
    case twentyFourHour
    case twelveHour
}

/// Display formatting (design doc §3 rules): heights one decimal + thin space
/// (U+2009) + small unit, feet display-side only; times absolute in station
/// time; countdowns in-app only.
enum TideFormatters {
    static let thinSpace = "\u{2009}"
    /// Display-side conversion factor (design doc §7 #1).
    static let feetPerMetre = 3.28084

    // MARK: Heights

    static func unitSymbol(_ unit: HeightUnit) -> String {
        unit == .feet ? "ft" : "m"
    }

    /// `"11.2"` — one decimal, no unit (swing column, gauge label).
    static func heightValue(_ metres: Double, unit: HeightUnit) -> String {
        let value = unit == .feet ? metres * feetPerMetre : metres
        return String(format: "%.1f", value)
    }

    /// `"11.2 m"` — value + thin space + unit.
    static func height(_ metres: Double, unit: HeightUnit) -> String {
        heightValue(metres, unit: unit) + thinSpace + unitSymbol(unit)
    }

    /// `"↑ 9.2"` / `"↓ 8.5"` — text arrows, Table voice (design doc §5.1).
    static func swing(_ delta: Double) -> String {
        String(format: "%@ %.1f", delta >= 0 ? "↑" : "↓", abs(delta))
    }

    // MARK: Times

    /// Absolute wall-clock time in station time (`"14:32"`).
    static func time(_ instant: Date, format: TimeFormatOption = .system) -> String {
        var style = Date.FormatStyle(timeZone: TideTime.timeZone)
        switch format {
        case .system:
            style = style.hour().minute()
        case .twentyFourHour:
            style = style.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)
        case .twelveHour:
            // Force a 12-hour cycle even when the device locale is 24-hour —
            // `defaultDigits(amPM:)` alone follows the locale's hour cycle.
            var components = Locale.Components(locale: .current)
            components.hourCycle = .oneToTwelve
            style.locale = Locale(components: components)
            style = style.hour(.defaultDigits(amPM: .abbreviated)).minute(.twoDigits)
        }
        return instant.formatted(style)
    }

    /// `"in 2 h 08 m"` / `"in 42 m"` / `"now"` — in-app only; widgets never
    /// show relative times.
    static func countdown(to target: Date, from now: Date) -> String {
        let minutes = Int((target.timeIntervalSince(now) / 60).rounded(.down))
        guard minutes > 0 else { return "now" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return hours > 0
            ? String(format: "in %d h %02d m", hours, remainder)
            : "in \(remainder) m"
    }

    /// `"15 h 08"` — day length.
    static func dayLength(_ interval: TimeInterval) -> String {
        let minutes = Int((interval / 60).rounded())
        return String(format: "%d h %02d", minutes / 60, minutes % 60)
    }

    // MARK: Dates

    /// `"Thursday 17 July"` (Meta, app header).
    static func fullDate(_ day: CalendarDay) -> String {
        noon(day).formatted(dateStyle().weekday(.wide).day().month(.wide))
    }

    /// `"Thu 17 July"` (systemLarge header).
    static func mediumDate(_ day: CalendarDay) -> String {
        noon(day).formatted(dateStyle().weekday(.abbreviated).day().month(.wide))
    }

    /// `"Thu 24"` (Fortnight rows).
    static func shortDate(_ day: CalendarDay) -> String {
        noon(day).formatted(dateStyle().weekday(.abbreviated).day())
    }

    private static func dateStyle() -> Date.FormatStyle {
        Date.FormatStyle(timeZone: TideTime.timeZone)
    }

    private static func noon(_ day: CalendarDay) -> Date {
        TideTime.date(day, hour: 12, minute: 0)
    }
}
