import AppIntents

/// The app's Siri/Shortcuts vocabulary. Platform rules (WWDC22 10169/10170):
/// every phrase must embed `\(.applicationName)`; at most 10 App Shortcuts and
/// 1,000 phrases per locale; Siri's flexible matching covers minor variants,
/// so keep synonym sets short. `INAlternativeAppNames` in project.yml adds
/// "Jersey" so "What's the tide in Jersey" resolves to this app. Exactly one
/// `AppShortcutsProvider` may exist per app — it lives in the app target only.
struct JerseyTidesShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NextHighTideIntent(),
            phrases: [
                "When is the next high tide in \(.applicationName)",
                "What's the next high tide in \(.applicationName)",
                "Next high tide in \(.applicationName)",
                "When is high water in \(.applicationName)",
                "What time is high tide in \(.applicationName)",
            ],
            shortTitle: "Next High Tide",
            systemImageName: "arrowtriangle.up.fill"
        )
        AppShortcut(
            intent: NextLowTideIntent(),
            phrases: [
                "When is the next low tide in \(.applicationName)",
                "What's the next low tide in \(.applicationName)",
                "Next low tide in \(.applicationName)",
                "When is low water in \(.applicationName)",
                "What time is low tide in \(.applicationName)",
            ],
            shortTitle: "Next Low Tide",
            systemImageName: "arrowtriangle.down.fill"
        )
        AppShortcut(
            intent: CurrentTideIntent(),
            phrases: [
                "What's the tide in \(.applicationName)",
                "What's the tide now in \(.applicationName)",
                "Current tide in \(.applicationName)",
                "How's the tide in \(.applicationName)",
                "Is the tide rising in \(.applicationName)",
                "What's the sea level in \(.applicationName)",
            ],
            shortTitle: "Tide Now",
            systemImageName: "water.waves"
        )
    }

    /// Shortcuts-app tile tint — closest system color to `sea`.
    static var shortcutTileColor: ShortcutTileColor { .navy }
}
