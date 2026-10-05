import AppIntents
import WidgetKit

/// watchOS marks the WidgetKit default `recommendations()` unavailable, so the
/// shared providers need one here. iOS keeps the SDK default.
extension DialTimelineProvider {
    func recommendations() -> [AppIntentRecommendation<DialConfigIntent>] {
        [AppIntentRecommendation(intent: DialConfigIntent(), description: "St Helier")]
    }
}

extension ChartTimelineProvider {
    func recommendations() -> [AppIntentRecommendation<ChartConfigIntent>] {
        [AppIntentRecommendation(intent: ChartConfigIntent(), description: "St Helier")]
    }
}

extension RectTimelineProvider {
    func recommendations() -> [AppIntentRecommendation<RectConfigIntent>] {
        [AppIntentRecommendation(intent: RectConfigIntent(), description: "St Helier")]
    }
}
