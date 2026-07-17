import SwiftUI

/// Sparkline variants (design doc §4.4): tomorrow ghost (systemLarge) and the
/// rolling `now−1h…now+5h` window (accessoryRectangular Curve style).
///
/// // CHUNK B FILLS THIS — placeholder body.
struct Sparkline: View {
    enum Variant: Equatable, Sendable {
        /// Tomorrow ghost: 1 pt `ghost` stroke, no fill/markers/labels/now.
        case ghost
        /// Rolling window: 2 pt stroke, HW/LW markers if inside window,
        /// punch-out now-dot r 2.5.
        case rolling(now: Date)
    }

    let samples: [TimelinePoint]
    let bounds: DayBounds
    let variant: Variant

    init(samples: [TimelinePoint], bounds: DayBounds, variant: Variant = .ghost) {
        self.samples = samples
        self.bounds = bounds
        self.variant = variant
    }

    var body: some View {
        // CHUNK B FILLS THIS
        Capsule().fill(Color.ghost).frame(height: 1)
    }
}
