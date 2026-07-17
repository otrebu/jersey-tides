import Foundation
import WidgetKit

/// Metres / feet — display-side conversion only (design doc §7 #1/#7).
enum HeightUnit: String, Codable, CaseIterable, Sendable {
    case metres
    case feet
}

/// Dial (systemSmall) hero choice (design doc §7 #5).
enum DialEmphasis: String, Codable, CaseIterable, Sendable {
    case nextTide
    case now
}

/// Rectangular accessory style (design doc §7 #6).
enum RectStyle: String, Codable, CaseIterable, Sendable {
    case text
    case curve
}

/// Per-widget knobs, resolved from the AppIntent configuration
/// (`Widget/ConfigIntents.swift`). Every entry carries the full set; each
/// family reads only what it honors.
struct TideWidgetConfig: Equatable, Sendable {
    var units: HeightUnit = .metres
    var emphasis: DialEmphasis = .nextTide
    var rectStyle: RectStyle = .text
    /// Metres, 0.5–12.0; nil = Off.
    var markedHeight: Double?
    var markedLabel: String?

    static let `default` = TideWidgetConfig()
}

/// One widget timeline entry. `dayModel == nil` → render the §10 error tile.
struct TideEntry: TimelineEntry, Sendable {
    /// When WidgetKit switches to this entry.
    let date: Date
    /// The instant levels/now-dot are computed at (entry-window midpoint, §9).
    let displayInstant: Date
    let dayModel: TideDayModel?
    let config: TideWidgetConfig

    /// Builds a fully-populated entry for the day containing `displayInstant`.
    static func make(
        at date: Date,
        displayInstant: Date? = nil,
        engine: any TideEngine = EngineProvider.engine,
        config: TideWidgetConfig = .default
    ) -> TideEntry {
        let instant = displayInstant ?? date
        let model = TideDayModel.make(
            day: TideTime.calendarDay(of: instant),
            engine: engine,
            now: instant,
            markedHeight: config.markedHeight,
            markedLabel: config.markedLabel
        )
        return TideEntry(date: date, displayInstant: instant, dayModel: model, config: config)
    }

    /// The §10 error-tile entry (timeline policy `+15 min` is chunk D's).
    static func error(at date: Date, config: TideWidgetConfig = .default) -> TideEntry {
        TideEntry(date: date, displayInstant: date, dayModel: nil, config: config)
    }
}

extension CalendarDay {
    /// Widget tap target: `jerseytides://day/2026-07-17`
    /// (parsed app-side by `App/DeepLink.swift`).
    var deepLinkURL: URL {
        URL(string: String(format: "jerseytides://day/%04d-%02d-%02d", year, month, day))!
    }
}
