import SwiftUI

/// Decorative wave band behind the "Now · water level" hero (mockup `.hero-wave`).
/// Two engraved `sea`-tinted swells plus a crest line, drifting slowly to signal
/// tide direction. Quiet by design — no motion when `accessibilityReduceMotion`
/// is on, cheap `TimelineView(.animation)` + `Canvas` when it isn't (no timers).
///
/// Additive to the shared layer: draws only with the `sea` token, so widget and
/// Live Activity rendering is untouched.
struct WaveBand: View {
    /// Tide trend: `true` when the next extreme is a high water (flooding).
    /// Rising swells drift right with a touch more amplitude; falling swells drift
    /// left and sit calmer — a subtle directional cue, not a gaudy animation.
    let rising: Bool
    /// Whether the host page is the selected pager page. `false` pauses the
    /// per-frame `TimelineView` for the today page swiped off-screen, so the
    /// wave doesn't redraw every frame while it's not visible.
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(rising: Bool, isActive: Bool = true) {
        self.rising = rising
        self.isActive = isActive
    }

    /// One swell layer, sizes as fractions of the band height (mockup viewBox
    /// is 393×120; base 90/84, amp 6/8 → the fractions below).
    private struct Swell {
        let baseFraction: CGFloat   // resting Y as a fraction of height
        let ampFraction: CGFloat    // peak deflection as a fraction of height
        let waves: CGFloat          // half-cycles across the band width
        let duration: Double        // seconds to drift one band width
    }

    // Back swell, then front swell (the front one also carries the crest line).
    private static let back  = Swell(baseFraction: 0.75, ampFraction: 0.050, waves: 4, duration: 9.5)
    private static let front = Swell(baseFraction: 0.70, ampFraction: 0.067, waves: 3, duration: 13)

    var body: some View {
        Group {
            if reduceMotion {
                Canvas { context, size in
                    draw(&context, size: size, seconds: 0)
                }
            } else {
                TimelineView(.animation(minimumInterval: nil, paused: !isActive)) { timeline in
                    Canvas { context, size in
                        draw(&context, size: size, seconds: timeline.date.timeIntervalSinceReferenceDate)
                    }
                }
            }
        }
        // Purely decorative — never intercepts scrubbing on the hero.
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: Rendering

    private func draw(_ context: inout GraphicsContext, size: CGSize, seconds: Double) {
        // Rising floods toward you (drift right); falling ebbs away (drift left),
        // and sits ~15 % calmer.
        let drift: CGFloat = rising ? -1 : 1
        let ampScale: CGFloat = rising ? 1.0 : 0.85

        context.fill(fill(Self.back,  size: size, seconds: seconds, drift: drift, ampScale: ampScale),
                     with: .color(.sea.opacity(0.06)))
        context.fill(fill(Self.front, size: size, seconds: seconds, drift: drift, ampScale: ampScale),
                     with: .color(.sea.opacity(0.06)))
        context.stroke(crest(Self.front, size: size, seconds: seconds, drift: drift, ampScale: ampScale),
                       with: .color(.sea.opacity(0.16)),
                       style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
    }

    /// Filled swell body, closed down to the bottom edge like a water level.
    private func fill(_ swell: Swell, size: CGSize, seconds: Double,
                      drift: CGFloat, ampScale: CGFloat) -> Path {
        var path = crest(swell, size: size, seconds: seconds, drift: drift, ampScale: ampScale)
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.addLine(to: CGPoint(x: 0, y: size.height))
        path.closeSubpath()
        return path
    }

    /// The swell's surface polyline — a sampled sine drifting horizontally.
    private func crest(_ swell: Swell, size: CGSize, seconds: Double,
                       drift: CGFloat, ampScale: CGFloat) -> Path {
        let width = size.width
        let base = swell.baseFraction * size.height
        let amp = swell.ampFraction * size.height * ampScale
        // Continuous phase (px), wrapped by the sine itself — no seam, no jump.
        let phase = drift * CGFloat(seconds / swell.duration) * width

        let steps = 80
        var path = Path()
        for i in 0...steps {
            let x = CGFloat(i) / CGFloat(steps) * width
            let angle = ((x + phase) / width) * swell.waves * .pi
            let y = base + sin(angle) * amp
            let point = CGPoint(x: x, y: y)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }
}

#Preview("Wave band — rising vs falling") {
    VStack(spacing: 24) {
        ZStack(alignment: .leading) {
            WaveBand(rising: true)
            Text("Rising").font(.caption).foregroundStyle(.seaSecondary).padding(.leading, 16)
        }
        .frame(height: 120)

        ZStack(alignment: .leading) {
            WaveBand(rising: false)
            Text("Falling").font(.caption).foregroundStyle(.seaSecondary).padding(.leading, 16)
        }
        .frame(height: 120)
    }
    .padding()
    .background(Color.sky)
}
