import ActivityKit
import Foundation

/// Live Activity contract for "Tide Watch" — one activity tracks the run from
/// the previous extreme to the next (the flood or the ebb). Everything the
/// island/lock screen shows is either an absolute value or a system-rendered
/// timer over `prevTime...nextTime`, so a stale activity is still true — the
/// same doctrine as widget entries (design doc §9).
struct TideWatchAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// The extreme this watch runs toward.
        var nextTime: Date
        var nextHeight: Double
        var nextIsHigh: Bool
        /// The extreme the run started from — the progress bar's zero.
        var prevTime: Date
        var prevHeight: Double

        var interval: ClosedRange<Date> { prevTime...nextTime }
    }

    /// Station eyebrow, fixed for the activity's lifetime.
    var stationName: String
}
