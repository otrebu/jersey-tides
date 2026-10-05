import Foundation

/// Spoken fragments composed from data — "High water 14:32, 11.2 metres.
/// Tide rising, 8.4 metres." Shared by every widget family and the watch
/// face (design doc §6).
enum WidgetVoice {
    static func arrowSymbol(rising: Bool) -> String {
        rising ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill"
    }

    static func spokenHeight(_ metres: Double, unit: HeightUnit) -> String {
        "\(TideFormatters.heightValue(metres, unit: unit)) \(unit == .feet ? "feet" : "metres")"
    }

    static func spokenExtreme(_ extreme: TideExtreme, unit: HeightUnit) -> String {
        "\(extreme.isHigh ? "High water" : "Low water") \(TideFormatters.time(extreme.time)), "
            + "\(spokenHeight(extreme.height, unit: unit))."
    }

    static func spokenTrend(_ height: Double, rising: Bool, unit: HeightUnit) -> String {
        "Tide \(rising ? "rising" : "falling"), \(spokenHeight(height, unit: unit))."
    }

    /// Next extreme + current trend — the §6 default widget label.
    static func summary(_ model: TideDayModel, units: HeightUnit) -> String {
        var parts: [String] = []
        if let next = model.nextExtreme {
            parts.append(spokenExtreme(next, unit: units))
        }
        if let height = model.currentHeight, let rising = model.isRising {
            parts.append(spokenTrend(height, rising: rising, unit: units))
        }
        return parts.isEmpty ? "Tide data unavailable" : parts.joined(separator: " ")
    }
}
