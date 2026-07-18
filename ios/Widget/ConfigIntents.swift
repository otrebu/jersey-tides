import AppIntents
import Foundation

/// Per-widget options as AppIntent parameters (design doc §7 #5–#8 — no App
/// Group exists, so widget options can never come from UserDefaults).

extension HeightUnit: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Units" }
    static var caseDisplayRepresentations: [HeightUnit: DisplayRepresentation] {
        [.metres: "Metres", .feet: "Feet"]
    }
}

extension DialEmphasis: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Emphasis" }
    static var caseDisplayRepresentations: [DialEmphasis: DisplayRepresentation] {
        [.nextTide: "Next tide", .now: "Now"]
    }
}

extension RectStyle: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Style" }
    static var caseDisplayRepresentations: [RectStyle: DisplayRepresentation] {
        [.text: "Text", .curve: "Curve"]
    }
}

/// Dial (systemSmall): Emphasis + Units.
struct DialConfigIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Dial" }
    static var description: IntentDescription { IntentDescription("Next-tide dial options.") }

    @Parameter(title: "Emphasis", default: .nextTide)
    var emphasis: DialEmphasis

    @Parameter(title: "Units", default: .metres)
    var units: HeightUnit

    var widgetConfig: TideWidgetConfig {
        var config = TideWidgetConfig.default
        config.emphasis = emphasis
        config.units = units
        return config
    }
}

/// Chart (systemMedium/Large): Units + Marked height (+ optional label).
struct ChartConfigIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Chart" }
    static var description: IntentDescription { IntentDescription("Tide chart options.") }

    @Parameter(title: "Units", default: .metres)
    var units: HeightUnit

    /// Metres, 0.5–12.0; nil = Off.
    @Parameter(title: "Marked height (m)", inclusiveRange: (0.5, 12.0))
    var markedHeight: Double?

    @Parameter(title: "Marked height name")
    var markedLabel: String?

    var widgetConfig: TideWidgetConfig {
        var config = TideWidgetConfig.default
        config.units = units
        // Clamp defensively — the intent range should already enforce this.
        config.markedHeight = markedHeight.map { min(max($0, 0.5), 12.0) }
        config.markedLabel = markedLabel
        return config
    }
}

/// Rectangular accessory: Style.
struct RectConfigIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Rectangular" }
    static var description: IntentDescription { IntentDescription("Rectangular tide options.") }

    @Parameter(title: "Style", default: .curve)
    var style: RectStyle

    var widgetConfig: TideWidgetConfig {
        var config = TideWidgetConfig.default
        config.rectStyle = style
        return config
    }
}
