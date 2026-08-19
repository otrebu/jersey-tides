import SwiftUI
import UIKit

/// Press-and-drag scrubbing on the day curve: hold a beat, then slide to read
/// the tide at any instant of the day. The long-press gate (0.15 s) keeps a
/// plain horizontal swipe paging days; once scrubbing, the drag owns the
/// gesture. Recomputes the same `CurveLayout` as `TideCurveView`, so the
/// scrub line, dot, and readout can never disagree with the drawn curve.
/// Bubbles "a scrub hold owns this touch" up to the day pager, which disables
/// its horizontal scroll for the duration. Without it the SwiftUI pager's pan
/// claims the drag even mid-scrub (the old `TabView` pager's UIKit scroll view
/// delayed touches; the paging `ScrollView` does not).
struct ScrubEngagedPreferenceKey: PreferenceKey {
    static let defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

/// UIKit long-press bridged into SwiftUI (`UIGestureRecognizerRepresentable`).
/// SwiftUI's own `LongPressGesture.sequenced(before: DragGesture)` — attached
/// via `.gesture`, `.highPriorityGesture` OR `.simultaneousGesture` — deadlocks
/// the paging `ScrollView`'s pan on iOS 26: a swipe that starts on the curve
/// neither scrubs nor pages (verified in the simulator; removing the gesture
/// made the same swipe page). The UIKit recognizer arbitrates correctly:
/// the scroll pan claims on movement (flick → page), a stationary 0.15 s hold
/// recognizes the press (→ scrub), and after recognition the recognizer keeps
/// streaming locations, so the finger roams the whole day while the
/// ScrubEngaged preference keeps both scroll axes frozen.
private struct HoldToScrubGesture: UIGestureRecognizerRepresentable {
    let began: (CGPoint) -> Void
    let moved: (CGPoint) -> Void
    let ended: () -> Void

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let recognizer = UILongPressGestureRecognizer()
        recognizer.minimumPressDuration = 0.15
        return recognizer
    }

    func handleUIGestureRecognizerAction(
        _ recognizer: UILongPressGestureRecognizer, context: Context
    ) {
        let location = context.converter.localLocation
        switch recognizer.state {
        case .began: began(location)
        case .changed: moved(location)
        default: ended() // .ended, .cancelled, .failed
        }
    }
}

struct TideScrubOverlay: View {
    let model: TideDayModel
    let style: CurveStyle
    let units: HeightUnit
    let timeFormat: TimeFormatOption

    @State private var scrubInstant: Date?
    /// True from the moment the hold completes until the finger lifts — the
    /// window in which the pager must not scroll.
    @State private var holdEngaged = false

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
            .gesture(HoldToScrubGesture(
                began: { location in
                    holdEngaged = true // lock the pager before the first readout
                    updateScrub(atX: location.x, width: proxy.size.width)
                },
                moved: { location in
                    updateScrub(atX: location.x, width: proxy.size.width)
                },
                ended: {
                    holdEngaged = false
                    scrubInstant = nil
                }
            ))
            // Soft tick when the hold engages — the readout appearing gets a
            // physical confirmation, same voice as the pager's today tick.
            .sensoryFeedback(.impact(weight: .light, intensity: 0.5), trigger: holdEngaged) { _, new in
                new
            }
            .preference(key: ScrubEngagedPreferenceKey.self, value: holdEngaged)
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

    /// Map a finger x (overlay-local) onto the day's time span.
    private func updateScrub(atX rawX: CGFloat, width: CGFloat) {
        let x = min(max(rawX, 0), width)
        let fraction = width > 0 ? x / width : 0
        scrubInstant = model.bounds.start.addingTimeInterval(
            Double(fraction) * model.bounds.duration
        )
    }
}
