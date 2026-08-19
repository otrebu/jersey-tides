import SwiftUI
import WidgetKit

/// Sparkline variants (design doc §4.4): tomorrow ghost (systemLarge) and the
/// rolling `now−1h…now+5h` window (accessoryRectangular Curve style).
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

    @Environment(\.widgetRenderingMode) private var renderingMode

    init(samples: [TimelinePoint], bounds: DayBounds, variant: Variant = .ghost) {
        self.samples = samples
        self.bounds = bounds
        self.variant = variant
    }

    var body: some View {
        GeometryReader { proxy in
            // Own Y domain from this window's samples; §4.2 insets:
            // ghost 2/2, rect-curve 4/2.
            let layout = CurveLayout(
                samples: samples,
                extremes: [],
                bounds: bounds,
                size: proxy.size,
                insets: variant == .ghost ? .init(top: 2, bottom: 2) : .init(top: 4, bottom: 2)
            )
            Canvas { context, _ in
                switch variant {
                case .ghost:
                    drawGhost(&context, layout: layout)
                case .rolling(let now):
                    drawRolling(&context, layout: layout, now: now)
                }
            }
        }
    }

    // MARK: Ghost (systemLarge tomorrow preview — base group, §2.1)

    /// 1 pt `ghost` stroke only — no fill, markers, labels, now, or horizon.
    private func drawGhost(_ context: inout GraphicsContext, layout: CurveLayout) {
        guard let path = polyline(layout: layout) else { return }
        let color: Color = renderingMode == .accented ? .primary.opacity(0.40) : .ghost
        context.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round)
        )
    }

    // MARK: Rolling (accessoryRectangular Curve style — vibrant surface)

    /// 2 pt stroke, fill white 15 % (vibrant), HW filled dot / LW ring per the
    /// print legend when inside the window, punch-out now-dot r 2.5.
    private func drawRolling(_ context: inout GraphicsContext, layout: CurveLayout, now: Date) {
        guard let path = polyline(layout: layout),
              let first = samples.first, let last = samples.last else { return }

        var fill = path
        fill.addLine(to: CGPoint(x: layout.x(last.time), y: layout.plotBottom))
        fill.addLine(to: CGPoint(x: layout.x(first.time), y: layout.plotBottom))
        fill.closeSubpath()
        context.fill(fill, with: .color(.white.opacity(0.15)))

        context.stroke(
            path,
            with: .color(.white),
            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
        )

        // Markers at the window's interior turning points (rect legend sizes:
        // HW r 2.5 filled, LW r 3 ring @ 1.25 pt — §4.3.5).
        for (index, sample) in samples.enumerated() where index > 0 && index < samples.count - 1 {
            let previous = samples[index - 1].height
            let next = samples[index + 1].height
            let isHigh = sample.height > previous && sample.height >= next
            let isLow = sample.height < previous && sample.height <= next
            guard isHigh || isLow else { continue }
            let center = CGPoint(x: layout.x(sample.time), y: layout.y(sample.height))
            if isHigh {
                context.fill(
                    Path(ellipseIn: CGRect(x: center.x - 2.5, y: center.y - 2.5, width: 5, height: 5)),
                    with: .color(.white)
                )
            } else {
                context.stroke(
                    Path(ellipseIn: CGRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6)),
                    with: .color(.white),
                    lineWidth: 1.25
                )
            }
        }

        // Punch-out now-dot r 2.5 (+2 pt destinationOut halo, §4.1).
        guard let height = interpolatedHeight(at: now) else { return }
        let center = CGPoint(
            x: min(max(layout.x(now), 1), layout.size.width - 1),
            y: layout.y(height)
        )
        var punch = context
        punch.blendMode = .destinationOut
        punch.fill(
            Path(ellipseIn: CGRect(x: center.x - 4.5, y: center.y - 4.5, width: 9, height: 9)),
            with: .color(.black)
        )
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - 2.5, y: center.y - 2.5, width: 5, height: 5)),
            with: .color(.white)
        )
    }

    // MARK: Helpers

    private func polyline(layout: CurveLayout) -> Path? {
        guard samples.count > 1 else { return nil }
        let points = samples.map { CGPoint(x: layout.x($0.time), y: layout.y($0.height)) }
        var path = Path()
        path.move(to: points[0])
        path.addLines(points)
        return path
    }

    /// Linear interpolation between the samples bracketing `instant`.
    private func interpolatedHeight(at instant: Date) -> Double? {
        guard let first = samples.first, let last = samples.last else { return nil }
        guard instant > first.time else { return first.height }
        guard instant < last.time else { return last.height }
        for index in 1..<samples.count {
            let a = samples[index - 1]
            let b = samples[index]
            if instant <= b.time {
                let span = b.time.timeIntervalSince(a.time)
                guard span > 0 else { return a.height }
                let fraction = instant.timeIntervalSince(a.time) / span
                return a.height + (b.height - a.height) * fraction
            }
        }
        return last.height
    }
}
