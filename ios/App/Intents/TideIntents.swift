import AppIntents
import Foundation
import SwiftUI

/// Siri surface (design doc: spoken + glanceable, never stale-feeling).
/// All three intents run in the app process on the pure engine — offline,
/// instant — so Siri answers inline (`openAppWhenRun` stays false) with a
/// dialog plus a token-styled snippet. Phrases live in
/// `JerseyTidesShortcuts`; every one must embed `\(.applicationName)`.

/// Snapshot of the app-side settings an intent can honor (units + time
/// format). Intents run in the app process, so `.standard` is the same
/// store `SettingsStore` writes — no App Group needed.
struct IntentSettings {
    let units: HeightUnit
    let timeFormat: TimeFormatOption

    @MainActor
    static func load(defaults: UserDefaults = .standard) -> IntentSettings {
        IntentSettings(
            units: defaults.string(forKey: SettingsStore.Keys.units)
                .flatMap(HeightUnit.init(rawValue:)) ?? .metres,
            timeFormat: defaults.string(forKey: SettingsStore.Keys.timeFormat)
                .flatMap(TimeFormatOption.init(rawValue:)) ?? .system
        )
    }
}

/// Speech-only formatting — the display voice (`TideFormatters.countdown`)
/// abbreviates ("in 2 h 08 m"), which Siri would read out badly.
enum TideSpeech {
    /// "in 3 hours 26 minutes" / "in 1 hour" / "in 42 minutes" /
    /// "right about now".
    static func countdown(to target: Date, from now: Date) -> String {
        let minutes = Int((target.timeIntervalSince(now) / 60).rounded(.down))
        guard minutes > 0 else { return "right about now" }
        func count(_ n: Int, _ word: String) -> String {
            "\(n) \(word)\(n == 1 ? "" : "s")"
        }
        let hours = minutes / 60
        let remainder = minutes % 60
        switch (hours, remainder) {
        case (0, _): return "in \(count(remainder, "minute"))"
        case (_, 0): return "in \(count(hours, "hour"))"
        default: return "in \(count(hours, "hour")) \(count(remainder, "minute"))"
        }
    }
}

/// Spoken when the engine yields nothing in the search window — should be
/// unreachable (harmonic engine always has extremes within 48 h), but Siri
/// needs words, not a crash.
struct TideUnavailableError: Error, CustomLocalizedStringResourceConvertible {
    var localizedStringResource: LocalizedStringResource {
        "Tide predictions aren't available right now. Open Jersey Tides to check."
    }
}

/// First extreme of `kind` (or any, when nil) after `now` — 48 h window
/// always contains at least three extremes at St Helier.
private func nextExtreme(ofKind kind: TideKind?, after now: Date) throws -> TideExtreme {
    let extremes = EngineProvider.engine.extremes(from: now, to: now.addingTimeInterval(48 * 3600))
    guard let match = extremes.first(where: { kind == nil || $0.kind == kind }) else {
        throw TideUnavailableError()
    }
    return match
}

struct NextHighTideIntent: AppIntent {
    static var title: LocalizedStringResource { "Next High Tide" }
    static var description: IntentDescription {
        IntentDescription("The time and height of the next high water at St Helier.")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let now = EngineProvider.clock.now
        let settings = IntentSettings.load()
        let extreme = try nextExtreme(ofKind: .high, after: now)
        let station = EngineProvider.engine.stationName
        let time = TideFormatters.time(extreme.time, format: settings.timeFormat)
        let dialog = IntentDialog(
            full: "Next high water at \(station) is at \(time), \(WidgetVoice.spokenHeight(extreme.height, unit: settings.units)) — \(TideSpeech.countdown(to: extreme.time, from: now)).",
            supporting: "Next high water at \(station)."
        )
        return .result(
            dialog: dialog,
            view: TideExtremeSnippetView(
                stationName: station, extreme: extreme, now: now,
                units: settings.units, timeFormat: settings.timeFormat
            )
        )
    }
}

struct NextLowTideIntent: AppIntent {
    static var title: LocalizedStringResource { "Next Low Tide" }
    static var description: IntentDescription {
        IntentDescription("The time and height of the next low water at St Helier.")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let now = EngineProvider.clock.now
        let settings = IntentSettings.load()
        let extreme = try nextExtreme(ofKind: .low, after: now)
        let station = EngineProvider.engine.stationName
        let time = TideFormatters.time(extreme.time, format: settings.timeFormat)
        let dialog = IntentDialog(
            full: "Next low water at \(station) is at \(time), \(WidgetVoice.spokenHeight(extreme.height, unit: settings.units)) — \(TideSpeech.countdown(to: extreme.time, from: now)).",
            supporting: "Next low water at \(station)."
        )
        return .result(
            dialog: dialog,
            view: TideExtremeSnippetView(
                stationName: station, extreme: extreme, now: now,
                units: settings.units, timeFormat: settings.timeFormat
            )
        )
    }
}

struct CurrentTideIntent: AppIntent {
    static var title: LocalizedStringResource { "Tide Now" }
    static var description: IntentDescription {
        IntentDescription("The sea level at St Helier right now, and where it's heading.")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let now = EngineProvider.clock.now
        let settings = IntentSettings.load()
        let engine = EngineProvider.engine
        let level = engine.levelAt(now)
        let next = try nextExtreme(ofKind: nil, after: now)
        // Trend from extreme alternation, not `slopeAt` — the slope's sign is
        // noisy within a minute of the turn and must never contradict the
        // "high water at …" clause that follows.
        let rising = next.isHigh
        let station = engine.stationName
        let time = TideFormatters.time(next.time, format: settings.timeFormat)
        let dialog = IntentDialog(
            full: "The tide at \(station) is \(WidgetVoice.spokenHeight(level, unit: settings.units)) and \(rising ? "rising" : "falling") — \(rising ? "high" : "low") water at \(time) will \(rising ? "reach" : "fall to") \(WidgetVoice.spokenHeight(next.height, unit: settings.units)).",
            supporting: "Tide now at \(station)."
        )
        return .result(
            dialog: dialog,
            view: TideNowSnippetView(
                stationName: station, level: level, rising: rising, next: next,
                units: settings.units, timeFormat: settings.timeFormat
            )
        )
    }
}
