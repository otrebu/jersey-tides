import Foundation

/// One table row: the extreme + its swing from the previous extreme
/// (Almanac graft #3; padded 15 h window so the first row of the day has a
/// real predecessor — design doc §5.1).
struct ExtremeRow: Equatable, Sendable {
    let extreme: TideExtreme
    /// Signed height difference vs the previous extreme (m); nil when no predecessor.
    let swing: Double?
}

/// Springs/neaps classification vs the surrounding ±7-day window (design doc §5.1).
enum SpringsClassification: String, Sendable {
    case springs
    case neaps
}

/// Marked-height state for the curve threshold + OVER caption (design doc §8).
struct ThresholdInfo: Equatable, Sendable {
    /// Threshold height, metres above chart datum.
    let height: Double
    /// Optional user label ("Causeway").
    let label: String?
    /// Level at `nowInstant` is above the threshold.
    let isOverNow: Bool
    /// Next downward crossing after now (≤ 1 min accuracy), when over.
    let overUntil: Date?
}

/// Tomorrow's preview: text row + ghost-sparkline input (design doc §4.4, §6 large).
struct TomorrowPreview: Equatable, Sendable {
    let day: CalendarDay
    let bounds: DayBounds
    let firstHigh: TideExtreme?
    let firstLow: TideExtreme?
    /// `timeline(addDays(day, 1), 6)` for the ghost sparkline.
    let samples: [TimelinePoint]
}

/// Everything one rendered day needs, assembled once from the engine facade.
/// Pure value; safe to carry inside widget timeline entries.
struct TideDayModel: Equatable, Sendable {
    let day: CalendarDay
    /// True local-midnight UTC bounds (23/25 h on DST days).
    let bounds: DayBounds
    /// `timeline(day, 6)` — 10-minute samples, endpoints inclusive.
    let samples: [TimelinePoint]
    /// `dayExtremes(day)` — exact instants + heights.
    let extremes: [TideExtreme]
    /// Extremes with the swing column.
    let rows: [ExtremeRow]
    let sun: SunTimes?
    let springs: SpringsClassification?
    /// "full moon in 2 d" / "new moon today"; nil when no event within ±7 d.
    let moonCaption: String?
    /// Header glyph for the current phase ("moonphase.full.moon").
    let moonSymbolName: String?
    /// Horizon-line datum: (day max + day min) / 2 (design doc §4.3).
    let horizonDatum: Double
    /// Display instant for level/now-dot; nil on non-today pages.
    let nowInstant: Date?
    let currentHeight: Double?
    let isRising: Bool?
    /// First extreme after `nowInstant` (may be tomorrow's).
    let nextExtreme: TideExtreme?
    /// Second extreme after `nowInstant`.
    let followingExtreme: TideExtreme?
    let threshold: ThresholdInfo?
    let tomorrow: TomorrowPreview?

    /// Assembles the model. `now == nil` renders a non-today page (no now
    /// marker, no current level, no countdown).
    static func make(
        day: CalendarDay,
        engine: any TideEngine = EngineProvider.engine,
        now: Date? = nil,
        markedHeight: Double? = nil,
        markedLabel: String? = nil
    ) -> TideDayModel {
        let bounds = TideTime.dayBounds(day)
        let samples = engine.timeline(day, samplesPerHour: 6)
        let extremes = engine.dayExtremes(day)
        let rows = swingRows(extremes: extremes, bounds: bounds, engine: engine)
        let sun = engine.sunTimes(day)
        let springs = classifySprings(day: day, dayExtremes: extremes, engine: engine)

        let noonish = bounds.start.addingTimeInterval(bounds.duration / 2)
        let (caption, symbol) = moonInfo(day: day, at: noonish, engine: engine)

        let heights = extremes.map(\.height)
        let sampleHeights = samples.map(\.height)
        let maxHeight = heights.max() ?? sampleHeights.max() ?? 0
        let minHeight = heights.min() ?? sampleHeights.min() ?? 0

        let currentHeight = now.map { engine.levelAt($0) }
        let isRising = now.map { engine.slopeAt($0) > 0 }
        var nextExtreme: TideExtreme?
        var followingExtreme: TideExtreme?
        if let now {
            let upcoming = engine.extremes(from: now, to: now.addingTimeInterval(30 * 3600))
            nextExtreme = upcoming.first
            followingExtreme = upcoming.count > 1 ? upcoming[1] : nil
        }

        var threshold: ThresholdInfo?
        if let markedHeight {
            threshold = thresholdInfo(
                height: markedHeight, label: markedLabel,
                samples: samples, now: now, currentHeight: currentHeight, engine: engine
            )
        }

        let tomorrowDay = TideTime.addDays(day, 1)
        let tomorrowExtremes = engine.dayExtremes(tomorrowDay)
        let tomorrow = TomorrowPreview(
            day: tomorrowDay,
            bounds: TideTime.dayBounds(tomorrowDay),
            firstHigh: tomorrowExtremes.first(where: \.isHigh),
            firstLow: tomorrowExtremes.first(where: { !$0.isHigh }),
            samples: engine.timeline(tomorrowDay, samplesPerHour: 6)
        )

        return TideDayModel(
            day: day,
            bounds: bounds,
            samples: samples,
            extremes: extremes,
            rows: rows,
            sun: sun,
            springs: springs,
            moonCaption: caption,
            moonSymbolName: symbol,
            horizonDatum: (maxHeight + minHeight) / 2,
            nowInstant: now,
            currentHeight: currentHeight,
            isRising: isRising,
            nextExtreme: nextExtreme,
            followingExtreme: followingExtreme,
            threshold: threshold,
            tomorrow: tomorrow
        )
    }

    /// Cheap re-target of the now-dependent fields onto an already-assembled
    /// day model. Widget timelines build one expensive `make` per calendar day
    /// and one `rebased` per entry (a handful of `levelAt`/`slopeAt` evals vs
    /// the full ±7-day springs scan) — this is what keeps entry building at
    /// the <1 ms/entry contract (design doc §12).
    ///
    /// `nextExtreme`/`followingExtreme` come from today's extremes plus
    /// tomorrow's first high + low (alternation guarantees those are
    /// tomorrow's first two), which covers any `now` within this day.
    func rebased(now: Date, engine: any TideEngine) -> TideDayModel {
        let currentHeight = engine.levelAt(now)
        var candidates = extremes
        if let tomorrow {
            candidates += [tomorrow.firstHigh, tomorrow.firstLow].compactMap { $0 }
        }
        let upcoming = candidates.sorted { $0.time < $1.time }.filter { $0.time > now }
        var threshold = self.threshold
        if let existing = threshold {
            threshold = Self.thresholdInfo(
                height: existing.height, label: existing.label,
                samples: samples, now: now, currentHeight: currentHeight, engine: engine
            )
        }
        return TideDayModel(
            day: day, bounds: bounds, samples: samples, extremes: extremes, rows: rows,
            sun: sun, springs: springs, moonCaption: moonCaption,
            moonSymbolName: moonSymbolName, horizonDatum: horizonDatum,
            nowInstant: now, currentHeight: currentHeight,
            isRising: engine.slopeAt(now) > 0,
            nextExtreme: upcoming.first,
            followingExtreme: upcoming.count > 1 ? upcoming[1] : nil,
            threshold: threshold, tomorrow: tomorrow
        )
    }

    // MARK: Assembly helpers

    /// Swing per extreme from a padded window `[dayStart − 15 h, dayEnd)`.
    private static func swingRows(
        extremes: [TideExtreme], bounds: DayBounds, engine: any TideEngine
    ) -> [ExtremeRow] {
        let padded = engine.extremes(
            from: bounds.start.addingTimeInterval(-15 * 3600), to: bounds.end
        )
        return extremes.map { extreme in
            let previous = padded.last(where: { $0.time < extreme.time })
            return ExtremeRow(
                extreme: extreme,
                swing: previous.map { extreme.height - $0.height }
            )
        }
    }

    /// ±7-day percentile rule: ≥ 85 % of window max → springs,
    /// ≤ 115 % of window min → neaps, else nil (design doc §5.1).
    private static func classifySprings(
        day: CalendarDay, dayExtremes: [TideExtreme], engine: any TideEngine
    ) -> SpringsClassification? {
        func range(of extremes: [TideExtreme]) -> Double? {
            guard let hi = extremes.map(\.height).max(),
                  let lo = extremes.map(\.height).min() else { return nil }
            return hi - lo
        }
        guard let todayRange = range(of: dayExtremes) else { return nil }
        var ranges: [Double] = []
        for offset in -7...7 {
            let extremes = offset == 0
                ? dayExtremes
                : engine.dayExtremes(TideTime.addDays(day, offset))
            if let r = range(of: extremes) { ranges.append(r) }
        }
        guard let windowMax = ranges.max(), let windowMin = ranges.min() else { return nil }
        if todayRange >= 0.85 * windowMax { return .springs }
        if todayRange <= 1.15 * windowMin { return .neaps }
        return nil
    }

    /// Nearest quarter-phase event within ±7 d → caption; phase glyph for the header.
    private static func moonInfo(
        day: CalendarDay, at instant: Date, engine: any TideEngine
    ) -> (caption: String?, symbolName: String?) {
        let symbol = engine.moonPhase(at: instant).systemImageName
        let events = engine.moonEvents(around: instant)
        let nearest = events.min {
            abs($0.date.timeIntervalSince(instant)) < abs($1.date.timeIntervalSince(instant))
        }
        guard let nearest else { return (nil, symbol) }
        let eventDay = TideTime.calendarDay(of: nearest.date)
        let diff = TideTime.daysBetween(day, eventDay)
        guard abs(diff) <= 7 else { return (nil, symbol) }
        let caption: String
        switch diff {
        case 0: caption = "\(nearest.kind.captionName) today"
        case 1...: caption = "\(nearest.kind.captionName) in \(diff) d"
        default: caption = "\(nearest.kind.captionName) \(-diff) d ago"
        }
        return (caption, symbol)
    }

    /// Next downward threshold crossing from now: scan 10-min samples, refine
    /// by bisection on `levelAt` to ≤ 1 min (design doc §8).
    private static func thresholdInfo(
        height: Double, label: String?, samples: [TimelinePoint],
        now: Date?, currentHeight: Double?, engine: any TideEngine
    ) -> ThresholdInfo {
        guard let now, let currentHeight else {
            return ThresholdInfo(height: height, label: label, isOverNow: false, overUntil: nil)
        }
        let isOver = currentHeight > height
        var until: Date?
        if isOver {
            var previousTime = now
            var previousLevel = currentHeight
            for point in samples where point.time > now {
                if previousLevel >= height, point.height < height {
                    until = refineCrossing(
                        threshold: height, from: previousTime, to: point.time, engine: engine
                    )
                    break
                }
                previousTime = point.time
                previousLevel = point.height
            }
        }
        return ThresholdInfo(height: height, label: label, isOverNow: isOver, overUntil: until)
    }

    private static func refineCrossing(
        threshold: Double, from: Date, to: Date, engine: any TideEngine
    ) -> Date {
        var lo = from.timeIntervalSinceReferenceDate
        var hi = to.timeIntervalSinceReferenceDate
        for _ in 0..<20 {
            let mid = (lo + hi) / 2
            if engine.levelAt(Date(timeIntervalSinceReferenceDate: mid)) >= threshold {
                lo = mid
            } else {
                hi = mid
            }
        }
        return Date(timeIntervalSinceReferenceDate: (lo + hi) / 2)
    }
}
