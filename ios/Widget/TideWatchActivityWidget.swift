import ActivityKit
import SwiftUI
import WidgetKit

/// "Tide Watch" Live Activity — the flood/ebb run to the next extreme, live in
/// the Dynamic Island and on the lock screen with zero app-driven updates
/// (system timers only). Views in Widget/Families/TideWatchViews.swift.
struct TideWatchActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TideWatchAttributes.self) { context in
            TideWatchLockView(stationName: context.attributes.stationName, state: context.state)
                .activityBackgroundTint(Color.sky)
                .activitySystemActionForegroundColor(Color.sea)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    TideWatchIslandLeading(state: context.state)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TideWatchIslandTrailing(state: context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    TideWatchIslandBottom(state: context.state)
                        .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: TideWatchVoice.arrowName(context.state))
                    .imageScale(.small)
                    .foregroundStyle(.white)
            } compactTrailing: {
                Text(timerInterval: context.state.interval, countsDown: true)
                    .font(.caption2)
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 44)
                    .foregroundStyle(.white)
            } minimal: {
                Image(systemName: TideWatchVoice.arrowName(context.state))
                    .imageScale(.small)
                    .foregroundStyle(.white)
            }
            .keylineTint(Color.dawn)
        }
    }
}
