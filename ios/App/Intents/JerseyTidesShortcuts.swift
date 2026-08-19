import AppIntents

/// The app's Siri/Shortcuts vocabulary. Platform rules (WWDC22 10169/10170):
/// every phrase must embed `\(.applicationName)`; at most 10 App Shortcuts and
/// 1,000 phrases per locale. Siri's flexible matching is unreliable across
/// singular/plural and word order in practice ("Jersey tides" matched while
/// "Jersey tide" and "tide in Jersey" missed), so each shape is spelled out
/// in both numbers and the common orders. `INAlternativeAppNames` in
/// project.yml adds "Jersey" + "Jersey Tide", so "\(.applicationName)"
/// resolves from "…in Jersey" / "…in Jersey Tide" as well as the full name.
/// Exactly one `AppShortcutsProvider` may exist per app — it lives in the app
/// target only.
struct JerseyTidesShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NextHighTideIntent(),
            phrases: [
                "When is the next high tide in \(.applicationName)",
                "When's the next high tide in \(.applicationName)",
                "What's the next high tide in \(.applicationName)",
                "Next high tide in \(.applicationName)",
                "\(.applicationName) next high tide",
                "\(.applicationName) high tide",
                "High tide in \(.applicationName)",
                "When is high tide in \(.applicationName)",
                "When's high tide in \(.applicationName)",
                "When is high water in \(.applicationName)",
                "What time is high tide in \(.applicationName)",
                "What time is the high tide in \(.applicationName)",
            ],
            shortTitle: "Next High Tide",
            systemImageName: "arrowtriangle.up.fill"
        )
        AppShortcut(
            intent: NextLowTideIntent(),
            phrases: [
                "When is the next low tide in \(.applicationName)",
                "When's the next low tide in \(.applicationName)",
                "What's the next low tide in \(.applicationName)",
                "Next low tide in \(.applicationName)",
                "\(.applicationName) next low tide",
                "\(.applicationName) low tide",
                "Low tide in \(.applicationName)",
                "When is low tide in \(.applicationName)",
                "When's low tide in \(.applicationName)",
                "When is low water in \(.applicationName)",
                "What time is low tide in \(.applicationName)",
                "What time is the low tide in \(.applicationName)",
            ],
            shortTitle: "Next Low Tide",
            systemImageName: "arrowtriangle.down.fill"
        )
        AppShortcut(
            intent: CurrentTideIntent(),
            phrases: [
                "What's the tide in \(.applicationName)",
                "What's the tide now in \(.applicationName)",
                "What are the tides in \(.applicationName)",
                "Current tide in \(.applicationName)",
                "How's the tide in \(.applicationName)",
                "Is the tide rising in \(.applicationName)",
                "What's the sea level in \(.applicationName)",
                "Tide in \(.applicationName)",
                "Tides in \(.applicationName)",
                "\(.applicationName) tide",
                "\(.applicationName) tides",
                "Show me the tide in \(.applicationName)",
                "Show me the tides in \(.applicationName)",
                "Tell me the tide in \(.applicationName)",
                "Tell me the tides in \(.applicationName)",
                "What's the tide like in \(.applicationName)",
                "Tide times in \(.applicationName)",
                "Tide times for \(.applicationName)",
                "Tide report for \(.applicationName)",
            ],
            shortTitle: "Tide Now",
            systemImageName: "water.waves"
        )
    }

    /// Shortcuts-app tile tint — closest system color to `sea`.
    static var shortcutTileColor: ShortcutTileColor { .navy }
}
