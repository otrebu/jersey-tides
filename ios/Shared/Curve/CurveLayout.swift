import CoreGraphics
import Foundation

/// Pure curve geometry (design doc §4.2): `x(t)` linear in UTC across the
/// day's bounds (DST-exact by construction), y-domain from samples ∪ exact
/// extreme heights padded `max(range, 1) × 0.07`, label clamps. Computed once
/// and passed to BOTH Canvases so they can never disagree on positions.
struct CurveLayout: Equatable, Sendable {
    /// Plot band insets (top/bottom pt): app 24/24 · medium 20/20 ·
    /// large 22/20 · rect-curve 4/2 · ghost 2/2.
    struct Insets: Equatable, Sendable {
        let top: CGFloat
        let bottom: CGFloat

        init(top: CGFloat, bottom: CGFloat) {
            self.top = top
            self.bottom = bottom
        }
    }

    let bounds: DayBounds
    let size: CGSize
    let insets: Insets
    /// Padded height domain (samples ∪ exact extreme heights, +7 % padding).
    let yDomain: ClosedRange<Double>

    init(
        samples: [TimelinePoint],
        extremes: [TideExtreme],
        bounds: DayBounds,
        size: CGSize,
        insets: Insets
    ) {
        self.bounds = bounds
        self.size = size
        self.insets = insets

        // Domain over samples ∪ exact extreme heights so markers placed at the
        // exact extremes always sit on (never off) the padded band.
        let heights = samples.map(\.height) + extremes.map(\.height)
        if let lo = heights.min(), let hi = heights.max() {
            let padding = max(hi - lo, 1) * 0.07
            self.yDomain = (lo - padding)...(hi + padding)
        } else {
            self.yDomain = 0...1
        }
    }

    // MARK: Plot band

    /// Top edge of the plot band.
    var plotTop: CGFloat { insets.top }

    /// Bottom edge of the plot band.
    var plotBottom: CGFloat { size.height - insets.bottom }

    /// Height of the plot band (never negative).
    var plotHeight: CGFloat { max(plotBottom - plotTop, 0) }

    // MARK: Mapping

    /// Horizontal position of an instant — linear in UTC, 23/25 h days exact.
    func x(_ instant: Date) -> CGFloat {
        guard bounds.duration > 0 else { return 0 }
        let fraction = instant.timeIntervalSince(bounds.start) / bounds.duration
        return CGFloat(fraction) * size.width
    }

    /// Vertical position of a height within the inset plot band (inverted).
    func y(_ height: Double) -> CGFloat {
        let span = yDomain.upperBound - yDomain.lowerBound
        guard span > 0 else { return plotBottom }
        let fraction = (height - yDomain.lowerBound) / span
        return plotTop + (1 - CGFloat(fraction)) * plotHeight
    }

    /// Clamps a label's leading x into `[0, width − labelWidth]`.
    func clampedLabelX(_ desired: CGFloat, labelWidth: CGFloat) -> CGFloat {
        let upper = max(size.width - labelWidth, 0)
        return min(max(desired, 0), upper)
    }
}
