import CoreGraphics
import Foundation
import Testing

@testable import JerseyTides

/// CurveLayout geometry gates (design doc §4.2): x linear in UTC — exact on
/// the 23 h (2026-03-29) and 25 h (2026-10-25) DST days — y-domain includes
/// exact extreme heights with `max(range, 1) × 0.07` padding, label clamps,
/// per-style insets.
struct CurveLayoutTests {
    private let size = CGSize(width: 320, height: 200)
    private let insets = CurveLayout.Insets(top: 24, bottom: 24)

    private func makeLayout(
        day: CalendarDay,
        samples: [TimelinePoint] = [],
        extremes: [TideExtreme] = []
    ) -> CurveLayout {
        CurveLayout(
            samples: samples,
            extremes: extremes,
            bounds: TideTime.dayBounds(day),
            size: size,
            insets: insets
        )
    }

    // MARK: x-mapping — DST days exact

    @Test func springForwardDayXMappingIsExact() {
        let day = CalendarDay(year: 2026, month: 3, day: 29)
        let bounds = TideTime.dayBounds(day)
        #expect(bounds.duration == 23 * 3600)

        let layout = makeLayout(day: day)
        #expect(layout.x(bounds.start) == 0)
        #expect(layout.x(bounds.end) == size.width)
        // Linear in UTC: the UTC midpoint maps to the horizontal midpoint even
        // though the local day is 23 h.
        #expect(layout.x(bounds.start.addingTimeInterval(bounds.duration / 2)) == size.width / 2)
        #expect(layout.x(bounds.start.addingTimeInterval(bounds.duration / 4)) == size.width / 4)

        // Wall-clock noon is start + 11 h (01:00→02:00 skipped), NOT half-way.
        let noon = TideTime.date(day, hour: 12, minute: 0)
        #expect(noon.timeIntervalSince(bounds.start) == 11 * 3600)
        #expect(abs(layout.x(noon) - size.width * 11 / 23) < 1e-9)
    }

    @Test func fallBackDayXMappingIsExact() {
        let day = CalendarDay(year: 2026, month: 10, day: 25)
        let bounds = TideTime.dayBounds(day)
        #expect(bounds.duration == 25 * 3600)

        let layout = makeLayout(day: day)
        #expect(layout.x(bounds.start) == 0)
        #expect(layout.x(bounds.end) == size.width)
        #expect(layout.x(bounds.start.addingTimeInterval(bounds.duration / 2)) == size.width / 2)
        #expect(layout.x(bounds.start.addingTimeInterval(bounds.duration / 4)) == size.width / 4)

        // Wall-clock noon is start + 13 h (02:00→01:00 repeated).
        let noon = TideTime.date(day, hour: 12, minute: 0)
        #expect(noon.timeIntervalSince(bounds.start) == 13 * 3600)
        #expect(abs(layout.x(noon) - size.width * 13 / 25) < 1e-9)
    }

    @Test func normalDayXMappingIsExact() {
        let day = CalendarDay(year: 2026, month: 7, day: 17)
        let bounds = TideTime.dayBounds(day)
        #expect(bounds.duration == 24 * 3600)

        let layout = makeLayout(day: day)
        #expect(layout.x(bounds.start) == 0)
        #expect(layout.x(bounds.start.addingTimeInterval(6 * 3600)) == size.width / 4)
        #expect(layout.x(bounds.end) == size.width)
    }

    // MARK: y-domain

    @Test func yDomainIncludesExactExtremeHeights() {
        let day = CalendarDay(year: 2026, month: 7, day: 17)
        let bounds = TideTime.dayBounds(day)
        // Samples deliberately miss the true extremes (10-min grid vs exact).
        let samples = [
            TimelinePoint(time: bounds.start, height: 2.1),
            TimelinePoint(time: bounds.start.addingTimeInterval(6 * 3600), height: 10.9),
            TimelinePoint(time: bounds.end, height: 2.4),
        ]
        let extremes = [
            TideExtreme(time: bounds.start.addingTimeInterval(5 * 3600), height: 11.2, kind: .high),
            TideExtreme(time: bounds.start.addingTimeInterval(11 * 3600), height: 1.9, kind: .low),
        ]
        let layout = makeLayout(day: day, samples: samples, extremes: extremes)

        #expect(layout.yDomain.contains(11.2))
        #expect(layout.yDomain.contains(1.9))

        // Padding = max(range, 1) × 0.07 on both ends of samples ∪ extremes.
        let padding = (11.2 - 1.9) * 0.07
        #expect(abs(layout.yDomain.lowerBound - (1.9 - padding)) < 1e-9)
        #expect(abs(layout.yDomain.upperBound - (11.2 + padding)) < 1e-9)

        // Markers at exact extreme heights stay inside the plot band.
        #expect(layout.y(11.2) > layout.plotTop)
        #expect(layout.y(1.9) < layout.plotBottom)
    }

    @Test func yDomainPaddingFloorsRangeAtOneMetre() {
        let day = CalendarDay(year: 2026, month: 7, day: 17)
        let bounds = TideTime.dayBounds(day)
        let samples = [
            TimelinePoint(time: bounds.start, height: 6.0),
            TimelinePoint(time: bounds.end, height: 6.2),
        ]
        let layout = makeLayout(day: day, samples: samples)
        // range 0.2 < 1 → padding = 1 × 0.07.
        #expect(abs(layout.yDomain.lowerBound - (6.0 - 0.07)) < 1e-9)
        #expect(abs(layout.yDomain.upperBound - (6.2 + 0.07)) < 1e-9)
    }

    @Test func yMapsDomainEdgesToInsetBand() {
        let day = CalendarDay(year: 2026, month: 7, day: 17)
        let bounds = TideTime.dayBounds(day)
        let samples = [
            TimelinePoint(time: bounds.start, height: 2.0),
            TimelinePoint(time: bounds.end, height: 10.0),
        ]
        let layout = makeLayout(day: day, samples: samples)
        #expect(abs(layout.y(layout.yDomain.upperBound) - insets.top) < 1e-9)
        #expect(abs(layout.y(layout.yDomain.lowerBound) - (size.height - insets.bottom)) < 1e-9)
        // Inverted: higher water is higher on screen.
        #expect(layout.y(10.0) < layout.y(2.0))
    }

    // MARK: Label clamps

    @Test func labelClampsAtBothEdges() {
        let day = CalendarDay(year: 2026, month: 7, day: 17)
        let layout = makeLayout(day: day)
        let labelWidth: CGFloat = 40

        // Leading edge: negative desired x pins to 0.
        #expect(layout.clampedLabelX(-25, labelWidth: labelWidth) == 0)
        // Trailing edge: pins to width − labelWidth.
        #expect(layout.clampedLabelX(310, labelWidth: labelWidth) == size.width - labelWidth)
        #expect(layout.clampedLabelX(size.width, labelWidth: labelWidth) == size.width - labelWidth)
        // Interior positions pass through untouched.
        #expect(layout.clampedLabelX(120, labelWidth: labelWidth) == 120)
        // Degenerate: label wider than the plot pins to 0.
        #expect(layout.clampedLabelX(50, labelWidth: size.width + 10) == 0)
    }

    // MARK: Per-style insets (§4.2)

    @Test func styleInsetsMatchSpec() {
        #expect(CurveStyle.app.insets == CurveLayout.Insets(top: 24, bottom: 24))
        #expect(CurveStyle.medium.insets == CurveLayout.Insets(top: 20, bottom: 20))
        #expect(CurveStyle.large.insets == CurveLayout.Insets(top: 22, bottom: 20))
        #expect(CurveStyle.rect.insets == CurveLayout.Insets(top: 4, bottom: 2))
        #expect(CurveStyle.ghost.insets == CurveLayout.Insets(top: 2, bottom: 2))
    }

    @Test func styleMarkerGeometryMatchesLegend() {
        // §4.3.5 print legend: HW filled dot r 3 / LW ring r 3.5 @ 1.5 pt;
        // rect-curve compacts to 2.5 / 3 @ 1.25 pt.
        #expect(CurveStyle.app.highMarkerRadius == 3)
        #expect(CurveStyle.app.lowMarkerRadius == 3.5)
        #expect(CurveStyle.app.lowMarkerStrokeWidth == 1.5)
        #expect(CurveStyle.rect.highMarkerRadius == 2.5)
        #expect(CurveStyle.rect.lowMarkerRadius == 3)
        #expect(CurveStyle.rect.lowMarkerStrokeWidth == 1.25)
        #expect(CurveStyle.rect.strokeWidth == 2)
    }
}
