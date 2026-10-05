import SwiftUI

/// Companion watch app. Predictions stay on-device (`TidesCore` via the
/// `TideEngine` facade) — no phone, no App Group, no network. Metres and
/// system time; the iPhone settings store does not sync here.
@main
struct JerseyTidesWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchPager()
        }
    }
}
