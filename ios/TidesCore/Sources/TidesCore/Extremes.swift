import Foundation

/// High/low water location: 20-minute slope-sign scan plus bisection.
///
/// Port of `extremes()` from `packages/core/src/engine.ts`.

/// Whether a tidal extreme is a high or a low water.
public enum TideExtremeType: String, Sendable {
    case high
    case low
}

/// A located tidal extreme (raw engine level, no datum).
public struct Extreme: Sendable {
    public let time: Date
    public let level: Double
    public let type: TideExtremeType
}

extension Predictor {
    /// All high/low extremes in `[start, end)`, chronological.
    public func extremes(from start: Date, to end: Date) -> [Extreme] {
        extremes(startMs: start.msSinceEpoch, endMs: end.msSinceEpoch)
    }

    func extremes(startMs: Double, endMs: Double) -> [Extreme] {
        var out: [Extreme] = []
        let stepMs = 20.0 * 60_000
        var tPrev = startMs
        var sPrev = slopeAt(ms: tPrev)
        // The scan deliberately runs one step past `end` so an extreme just
        // before the boundary is still bracketed.
        var t = startMs + stepMs
        while t <= endMs + stepMs {
            let sCur = slopeAt(ms: t)
            if sPrev == 0 || sPrev * sCur < 0 {
                // Bracketed a stationary point: bisect the slope sign change.
                var lo = tPrev
                var hi = t
                var sLo = sPrev
                var iteration = 0
                while iteration < 40, hi - lo > 500 {
                    let mid = 0.5 * (lo + hi)
                    let sMid = slopeAt(ms: mid)
                    if sLo * sMid <= 0 {
                        hi = mid
                    } else {
                        lo = mid
                        sLo = sMid
                    }
                    iteration += 1
                }
                // JS constructs a Date here, truncating fractional ms.
                let tExt = (0.5 * (lo + hi)).rounded(.towardZero)
                if tExt >= startMs, tExt < endMs {
                    // Classify by second-derivative sign (finite difference of slope).
                    let h = 10.0 * 60_000
                    let curv = slopeAt(ms: tExt + h) - slopeAt(ms: tExt - h)
                    let type: TideExtremeType = curv < 0 ? .high : .low
                    out.append(Extreme(time: Date(msSinceEpoch: tExt), level: levelAt(ms: tExt), type: type))
                }
            }
            tPrev = t
            sPrev = sCur
            t += stepMs
        }
        return out
    }
}
