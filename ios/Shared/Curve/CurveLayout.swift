import CoreGraphics
import Foundation

/// Pure curve geometry (design doc §4.2): `x(t)` linear in UTC across the
/// day's bounds (DST-exact by construction), y-domain from samples ∪ exact
/// extreme heights padded `max(range, 1) × 0.07`, label clamps. Computed once
/// and passed to BOTH Canvases so they can never disagree on positions.
///
/// // CHUNK B FILLS THIS — placeholder bodies return neutral values.
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
        self.yDomain = 0...1 // CHUNK B FILLS THIS
    }

    /// Horizontal position of an instant — linear in UTC, 23/25 h days exact.
    func x(_ instant: Date) -> CGFloat {
        0 // CHUNK B FILLS THIS
    }

    /// Vertical position of a height within the inset plot band (inverted).
    func y(_ height: Double) -> CGFloat {
        0 // CHUNK B FILLS THIS
    }

    /// Clamps a label's leading x into `[0, width − labelWidth]`.
    func clampedLabelX(_ desired: CGFloat, labelWidth: CGFloat) -> CGFloat {
        0 // CHUNK B FILLS THIS
    }
}
