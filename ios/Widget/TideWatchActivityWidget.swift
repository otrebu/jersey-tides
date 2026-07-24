import ActivityKit
import SwiftUI
import WidgetKit

/// "Tide Watch" Live Activity — the flood/ebb run to the next extreme, live in
/// the Dynamic Island and on the lock screen with zero app-driven updates
/// (system timers only). Views in Widget/Families/TideWatchViews.swift.
/// Compact = wave badge + absolute next-extreme time (both fixed for the whole
/// run); minimal = the badge alone; the only countdown is the expanded
/// trailing region's — the lock card carries the run gauge instead.
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
                    TideWatchIslandBottom(attributes: context.attributes, state: context.state)
                        .padding(.top, 4)
                }
            } compactLeading: {
                TideWaveGlyph(state: context.state)
                    .frame(width: 23, height: 23)
            } compactTrailing: {
                // `compactTime` (narrow day period), not `time`: "10:47 PM"
                // outgrows the slot in 12-hour locales; "10:47p" stays one
                // short absolute element.
                Text(TideFormatters.compactTime(context.state.nextTime))
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(.white)
            } minimal: {
                TideWaveGlyph(state: context.state)
                    .frame(width: 25, height: 25)
            }
            .keylineTint(Color.dawn)
        }
    }
}
