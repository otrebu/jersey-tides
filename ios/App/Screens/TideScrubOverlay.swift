import SwiftUI

/// Press-and-drag scrubbing on the day curve: hold a beat, then slide to read
/// the tide at any instant of the day. The long-press gate (0.15 s) keeps a
/// plain horizontal swipe paging days; once scrubbing, the drag owns the
/// gesture. Recomputes the same `CurveLayout` as `TideCurveView`, so the
/// scrub line, dot, and readout can never disagree with the drawn curve.
struct TideScrubOverlay: View {
    let model: TideDayModel
    let style: CurveStyle
    let units: HeightUnit
    let timeFormat: TimeFormatOption

    @State private var scrubInstant: Date?

    var body: some View {
        GeometryReader { proxy in
            let layout = CurveLayout(
                samples: model.samples,
                extremes: model.extremes,
                bounds: model.bounds,
                size: proxy.size,
                insets: style.insets
            )
            ZStack(alignment: .topLeading) {
                Color.clear
                if let instant = scrubInstant {
                    let height = EngineProvider.engine.levelAt(instant)
                    let x = layout.x(instant)

                    Rectangle()
                        .fill(Color.sea.opacity(0.55))
                        .frame(width: 0.75, height: layout.plotHeight)
                        .position(x: x, y: layout.plotTop + layout.plotHeight / 2)

                    Circle()
                        .fill(Color.sea)
                        .frame(width: 7, height: 7)
                        .position(x: x, y: layout.y(height))

                    readout(instant: instant, height: height)
                        .position(x: min(max(x, 56), proxy.size.width - 56), y: 12)
                }
            }
            .contentShape(Rectangle())
            .gesture(scrubGesture(layout: layout, width: proxy.size.width))
            .animation(.easeOut(duration: 0.12), value: scrubInstant == nil)
        }
        .accessibilityHidden(true) // the curve's AXChart already covers non-visual reading
    }

    /// `14:32 · 8.4 m` — chart voice, knocked out on a sky capsule.
    private func readout(instant: Date, height: Double) -> some View {
        HStack(spacing: 5) {
            Text(TideFormatters.time(instant, format: timeFormat))
                .font(.caption2.weight(.semibold))
                .monospaced()
                .foregroundStyle(Color.sea)
            Text(TideFormatters.height(height, unit: units))
                .font(.caption2)
                .monospaced()
                .foregroundStyle(Color.seaSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.sky))
        .overlay(Capsule().strokeBorder(Color.hairline, lineWidth: 0.5))
        .fixedSize()
    }

    private func scrubGesture(layout: CurveLayout, width: CGFloat) -> some Gesture {
        LongPressGesture(minimumDuration: 0.15)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
            .onChanged { value in
                guard case .second(true, let drag) = value else { return }
                let x = min(max(drag?.location.x ?? 0, 0), width)
                let fraction = width > 0 ? x / width : 0
                scrubInstant = model.bounds.start.addingTimeInterval(
                    Double(fraction) * model.bounds.duration
                )
            }
            .onEnded { _ in
                scrubInstant = nil
            }
    }
}
