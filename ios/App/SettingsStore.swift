import Foundation
import SwiftUI
import WidgetKit

/// UserDefaults-backed app options (design doc §7 — app process only; no App
/// Group exists, so anything a widget honors is an AppIntent parameter
/// instead).
///
/// Every change persists immediately and reloads all widget timelines
/// (design doc §9: "on every app-settings change").
@MainActor
final class SettingsStore: ObservableObject {
    enum Keys {
        static let units = "units"
        static let timeFormat = "timeFormat"
        static let sunEvents = "sunEvents"
        static let markedHeight = "markedHeight"
        static let markedLabel = "markedLabel"
    }

    /// Metres / Feet (display-side conversion only). Default Metres.
    @Published var units: HeightUnit = .metres {
        didSet { persist { $0.set(units.rawValue, forKey: Keys.units) } }
    }
    /// Follow system / 24-hour / 12-hour. Default follow system.
    @Published var timeFormat: TimeFormatOption = .system {
        didSet { persist { $0.set(timeFormat.rawValue, forKey: Keys.timeFormat) } }
    }
    /// Sun ticks + SUN row in the app (widgets always show sun). Default on.
    @Published var sunEvents: Bool = true {
        didSet { persist { $0.set(sunEvents, forKey: Keys.sunEvents) } }
    }
    /// Marked height in metres; nil = Off. Stepper 0.5–12.0, 0.1 steps.
    @Published var markedHeight: Double? {
        didSet {
            persist {
                if let markedHeight {
                    $0.set(markedHeight, forKey: Keys.markedHeight)
                } else {
                    $0.removeObject(forKey: Keys.markedHeight)
                }
            }
        }
    }
    /// Optional name for the marked height ("Causeway").
    @Published var markedLabel: String = "" {
        didSet { persist { $0.set(markedLabel, forKey: Keys.markedLabel) } }
    }

    private let defaults: UserDefaults
    /// Suppresses persistence while the initial load assigns properties.
    private var isLoading = true

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let raw = defaults.string(forKey: Keys.units),
           let value = HeightUnit(rawValue: raw) {
            units = value
        }
        if let raw = defaults.string(forKey: Keys.timeFormat),
           let value = TimeFormatOption(rawValue: raw) {
            timeFormat = value
        }
        if defaults.object(forKey: Keys.sunEvents) != nil {
            sunEvents = defaults.bool(forKey: Keys.sunEvents)
        }
        markedHeight = defaults.object(forKey: Keys.markedHeight) as? Double
        markedLabel = defaults.string(forKey: Keys.markedLabel) ?? ""
        isLoading = false
    }

    /// `markedLabel` trimmed to nil when empty — what the day model wants.
    var markedLabelOrNil: String? {
        let trimmed = markedLabel.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func persist(_ write: (UserDefaults) -> Void) {
        guard !isLoading else { return }
        write(defaults)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
