import SwiftUI
import WidgetKit

/// systemSmall "the clock" — the classic tide-clock instrument (widget canvas
/// concept #1). A needle sweeps one half-cycle per face half: it climbs the
/// LEFT side toward HIGH at 12 while the tide rises, and falls down the RIGHT
/// side toward LOW at 6 while it ebbs. The face stays pure instrument; the
/// countdown + exact event live in the footer.
///
/// Rendering-mode contract §2.1: the countdown line is the accent group; the
/// face draws in `sea`/`hairline` only, no `dawn` at this size.
struct ClockSmallView: View {
    let entry: TideEntry

    private var units: HeightUnit { entry.config.units }

    var body: some View {
        Group {
            if let model = entry.dayModel, let next = model.nextExtreme {
                clock(model: model, next: next)
            } else {
                ErrorTileView(family: .systemSmall)
            }
        }
        .containerBackground(Color.sky, for: .widget)
        .widgetURL(entry.dayModel?.day.deepLinkURL)
    }

    // MARK: Layout

    private func clock(model: TideDayModel, next: TideExtreme) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("St Helier").engravingStyle()
            TideClockFace(angle: needleAngle(next: next))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 1)
            Text(
                "\(next.isHigh ? "HW" : "LW") "
                    + TideFormatters.countdown(to: next.time, from: entry.displayInstant)
            )
            .tableStyle()
            .foregroundStyle(.sea)
            .contentTransition(.numericText())
            .widgetAccentable()
            Text(
                "\(TideFormatters.time(next.time)) · "
                    + TideFormatters.height(next.height, unit: units)
            )
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(.seaSecondary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WidgetVoice.summary(model, units: units))
    }

    /// Clockwise angle from HIGH (top). Falling half (next is LOW): 0→π down
    /// the right side; rising half (next is HIGH): π→2π up the left side.
    /// The true previous extreme anchors the sweep so uneven half-cycles
    /// (5.9–6.8 h at St Helier) keep the needle honest; the mean half-cycle
    /// is only the fallback when no predecessor is found.
    private func needleAngle(next: TideExtreme) -> Angle {
        let now = entry.displayInstant
        let meanHalfCycle: TimeInterval = 6.2103 * 3600
        let previous = EngineProvider.engine
            .extremes(from: now.addingTimeInterval(-16 * 3600), to: now)
            .last
        let start = previous?.time ?? next.time.addingTimeInterval(-meanHalfCycle)
        let span = next.time.timeIntervalSince(start)
        let fraction = span > 0 ? min(max(now.timeIntervalSince(start) / span, 0), 1) : 0
        return .radians(next.isHigh ? .pi + fraction * .pi : fraction * .pi)
    }
}

/// The dial: hairline ring, 12 ticks (cardinals longer + stronger), HIGH/LOW
/// triangles quoting the app's rising/falling arrows, `sea` needle with hub.
private struct TideClockFace: View {
    let angle: Angle

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 1

            // Ring.
            context.stroke(
                Path(ellipseIn: CGRect(
                    x: center.x - radius, y: center.y - radius,
                    width: radius * 2, height: radius * 2
                )),
                with: .color(.hairline), lineWidth: 1
            )

            // 12 ticks; cardinal HIGH/LOW ticks longer and stronger.
            for tick in 0..<12 {
                let theta = Double(tick) * .pi / 6
                let cardinal = tick == 0 || tick == 6
                let inner = radius - (cardinal ? 7 : 3.5)
                var path = Path()
                path.move(to: point(center: center, radius: radius, theta: theta))
                path.addLine(to: point(center: center, radius: inner, theta: theta))
                context.stroke(
                    path,
                    with: .color(cardinal ? .seaSecondary : .seaTertiary),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                )
            }

            // HIGH / LOW engraved on the face, the way a real tide clock is.
            let faceLabel = Font.system(size: 7, weight: .semibold)
            context.draw(
                Text(verbatim: "HIGH").font(faceLabel).kerning(1.1)
                    .foregroundStyle(Color.seaSecondary),
                at: CGPoint(x: center.x + 0.5, y: center.y - radius + 15)
            )
            context.draw(
                Text(verbatim: "LOW").font(faceLabel).kerning(1.1)
                    .foregroundStyle(Color.seaSecondary),
                at: CGPoint(x: center.x + 0.5, y: center.y + radius - 15)
            )

            // Needle + counterweight tail + hub.
            let theta = angle.radians
            var needle = Path()
            needle.move(to: point(center: center, radius: -7, theta: theta))
            needle.addLine(to: point(center: center, radius: radius * 0.72, theta: theta))
            context.stroke(
                needle, with: .color(.sea),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
            )
            let hub = CGRect(x: center.x - 3.5, y: center.y - 3.5, width: 7, height: 7)
            context.fill(Path(ellipseIn: hub), with: .color(.sea))
        }
        .accessibilityHidden(true)
    }

    /// Dial coordinates: theta clockwise from 12 o'clock.
    private func point(center: CGPoint, radius: Double, theta: Double) -> CGPoint {
        CGPoint(x: center.x + radius * sin(theta), y: center.y - radius * cos(theta))
    }

}
