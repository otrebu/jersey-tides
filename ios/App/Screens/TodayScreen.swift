import SwiftUI
import UIKit
import WidgetKit

/// Screen 1 — the instrument face (design doc §5.1): a lazy horizontal
/// paging `ScrollView` (`LazyHStack` + `.scrollTargetBehavior(.paging)`),
/// one `DayPage` per day, ±`DeepLink.pageRadius` (10 years — effectively
/// unbounded; only rendered pages are ever built). Hosts the Fortnight +
/// Settings sheets (§5.2/§5.3), the deep-link routing (§5.4), and the single
/// soft haptic tick on landing back on today (§5.1, Almanac graft #5b).
struct TodayScreen: View {
    /// Deep-link target set by JerseyTidesApp; consumed + cleared here.
    @Binding var requestedDay: CalendarDay?

    @StateObject private var settings = SettingsStore()
    @StateObject private var tideWatch = TideWatchController()
    /// Pager selection as a signed day offset from `baseDay`; 0 = today.
    /// Optional because it doubles as the `scrollPosition(id:)` binding —
    /// treat nil (mid-gesture, mid-layout) as "unchanged".
    @State private var selection: Int? = 0
    /// False while the pager is being dragged or decelerating — pauses the
    /// hero wave's per-frame redraw so nothing competes with the scroll.
    @State private var pagerSettled = true
    /// True while a curve scrub hold owns the touch (ScrubEngaged preference)
    /// — disables the pager's pan so the scrub drag can't page days.
    @State private var scrubEngaged = false
    /// Today at screen creation; refreshed on foreground when the day rolls.
    @State private var baseDay = TideTime.calendarDay(of: EngineProvider.clock.now)
    @State private var showFortnight = false
    @State private var showSettings = false
    /// Day-transition "night passing" veil opacity (mockup `--veil`).
    @State private var veilOpacity: Double = 0
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let clock = EngineProvider.clock

    var body: some View {
        TimelineView(.everyMinute) { _ in
            pager(now: clock.now)
        }
        .background(Color.sky.ignoresSafeArea())
        // Subtle darken-then-lighten hint as the day changes (§5.1 redesign);
        // above the pages, below the status bar, never intercepts touches.
        .overlay {
            Color.nightVeil
                .opacity(veilOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .onChange(of: selection) { _, new in
            guard new != nil else { return } // transient scroll states
            pulseVeil()
        }
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
            tideWatch.rollForwardIfNeeded(
                engine: EngineProvider.engine, now: clock.now, units: settings.units
            )
        }
        .onAppear {
            consumeDeepLink(requestedDay)
            tideWatch.adoptExisting()
            applyHarnessArguments()
            warmAround(currentOffset)
        }
    }

    /// DEBUG screenshot plumbing: `-harness-page <offset>` pre-pages the
    /// pager, `-harness-sheet fortnight|settings` opens a sheet.
    private func applyHarnessArguments() {
        #if DEBUG
        if let raw = LaunchArguments.value(for: "-harness-page"), let offset = Int(raw) {
            selection = min(max(offset, -DeepLink.pageRadius), DeepLink.pageRadius)
        }
        if ProcessInfo.processInfo.arguments.contains("-start-tide-watch") {
            tideWatch.start(engine: EngineProvider.engine, now: clock.now, units: settings.units)
        }
        switch LaunchArguments.value(for: "-harness-sheet") {
        case "fortnight": showFortnight = true
        case "settings": showSettings = true
        default: break
        }
        #endif
    }

    /// The day pager. A lazy paging `ScrollView` rather than `TabView(.page)`:
    /// the TabView builds every page in the `ForEach` eagerly (untenable at
    /// ±10 years) and re-evaluates them all on each selection change; the lazy
    /// stack materializes only the on-screen page and its neighbours, so
    /// swipes stay at full frame rate no matter how far the range spans.
    private func pager(now: Date) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(-DeepLink.pageRadius...DeepLink.pageRadius, id: \.self) { offset in
                    DayPageContainer(
                        day: TideTime.addDays(baseDay, offset),
                        dayOffset: offset,
                        isToday: offset == 0,
                        isActivePage: offset == currentOffset && pagerSettled,
                        now: now,
                        settings: settings,
                        tideWatch: tideWatch,
                        onGearTap: { showSettings = true },
                        onTodayTap: { page(toOffset: 0) },
                        onSpringsTap: { showFortnight = true },
                        onSelectOffset: { page(toOffset: $0) }
                    )
                    .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $selection)
        .scrollIndicators(.hidden)
        .scrollDisabled(scrubEngaged)
        .onScrollPhaseChange { _, newPhase in
            pagerSettled = newPhase == .idle
            if newPhase == .idle { warmAround(currentOffset) }
        }
        .onPreferenceChange(ScrubEngagedPreferenceKey.self) { engaged in
            scrubEngaged = engaged
        }
        .ignoresSafeArea(edges: .bottom)
    }

    /// The pager's current day offset; nil selection (transient) reads as the
    /// last settled page's semantics — today at launch.
    private var currentOffset: Int { selection ?? 0 }

    /// Warm the day-model cache ±2 pages around a pager offset.
    private func warmAround(_ offset: Int) {
        DayModelCache.warmNeighbors(
            of: TideTime.addDays(baseDay, offset),
            markedHeight: settings.markedHeight,
            markedLabel: settings.markedLabelOrNil
        )
    }

    // MARK: Navigation

    private func page(to day: CalendarDay) {
        page(toOffset: DeepLink.pageOffset(for: day, today: baseDay))
    }

    private func page(toOffset offset: Int) {
        let clamped = min(max(offset, -DeepLink.pageRadius), DeepLink.pageRadius)
        // Near targets glide; far ones (Fortnight rows, deep links, `‹ Today`
        // from weeks away) teleport — animating hundreds of page widths is
        // noise, and the veil pulse already marks the transition.
        if abs(clamped - currentOffset) > 8 {
            selection = clamped
        } else {
            withAnimation(.snappy(duration: 0.32, extraBounce: 0)) {
                selection = clamped
            }
        }
        warmAround(clamped)
    }

    /// Subtle "night passing" hint on day changes: darken briefly, then
    /// lighten back. Skipped entirely under Reduce Motion.
    private func pulseVeil() {
        guard !reduceMotion else { return }
        withAnimation(.easeIn(duration: 0.12)) {
            veilOpacity = 0.14
        }
        withAnimation(.easeOut(duration: 0.34).delay(0.12)) {
            veilOpacity = 0
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

/// Process-wide memo of the expensive day assemblies. Engine output is
/// deterministic for a given day + threshold config, so pager pages and
/// minute ticks share one assembly; only the cheap `rebased` runs per tick.
@MainActor
private enum DayModelCache {
    private struct Key: Hashable {
        let day: CalendarDay
        let markedHeight: Double?
        let markedLabel: String?
    }

    private static var store: [Key: TideDayModel] = [:]

    static func base(day: CalendarDay, markedHeight: Double?, markedLabel: String?) -> TideDayModel {
        let key = Key(day: day, markedHeight: markedHeight, markedLabel: markedLabel)
        if let cached = store[key] { return cached }
        if store.count > 96 { store.removeAll(keepingCapacity: true) }
        let built = TideDayModel.make(
            day: day, now: nil, markedHeight: markedHeight, markedLabel: markedLabel
        )
        store[key] = built
        return built
    }

    /// Pre-assembles the neighbours of `day` off the main actor so a swipe
    /// always materializes an already-cached page — paying assembly on the
    /// main thread mid-gesture showed up as a hitch in the slide animation.
    static func warmNeighbors(of day: CalendarDay, markedHeight: Double?, markedLabel: String?) {
        let missing = (-2...2)
            .filter { $0 != 0 }
            .map { TideTime.addDays(day, $0) }
            .filter { store[Key(day: $0, markedHeight: markedHeight, markedLabel: markedLabel)] == nil }
        guard !missing.isEmpty else { return }
        Task.detached(priority: .userInitiated) {
            let built = missing.map {
                ($0, TideDayModel.make(day: $0, markedHeight: markedHeight, markedLabel: markedLabel))
            }
            await MainActor.run {
                if store.count > 96 { store.removeAll(keepingCapacity: true) }
                for (day, model) in built {
                    store[Key(day: day, markedHeight: markedHeight, markedLabel: markedLabel)] = model
                }
            }
        }
    }
}

/// Builds one day's model lazily (only rendered pages pay for assembly, once —
/// memoized in `DayModelCache`) and hands it to `DayPage`. On minute ticks the
/// today page pays only a `rebased` (a few `levelAt` evals), not a rebuild
/// (§5.1 `TimelineView(.everyMinute)`).
private struct DayPageContainer: View {
    let day: CalendarDay
    let dayOffset: Int
    let isToday: Bool
    /// Whether this page is the currently selected pager page.
    let isActivePage: Bool
    let now: Date
    @ObservedObject var settings: SettingsStore
    @ObservedObject var tideWatch: TideWatchController
    let onGearTap: () -> Void
    let onTodayTap: () -> Void
    let onSpringsTap: () -> Void
    let onSelectOffset: (Int) -> Void

    var body: some View {
        let base = DayModelCache.base(
            day: day,
            markedHeight: settings.markedHeight,
            markedLabel: settings.markedLabelOrNil
        )
        DayPage(
            model: isToday ? base.rebased(now: now, engine: EngineProvider.engine) : base,
            isToday: isToday,
            dayOffset: dayOffset,
            isActivePage: isActivePage,
            units: settings.units,
            timeFormat: settings.timeFormat,
            showsSun: settings.sunEvents,
            onGearTap: onGearTap,
            onTodayTap: onTodayTap,
            onSpringsTap: onSpringsTap,
            onSelectOffset: onSelectOffset,
            isWatching: tideWatch.isWatching,
            onWatchTap: isToday
                ? { tideWatch.toggle(engine: EngineProvider.engine, now: now, units: settings.units) }
                : nil
        )
    }
}

private extension Color {
    /// Day-transition veil ink (mockup `--veil`): near-black blue in light,
    /// pure black in dark. App-local — not a shared token, so widget rendering
    /// is untouched.
    static let nightVeil = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0, green: 0, blue: 0, alpha: 1)
            : UIColor(red: 6 / 255, green: 18 / 255, blue: 26 / 255, alpha: 1)
    })
}
