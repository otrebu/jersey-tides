import SwiftUI
import WidgetKit

/// Screen 1 — the instrument face (design doc §5.1): `TabView(.page)` pager
/// hard-bounded ±14 days (rubber-band at the edges by construction), index
/// dots hidden, one `DayPage` per day. Hosts the Fortnight + Settings sheets
/// (§5.2/§5.3), the deep-link routing (§5.4), and the single soft haptic tick
/// on landing back on today (§5.1, Almanac graft #5b).
struct TodayScreen: View {
    /// Deep-link target set by JerseyTidesApp; consumed + cleared here.
    @Binding var requestedDay: CalendarDay?

    @StateObject private var settings = SettingsStore()
    /// Pager selection as a signed day offset from `baseDay`; 0 = today.
    @State private var selection = 0
    /// Today at screen creation; refreshed on foreground when the day rolls.
    @State private var baseDay = TideTime.calendarDay(of: EngineProvider.clock.now)
    @State private var showFortnight = false
    @State private var showSettings = false
    @Environment(\.scenePhase) private var scenePhase

    private let clock = EngineProvider.clock

    var body: some View {
        TimelineView(.everyMinute) { _ in
            pager(now: clock.now)
        }
        .background(Color.sky.ignoresSafeArea())
        // Almanac graft #5b: one soft tick when paging lands back on today —
        // nothing fires leaving today or between other days.
        .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: selection == 0) { _, new in
            new
        }
        .sheet(isPresented: $showFortnight) {
            FortnightSheet(startDay: baseDay) { day in
                showFortnight = false
                page(to: day)
            }
            .environmentObject(settings)
            .presentationDetents([.medium, .large])
            .presentationBackground(.thinMaterial)
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet()
                .environmentObject(settings)
        }
        .onChange(of: requestedDay) { _, day in
            consumeDeepLink(day)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            refreshDayAndWidgetsOnForeground()
        }
        .onAppear {
            consumeDeepLink(requestedDay)
            applyHarnessArguments()
        }
    }

    /// DEBUG screenshot plumbing: `-harness-page <offset>` pre-pages the
    /// pager, `-harness-sheet fortnight|settings` opens a sheet.
    private func applyHarnessArguments() {
        #if DEBUG
        if let raw = LaunchArguments.value(for: "-harness-page"), let offset = Int(raw) {
            selection = min(max(offset, -DeepLink.pageRadius), DeepLink.pageRadius)
        }
        switch LaunchArguments.value(for: "-harness-sheet") {
        case "fortnight": showFortnight = true
        case "settings": showSettings = true
        default: break
        }
        #endif
    }

    private func pager(now: Date) -> some View {
        TabView(selection: $selection) {
            ForEach(-DeepLink.pageRadius...DeepLink.pageRadius, id: \.self) { offset in
                DayPageContainer(
                    day: TideTime.addDays(baseDay, offset),
                    isToday: offset == 0,
                    now: now,
                    settings: settings,
                    onGearTap: { showSettings = true },
                    onTodayTap: { page(toOffset: 0) },
                    onSpringsTap: { showFortnight = true },
                    onTomorrowTap: { page(toOffset: min(offset + 1, DeepLink.pageRadius)) }
                )
                .tag(offset)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: Navigation

    private func page(to day: CalendarDay) {
        page(toOffset: DeepLink.pageOffset(for: day, today: baseDay))
    }

    private func page(toOffset offset: Int) {
        withAnimation(.easeInOut(duration: 0.18)) {
            selection = offset
        }
    }

    private func consumeDeepLink(_ day: CalendarDay?) {
        guard let day else { return }
        page(to: day)
        requestedDay = nil
    }

    /// §9: reload widget timelines on foreground when the stored day ≠ today;
    /// also recenters the pager's base day after a midnight rollover.
    private func refreshDayAndWidgetsOnForeground() {
        let today = TideTime.calendarDay(of: clock.now)
        if today != baseDay {
            baseDay = today
            selection = 0
        }
        let key = String(format: "%04d-%02d-%02d", today.year, today.month, today.day)
        let defaults = UserDefaults.standard
        if defaults.string(forKey: "lastActiveDay") != key {
            defaults.set(key, forKey: "lastActiveDay")
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}

/// Builds one day's model lazily (only rendered pages pay for assembly) and
/// hands it to `DayPage`. Recreated on every minute tick so the today page's
/// countdown and now-line stay live (§5.1 `TimelineView(.everyMinute)`).
private struct DayPageContainer: View {
    let day: CalendarDay
    let isToday: Bool
    let now: Date
    @ObservedObject var settings: SettingsStore
    let onGearTap: () -> Void
    let onTodayTap: () -> Void
    let onSpringsTap: () -> Void
    let onTomorrowTap: () -> Void

    var body: some View {
        DayPage(
            model: TideDayModel.make(
                day: day,
                now: isToday ? now : nil,
                markedHeight: settings.markedHeight,
                markedLabel: settings.markedLabelOrNil
            ),
            isToday: isToday,
            units: settings.units,
            timeFormat: settings.timeFormat,
            showsSun: settings.sunEvents,
            onGearTap: onGearTap,
            onTodayTap: onTodayTap,
            onSpringsTap: onSpringsTap,
            onTomorrowTap: onTomorrowTap
        )
    }
}
