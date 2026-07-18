import ActivityKit
import SwiftUI
import WidgetKit

/// "Tide Watch" Live Activity faces (lock screen + Dynamic Island regions).
/// Everything shown is an absolute value or a system-rendered timer over
/// `prevTime...nextTime` — the system animates countdown + progress, so the
/// activity is live without a single update from the app.
///
/// The island backdrop is always black glass, so island regions use the
/// vibrant discipline (§2.1): white opacity tiers, never `sea`. The lock
/// screen card uses the full Horizon tokens on a `sky` tint.
enum TideWatchVoice {
    static func eyebrow(_ state: TideWatchAttributes.ContentState) -> String {
        state.nextIsHigh ? "NEXT HIGH WATER" : "NEXT LOW WATER"
    }

    static func arrowName(_ state: TideWatchAttributes.ContentState) -> String {
        state.nextIsHigh ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill"
    }
}

/// Lock screen / StandBy / banner presentation.
struct TideWatchLockView: View {
    let stationName: String
    let state: TideWatchAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(stationName.uppercased())
                Spacer()
                Text(TideWatchVoice.eyebrow(state))
            }
            .font(.caption2.weight(.semibold))
            .tracking(1.4)
            .foregroundStyle(Color.seaSecondary)

            HStack(alignment: .firstTextBaseline) {
                Text(TideFormatters.time(state.nextTime))
                    .font(.system(size: 34, weight: .thin))
                    .monospacedDigit()
                    .foregroundStyle(Color.sea)
                Text(TideFormatters.height(state.nextHeight, unit: .metres))
                    .font(.footnote)
                    .foregroundStyle(Color.seaSecondary)
                Spacer()
                Text(timerInterval: state.interval, countsDown: true)
                    .font(.system(size: 26, weight: .thin))
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 96)
                    .foregroundStyle(Color.sea)
            }

            ProgressView(timerInterval: state.interval, countsDown: false) {
            } currentValueLabel: {
            }
            .progressViewStyle(.linear)
            .tint(Color.sea)
        }
        .padding(16)
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
            Text(TideFormatters.height(state.nextHeight, unit: .metres))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))
        }
    }
}

struct TideWatchIslandTrailing: View {
    let state: TideWatchAttributes.ContentState

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Image(systemName: TideWatchVoice.arrowName(state))
                .imageScale(.small)
                .foregroundStyle(.white.opacity(0.55))
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
