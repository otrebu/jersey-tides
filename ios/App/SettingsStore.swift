import Foundation
import SwiftUI

/// UserDefaults-backed app options (design doc §7 — app process only; no App
/// Group exists, so anything a widget honors is an AppIntent parameter
/// instead).
///
/// // CHUNK C FILLS THIS — keys + defaults are pinned; persistence and the
/// `WidgetCenter.shared.reloadAllTimelines()` side effect on change are C's.
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
    @Published var units: HeightUnit = .metres
    /// Follow system / 24-hour / 12-hour. Default follow system.
    @Published var timeFormat: TimeFormatOption = .system
    /// Sun ticks + SUN row in the app (widgets always show sun). Default on.
    @Published var sunEvents: Bool = true
    /// Marked height in metres; nil = Off. Stepper 0.5–12.0, 0.1 steps.
    @Published var markedHeight: Double?
    /// Optional name for the marked height ("Causeway").
    @Published var markedLabel: String = ""

    // CHUNK C FILLS THIS: load from / persist to UserDefaults.standard under
    // Keys, and reload widget timelines on every change.
}
