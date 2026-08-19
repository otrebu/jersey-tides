import SwiftUI

/// DEBUG launch-argument plumbing shared by the harness screens
/// (implementation plan §4: `-harness widgets|app|curve`, `-harness-day <ISO>`,
/// `-harness-mode standard|accented|vibrant`, `-frozen-now <ISO8601>`).
enum LaunchArguments {
    /// The value following a `-flag`-style argument, if present.
    static func value(for flag: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: flag),
              arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }
}

/// Which surface to boot into. DEBUG-only; release builds always get the app.
enum HarnessMode: String {
    case app
    case widgets
    case curve

    static func fromLaunchArguments() -> HarnessMode {
        #if DEBUG
        if let raw = LaunchArguments.value(for: "-harness"),
           let mode = HarnessMode(rawValue: raw) {
            return mode
        }
        // Bare `-harness` defaults to the widget gallery.
        if ProcessInfo.processInfo.arguments.contains("-harness") {
            return .widgets
        }
        #endif
        return .app
    }
}

@main
struct JerseyTidesApp: App {
    /// Deep-link target parsed from `jerseytides://day/<ISO>`; consumed (and
    /// cleared) by TodayScreen's pager — chunk C.
    @State private var requestedDay: CalendarDay?

    private let harness = HarnessMode.fromLaunchArguments()

    var body: some Scene {
        WindowGroup {
            root
                .onOpenURL { url in
                    if let day = DeepLink.parse(url) {
                        requestedDay = day
                    }
                }
        }
    }

    @ViewBuilder
    private var root: some View {
        switch harness {
        case .widgets:
            #if DEBUG
            DebugWidgetGallery()
            #else
            TodayScreen(requestedDay: $requestedDay)
            #endif
        case .curve:
            #if DEBUG
            CurveHarnessScreen()
            #else
            TodayScreen(requestedDay: $requestedDay)
            #endif
        case .app:
            TodayScreen(requestedDay: $requestedDay)
        }
    }
}

#if DEBUG
/// `-harness curve`: every TideCurveView preset + the ghost sparkline for the
/// (frozen) clock's day — chunk B's screenshot gate renders through this.
struct CurveHarnessScreen: View {
    private let model = TideDayModel.make(
        day: TideTime.calendarDay(of: EngineProvider.clock.now),
        now: EngineProvider.clock.now
    )

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                harnessRow(".app · 200 pt") {
                    TideCurveView(model: model, style: .app).frame(height: 200)
                }
                harnessRow(".medium · 200×130 pt") {
                    TideCurveView(model: model, style: .medium).frame(width: 200, height: 130)
                }
                harnessRow(".large · 170 pt") {
                    TideCurveView(model: model, style: .large).frame(height: 170)
                }
                harnessRow(".rect · 160×48 pt") {
                    TideCurveView(model: model, style: .rect).frame(width: 160, height: 48)
                }
                harnessRow("ghost sparkline · 20 pt") {
                    if let tomorrow = model.tomorrow {
                        Sparkline(samples: tomorrow.samples, bounds: tomorrow.bounds)
                            .frame(height: 20)
                    }
                }
            }
            .padding(24)
        }
        .background(Color.sky.ignoresSafeArea())
    }

    private func harnessRow(
        _ label: String, @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).metaStyle()
            content()
        }
    }
}
#endif
