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
        /// The next HIGH water at or beyond `nextTime` — the same extreme when
        /// `nextIsHigh`, otherwise the high beyond the coming low. Absolute
        /// values, so the lock card can promise the next high even mid-ebb
        /// without ever needing an update.
        var nextHighTime: Date
        var nextHighHeight: Double
        /// Display unit for every height on the activity, captured when the
        /// run starts. Like every other value here it holds for the whole
        /// run: the setting can only change while the app is foregrounded,
        /// which is exactly when the controller restarts the activity.
        var unit: HeightUnit

        var interval: ClosedRange<Date> { prevTime...nextTime }

        init(
            nextTime: Date, nextHeight: Double, nextIsHigh: Bool,
            prevTime: Date, prevHeight: Double,
            nextHighTime: Date, nextHighHeight: Double,
            unit: HeightUnit
        ) {
            self.nextTime = nextTime
            self.nextHeight = nextHeight
            self.nextIsHigh = nextIsHigh
            self.prevTime = prevTime
            self.prevHeight = prevHeight
            self.nextHighTime = nextHighTime
            self.nextHighHeight = nextHighHeight
            self.unit = unit
        }

        private enum CodingKeys: String, CodingKey {
            case nextTime, nextHeight, nextIsHigh, prevTime, prevHeight
            case nextHighTime, nextHighHeight, unit
        }

        /// Tolerant decoding for fields added after the first build:
        /// ActivityKit re-decodes a live activity's persisted state when a
        /// new build launches, and a `keyNotFound` would silently orphan the
        /// run — invisible to `adoptExisting()`, unreachable by `stop()`,
        /// still sitting on the lock screen. Later fields fall back to
        /// values an old run rendered anyway; `rollForwardIfNeeded` rebuilds
        /// the full state at the next foreground.
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            nextTime = try container.decode(Date.self, forKey: .nextTime)
            nextHeight = try container.decode(Double.self, forKey: .nextHeight)
            nextIsHigh = try container.decode(Bool.self, forKey: .nextIsHigh)
            prevTime = try container.decode(Date.self, forKey: .prevTime)
            prevHeight = try container.decode(Double.self, forKey: .prevHeight)
            nextHighTime = try container.decodeIfPresent(Date.self, forKey: .nextHighTime) ?? nextTime
            nextHighHeight = try container.decodeIfPresent(Double.self, forKey: .nextHighHeight) ?? nextHeight
            unit = try container.decodeIfPresent(HeightUnit.self, forKey: .unit) ?? .metres
        }
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
