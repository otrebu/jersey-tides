#if DEBUG
import SwiftUI
import WidgetKit

/// `-harness widgets`: renders every widget entry view directly at family size
/// for the (frozen) clock (widgets cannot be scripted onto the sim home
/// screen). Spec: implementation plan §4 "DebugWidgetGallery spec".
///
/// Selectors:
/// - `-harness-day <ISO yyyy-MM-dd>` — override the rendered day (noon local).
/// - `-harness-mode standard|accented|vibrant` — sets
///   `\.widgetRenderingMode` on the whole gallery (the SDK setter is public),
///   flipping every mode-dependent code path. The system compositor's actual
///   tinting/vibrancy is NOT simulated — final visual sign-off for accented /
///   vibrant is the manual gate in the footer row.
/// - `-harness-page 1|2|3|4|5|6|7` — one section per launch (screenshot paging;
///   each page fits a single iPhone screen); omit to stack all sections in
///   one scroll.
struct DebugWidgetGallery: View {
    private let now: Date
    private let entry: TideEntry
    private let dialNowEntry: TideEntry
    private let rectCurveEntry: TideEntry
    private let thresholdEntry: TideEntry
    private let errorEntry: TideEntry
    private let page: Int?
    private let modeOverride: WidgetRenderingMode?
    private let modeLabel: String

    init() {
        var instant = EngineProvider.clock.now
        if let iso = LaunchArguments.value(for: "-harness-day") {
            let parts = iso.split(separator: "-").compactMap { Int($0) }
            if parts.count == 3 {
                let day = CalendarDay(year: parts[0], month: parts[1], day: parts[2])
                instant = TideTime.date(day, hour: 12, minute: 0)
            }
        }
        now = instant

        func config(_ mutate: (inout TideWidgetConfig) -> Void) -> TideWidgetConfig {
            var config = TideWidgetConfig.default
            mutate(&config)
            return config
        }
        entry = TideEntry.make(at: instant)
        dialNowEntry = TideEntry.make(at: instant, config: config { $0.emphasis = .now })
        rectCurveEntry = TideEntry.make(at: instant, config: config { $0.rectStyle = .curve })
        thresholdEntry = TideEntry.make(
            at: instant,
            config: config {
                $0.markedHeight = 7.5
                $0.markedLabel = "Causeway"
            }
        )
        errorEntry = TideEntry.error(at: instant)
        page = LaunchArguments.value(for: "-harness-page").flatMap(Int.init)

        switch LaunchArguments.value(for: "-harness-mode") {
        case "accented":
            modeOverride = .accented
            modeLabel = "accented"
        case "vibrant":
            modeOverride = .vibrant
            modeLabel = "vibrant"
        default:
            modeOverride = nil
            modeLabel = "standard"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("widget gallery · \(TideFormatters.mediumDate(TideTime.calendarDay(of: now))) · mode \(modeLabel)")
                    .engravingStyle()
                if showsPage(1) { systemSmallRows }
                if showsPage(2) { chartRows }
                if showsPage(3) { accessoryRows }
                if showsPage(4) { errorSystemRows }
                if showsPage(5) {
                    errorAccessoryRows
                    footerNote
                }
                if showsPage(6) { tideWatchRows }
                if showsPage(7) { siriSnippetRows }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.sky.ignoresSafeArea())
        .modifier(RenderingModeOverride(mode: modeOverride))
    }

    private func showsPage(_ index: Int) -> Bool {
        page == nil || page == index
    }

    // MARK: Sections

    @ViewBuilder
    private var systemSmallRows: some View {
        galleryRow("systemSmall — Dial · Next tide") {
            systemTile(DialSmallView(entry: entry), width: 170, height: 170)
        }
        galleryRow("systemSmall — Dial · Now") {
            systemTile(DialSmallView(entry: dialNowEntry), width: 170, height: 170)
        }
        galleryRow("systemMedium — Chart") {
            systemTile(ChartMediumView(entry: entry), width: 364, height: 170)
        }
    }

    @ViewBuilder
    private var chartRows: some View {
        galleryRow("systemLarge — Chart") {
            systemTile(ChartLargeView(entry: entry), width: 364, height: 382)
        }
        galleryRow("systemLarge — Chart · marked 7.5 m (OVER)") {
            systemTile(ChartLargeView(entry: thresholdEntry), width: 364, height: 382)
        }
    }

    @ViewBuilder
    private var accessoryRows: some View {
        galleryRow("accessoryRectangular · Text") {
            accessoryTile(RectAccessoryView(entry: entry), width: 160, height: 72)
        }
        galleryRow("accessoryRectangular · Curve") {
            accessoryTile(RectAccessoryView(entry: rectCurveEntry), width: 160, height: 72)
        }
        galleryRow("accessoryCircular") {
            accessoryTile(CircularAccessoryView(entry: entry), width: 76, height: 76)
        }
        galleryRow("accessoryInline") {
            accessoryTile(InlineAccessoryView(entry: entry), width: 234, height: 26)
        }
    }

    @ViewBuilder
    private var errorSystemRows: some View {
        galleryRow("error tile — systemSmall") {
            systemTile(DialSmallView(entry: errorEntry), width: 170, height: 170)
        }
        galleryRow("error tile — systemMedium") {
            systemTile(ChartMediumView(entry: errorEntry), width: 364, height: 170)
        }
        galleryRow("error tile — accessoryRectangular") {
            accessoryTile(RectAccessoryView(entry: errorEntry), width: 160, height: 72)
        }
    }

    @ViewBuilder
    private var errorAccessoryRows: some View {
        galleryRow("error tile — accessoryCircular") {
            accessoryTile(CircularAccessoryView(entry: errorEntry), width: 76, height: 76)
        }
        galleryRow("error tile — accessoryInline") {
            accessoryTile(InlineAccessoryView(entry: errorEntry), width: 234, height: 26)
        }
    }

    /// Manual gate (implementation plan §4): the env override flips code paths
    /// only — real tint desaturation and lock-screen vibrancy must be verified
    /// by placing widgets on a tinted home screen / lock screen in the sim.
    /// Page 6 — Tide Watch Live Activity faces (lock card + island mocks).
    /// The compact/minimal mocks use secondary-source slot metrics (the
    /// 52 × 36.67 class) — the real Dynamic Island remains the manual gate,
    /// verified by starting the activity with `-start-tide-watch` and
    /// backgrounding the app.
    @ViewBuilder
    private var tideWatchRows: some View {
        let rising = TideWatchAttributes.ContentState(
            nextTime: now.addingTimeInterval(89 * 60),
            nextHeight: 10.3,
            nextIsHigh: true,
            prevTime: now.addingTimeInterval(-215 * 60),
            prevHeight: 1.3,
            nextHighTime: now.addingTimeInterval(89 * 60),
            nextHighHeight: 10.3,
            unit: .metres
        )
        let falling = TideWatchAttributes.ContentState(
            nextTime: now.addingTimeInterval(140 * 60),
            nextHeight: 1.2,
            nextIsHigh: false,
            prevTime: now.addingTimeInterval(-160 * 60),
            prevHeight: 10.1,
            nextHighTime: now.addingTimeInterval(9 * 3600 + 25 * 60),
            nextHighHeight: 9.8,
            unit: .metres
        )
        let mockAttributes = TideWatchAttributes(
            stationName: "St Helier · Jersey",
            curveHeights: (0...48).map { 0.5 + 0.45 * sin(Double($0) / 48 * 4 * .pi - 1.2) },
            curveMarks: [
                .init(fraction: 0.16, level: 0.05, isHigh: false),
                .init(fraction: 0.40, level: 0.95, isHigh: true),
                .init(fraction: 0.66, level: 0.05, isHigh: false),
                .init(fraction: 0.90, level: 0.95, isHigh: true),
            ]
        )
        galleryRow("live activity — lock screen (flooding)") {
            TideWatchLockView(stationName: "St Helier · Jersey", state: rising)
                .background(Color.sky, in: RoundedRectangle(cornerRadius: 24))
                .frame(width: 364)
        }
        galleryRow("live activity — lock screen (ebbing)") {
            TideWatchLockView(stationName: "St Helier · Jersey", state: falling)
                .background(Color.sky, in: RoundedRectangle(cornerRadius: 24))
                .frame(width: 364)
        }
        galleryRow("live activity — island expanded (mock)") {
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    TideWatchIslandLeading(state: rising)
                    Spacer()
                    TideWatchIslandTrailing(state: rising)
                }
                TideWatchIslandBottom(attributes: mockAttributes, state: rising)
                    .padding(.top, 8)
            }
            .padding(20)
            .frame(width: 364)
            .background(.black, in: RoundedRectangle(cornerRadius: 44))
            .environment(\.colorScheme, .dark)
        }
        galleryRow("live activity — island compact (mock)") {
            HStack(spacing: 16) {
                compactIslandMock(state: rising)
                compactIslandMock(state: falling)
            }
        }
        galleryRow("live activity — minimal + glyph level sweep (mock)") {
            HStack(spacing: 10) {
                minimalIslandMock(state: rising)
                minimalIslandMock(state: falling)
                ForEach([0.15, 0.35, 0.5, 0.65, 0.85], id: \.self) { level in
                    TideWaveGlyph(level: level, rising: level >= 0.5)
                        .frame(width: 25, height: 25)
                        .padding(6)
                        .background(.black, in: Circle())
                }
            }
            .environment(\.colorScheme, .dark)
        }
    }

    /// Page 7 — Siri snippet cards (`App/Intents/`). Rendered on a `sky`
    /// card here; in Siri the system material is the background.
    @ViewBuilder
    private var siriSnippetRows: some View {
        let engine = EngineProvider.engine
        let extremes = engine.extremes(from: now, to: now.addingTimeInterval(48 * 3600))
        if let next = extremes.first {
            galleryRow("siri snippet — next extreme") {
                TideExtremeSnippetView(
                    stationName: engine.stationName, extreme: next, now: now,
                    units: .metres, timeFormat: .system
                )
                .background(Color.sky, in: RoundedRectangle(cornerRadius: 24))
                .frame(width: 364)
            }
            galleryRow("siri snippet — tide now") {
                TideNowSnippetView(
                    stationName: engine.stationName, level: engine.levelAt(now),
                    rising: next.isHigh, next: next,
                    units: .metres, timeFormat: .system
                )
                .background(Color.sky, in: RoundedRectangle(cornerRadius: 24))
                .frame(width: 364)
            }
        }
    }

    private var footerNote: some View {
        Text(
            "MANUAL GATE — accented/vibrant compositing is not simulated: "
                + "place widgets on a tinted home screen (accented) and the lock "
                + "screen (vibrant) in the simulator and compare against §2.1."
        )
        .metaStyle()
        .frame(maxWidth: 364, alignment: .leading)
    }

    // MARK: Tiles

    /// System-family tile: 16 pt padding simulates the widget content margins.
    private func systemTile(
        _ view: some View, width: CGFloat, height: CGFloat
    ) -> some View {
        view
            .padding(16)
            .frame(width: width, height: height)
            .background(Color.sky)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Color.hairline))
    }

    /// Accessory tile: dark backdrop + dark scheme approximates the lock
    /// screen material so `.primary`/`.secondary` tiers read correctly.
    private func accessoryTile(
        _ view: some View, width: CGFloat, height: CGFloat
    ) -> some View {
        view
            .frame(width: width, height: height)
            .padding(10)
            .background(Color(red: 0.09, green: 0.11, blue: 0.15))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .environment(\.colorScheme, .dark)
    }

    /// Compact island mock: real slot metrics (23 pt glyph, 37 pt pill) with a
    /// spacer standing in for the TrueDepth sensor region.
    private func compactIslandMock(state: TideWatchAttributes.ContentState) -> some View {
        HStack(spacing: 0) {
            TideWaveGlyph(state: state)
                .frame(width: 23, height: 23)
            Spacer().frame(width: 70)
            // Same formatter as the real face, so a 12-hour locale's wider
            // time ("10:47p") shows up in the mock too.
            Text(TideFormatters.compactTime(state.nextTime))
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 9)
        .frame(height: 37)
        .background(.black, in: Capsule())
        .environment(\.colorScheme, .dark)
    }

    private func minimalIslandMock(state: TideWatchAttributes.ContentState) -> some View {
        TideWaveGlyph(state: state)
            .frame(width: 25, height: 25)
            .frame(width: 37, height: 37)
            .background(.black, in: Circle())
            .environment(\.colorScheme, .dark)
    }

    private func galleryRow(
        _ label: String, @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).metaStyle()
            content()
        }
    }
}

/// Applies `\.widgetRenderingMode` only when a `-harness-mode` override exists,
/// so the default run keeps the host's real value.
private struct RenderingModeOverride: ViewModifier {
    let mode: WidgetRenderingMode?

    func body(content: Content) -> some View {
        if let mode {
            content.environment(\.widgetRenderingMode, mode)
        } else {
            content
        }
    }
}
#endif
