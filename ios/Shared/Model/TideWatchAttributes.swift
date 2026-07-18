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

    /// An extreme on the day-curve snapshot, in normalized plot coordinates.
    struct CurveMark: Codable, Hashable {
        /// 0…1 across the local day.
        var fraction: Double
        /// 0…1 within the curve's height band.
        var level: Double
        var isHigh: Bool
    }

    /// Station eyebrow, fixed for the activity's lifetime.
    var stationName: String

    /// Day-curve snapshot for the expanded island: heights normalized 0…1
    /// across the local day (49 points ≈ 30-min steps; a few hundred bytes,
    /// well under the ActivityKit payload budget). Static per activity — the
    /// controller restarts the activity rather than updating it across a day
    /// boundary, so the snapshot never goes stale.
    var curveHeights: [Double]
    var curveMarks: [CurveMark]
}
