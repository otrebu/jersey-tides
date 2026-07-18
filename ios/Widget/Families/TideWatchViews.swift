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
    let state: TideWatchAttributes.ContentState

    var body: some View {
        ProgressView(timerInterval: state.interval, countsDown: false) {
        } currentValueLabel: {
        }
        .progressViewStyle(.linear)
        .tint(.white)
    }
}
