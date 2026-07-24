import ActivityKit
import SwiftUI
import WidgetKit

// "Tide Watch" Live Activity faces (lock screen + Dynamic Island regions).
// Everything shown is an absolute value or a system-rendered timer over
// `prevTime...nextTime` — the system animates countdown + progress, so the
// activity is live without a single update from the app.
//
// The island backdrop is always black glass, so island regions use the
// vibrant discipline (§2.1): white opacity tiers, never `sea`. The lock
// screen card uses the full Horizon tokens on a `sky` tint. The
// compact/minimal face is `TideWaveGlyph` — a static destination-state
// badge (see its doc).

/// The tide badge for the island's compact and minimal slots: a circular
/// gauge whose water level shows the state the run is heading to — high fill
/// for a flood, low fill for an ebb — with a chevron for direction. The
/// mapping is deliberately the *destination*, not the current level: the
/// activity receives zero app-driven updates, and "flooding toward high
/// water" stays true for the whole run. Circular footprint because the
/// island mask (44 pt corner radius) clips square content, and the minimal
/// slot is a circle. White tiers only — island glass is always black.
struct TideWaveGlyph: View {
    /// Waterline within the badge, 0 empty … 1 full (clamped to 0.15…0.85 so
    /// crest and chevron always clear the ring).
    var level: Double
    var rising: Bool

    init(level: Double, rising: Bool) {
        self.level = level
        self.rising = rising
    }

    /// Run-long static mapping for the Live Activity.
    init(state: TideWatchAttributes.ContentState) {
        self.init(level: state.nextIsHigh ? 0.72 : 0.28, rising: state.nextIsHigh)
    }

    var body: some View {
        Canvas { context, size in
            let d = min(size.width, size.height)
            guard d > 0 else { return }
            let badge = CGRect(
                x: (size.width - d) / 2, y: (size.height - d) / 2,
                width: d, height: d
            )

            // Container ring — the gauge that makes "how full" legible.
            let ringWidth = max(1, d * 0.05)
            context.stroke(
                Path(ellipseIn: badge.insetBy(dx: ringWidth / 2, dy: ringWidth / 2)),
                with: .color(.white.opacity(0.3)),
                lineWidth: ringWidth
            )

            let inner = badge.insetBy(dx: ringWidth + 0.5, dy: ringWidth + 0.5)
            let clamped = min(max(level, 0.15), 0.85)
            let margin = d * 0.18
            let waterY = badge.minY + margin + (1 - clamped) * (d - margin * 2)

            // Gentle sine crest: 1.25 cycles across the badge, ~6% amplitude.
            let amplitude = d * 0.055
            let step = max(0.5, inner.width / 48)
            var crest: [CGPoint] = []
            var x = inner.minX
            while x <= inner.maxX + step / 2 {
                let phase = (x - inner.minX) / inner.width * 2 * .pi * 1.25 + .pi / 6
                crest.append(CGPoint(x: min(x, inner.maxX), y: waterY - amplitude * sin(phase)))
                x += step
            }
            guard crest.count > 1 else { return }

            context.drawLayer { layer in
                layer.clip(to: Path(ellipseIn: inner))
                var water = Path()
                water.move(to: CGPoint(x: inner.minX, y: inner.maxY))
                water.addLines(crest)
                water.addLine(to: CGPoint(x: inner.maxX, y: inner.maxY))
                water.closeSubpath()
                layer.fill(water, with: .color(.white.opacity(0.35)))

                var line = Path()
                line.addLines(crest)
                layer.stroke(
                    line, with: .color(.white),
                    style: StrokeStyle(lineWidth: max(1.25, d * 0.065), lineCap: .round)
                )
            }

            // Chevron in whichever half has room: in the water pointing up on
            // a flood, in the air pointing down on an ebb — either way it sits
            // next to the waterline and points where the surface is going.
            let chevronY = rising
                ? (waterY + inner.maxY) / 2
                : (inner.minY + waterY) / 2
            let w = d * 0.36
            let h = d * 0.16
            let tip = rising ? -h / 2 : h / 2
            var chevron = Path()
            chevron.move(to: CGPoint(x: badge.midX - w / 2, y: chevronY - tip))
            chevron.addLine(to: CGPoint(x: badge.midX, y: chevronY + tip))
            chevron.addLine(to: CGPoint(x: badge.midX + w / 2, y: chevronY - tip))
            context.stroke(
                chevron, with: .color(.white),
                style: StrokeStyle(lineWidth: max(1.5, d * 0.08), lineCap: .round, lineJoin: .round)
            )
        }
        .accessibilityLabel(rising ? "Tide rising" : "Tide falling")
    }
}

/// Lock screen / StandBy / banner presentation. Two facts, no countdowns:
/// the next HIGH water (absolute time + height — looked up past the coming
/// low when the tide is ebbing) and the current run as a range gauge, the
/// previous extreme's height at one end and the next at the other with the
/// system-animated progress bar between. The bar tracks time, not height
/// (tides are sinusoidal), so the card frames "now" honestly without
/// claiming a number it cannot update. The gauge end that is the hero
/// extreme shows only its HW tag — its value already sits in the dial row.
/// Mid-ebb the hero is a *later* extreme than the bar's destination, so the
/// LW end carries its own time as well as its height: the bar's finish line
/// is always labeled, never mistaken for the dial row's high.
struct TideWatchLockView: View {
    let stationName: String
    let state: TideWatchAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(stationName)
                Spacer()
                Text("Next high water")
            }
            .engravingStyle()

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(TideFormatters.time(state.nextHighTime))
                    .font(TideTypography.dial2(size: 34))
                    .foregroundStyle(Color.sea)
                Text(TideFormatters.height(state.nextHighHeight, unit: state.unit))
                    .font(.footnote)
                    .foregroundStyle(Color.seaSecondary)
            }

            HStack(spacing: 10) {
                gaugeEnd(tag: state.nextIsHigh ? "LW" : "HW",
                         height: state.prevHeight)
                ProgressView(timerInterval: state.interval, countsDown: false) {
                } currentValueLabel: {
                }
                .progressViewStyle(.linear)
                .tint(Color.sea)
                gaugeEnd(tag: state.nextIsHigh ? "HW" : "LW",
                         time: state.nextIsHigh ? nil : state.nextTime,
                         height: state.nextIsHigh ? nil : state.nextHeight)
            }
        }
        .padding(16)
    }

    /// One end of the run gauge: engraved HW/LW tag plus that extreme's
    /// absolute height. `height: nil` on the end the dial row already owns;
    /// `time:` on the destination end when it is *not* the dial row's hero
    /// (the ebb case), echoing the dial hierarchy in miniature — time leads
    /// in `sea`, height steps back to `seaSecondary`.
    @ViewBuilder
    private func gaugeEnd(tag: String, time: Date? = nil, height: Double?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(tag)
                .engravingStyle()
            if let time {
                Text(TideFormatters.time(time))
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(Color.sea)
            }
            if let height {
                Text(TideFormatters.height(height, unit: state.unit))
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(time == nil ? Color.sea : Color.seaSecondary)
            }
        }
    }
}

/// Dynamic Island expanded regions, composed by the ActivityConfiguration —
/// split out so the DEBUG gallery can render an island mock too.
struct TideWatchIslandLeading: View {
    let state: TideWatchAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(state.nextIsHigh ? "NEXT HW" : "NEXT LW")
                .font(.caption2.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.55))
            Text(TideFormatters.time(state.nextTime))
                .font(.system(size: 26, weight: .thin))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text(TideFormatters.height(state.nextHeight, unit: state.unit))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))
        }
    }
}

struct TideWatchIslandTrailing: View {
    let state: TideWatchAttributes.ContentState

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            TideWaveGlyph(state: state)
                .frame(width: 18, height: 18)
                .opacity(0.7)
            Text(timerInterval: state.interval, countsDown: true)
                .font(.system(size: 26, weight: .thin))
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 90)
                .foregroundStyle(.white)
        }
    }
}

struct TideWatchIslandBottom: View {
    let attributes: TideWatchAttributes
    let state: TideWatchAttributes.ContentState

    var body: some View {
        VStack(spacing: 6) {
            TideWatchIslandCurve(attributes: attributes)
                .frame(height: 44)
            ProgressView(timerInterval: state.interval, countsDown: false) {
            } currentValueLabel: {
            }
            .progressViewStyle(.linear)
            .tint(.white)
        }
    }
}

/// The day sinus on the island's black glass: white stroke over a faint fill,
/// HW filled dot / LW open ring per the print legend (§4.3.5). Drawn from the
/// normalized snapshot in the attributes — static by design; the progress bar
/// below is the live element.
struct TideWatchIslandCurve: View {
    let attributes: TideWatchAttributes

    var body: some View {
        Canvas { context, size in
            let heights = attributes.curveHeights
            guard heights.count > 1 else { return }
            let inset: CGFloat = 4
            let band = size.height - inset * 2
            func point(_ index: Int) -> CGPoint {
                CGPoint(
                    x: CGFloat(index) / CGFloat(heights.count - 1) * size.width,
                    y: inset + (1 - CGFloat(heights[index])) * band
                )
            }
            let points = heights.indices.map(point(_:))

            var fill = Path()
            fill.move(to: CGPoint(x: 0, y: size.height))
            fill.addLines(points)
            fill.addLine(to: CGPoint(x: size.width, y: size.height))
            fill.closeSubpath()
            context.fill(fill, with: .color(.white.opacity(0.15)))

            var stroke = Path()
            stroke.addLines(points)
            context.stroke(
                stroke, with: .color(.white),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
            )

            for mark in attributes.curveMarks {
                let center = CGPoint(
                    x: CGFloat(mark.fraction) * size.width,
                    y: inset + (1 - CGFloat(mark.level)) * band
                )
                if mark.isHigh {
                    let dot = Path(ellipseIn: CGRect(
                        x: center.x - 2.5, y: center.y - 2.5, width: 5, height: 5
                    ))
                    context.fill(dot, with: .color(.white))
                } else {
                    let ring = Path(ellipseIn: CGRect(
                        x: center.x - 3, y: center.y - 3, width: 6, height: 6
                    ))
                    context.stroke(ring, with: .color(.white), lineWidth: 1.25)
                }
            }
        }
    }
}
