import Accessibility
import SwiftUI
import WidgetKit

/// Rendering preset per surface (design doc §4.2 insets, §4.3 treatments).
struct CurveStyle: Equatable, Sendable {
    var insets: CurveLayout.Insets
    var strokeWidth: CGFloat
    var showsHorizonLine: Bool
    var showsHorizonLabel: Bool
    var showsSunTicks: Bool
    var showsSunTimes: Bool
    var showsExtremeLabels: Bool
    var showsExtremeMarkers: Bool

    /// App face — 200 pt tall, labeled horizon, sun times under ticks.
    static let app = CurveStyle(
        insets: .init(top: 24, bottom: 24), strokeWidth: 1.5,
        showsHorizonLine: true, showsHorizonLabel: true,
        showsSunTicks: true, showsSunTimes: true,
        showsExtremeLabels: true, showsExtremeMarkers: true
    )
    /// systemMedium — unlabeled horizon, ticks without times.
    static let medium = CurveStyle(
        insets: .init(top: 20, bottom: 20), strokeWidth: 1.5,
        showsHorizonLine: true, showsHorizonLabel: false,
        showsSunTicks: true, showsSunTimes: false,
        showsExtremeLabels: true, showsExtremeMarkers: true
    )
    /// systemLarge — labeled horizon, sun ticks. The 4-column table and SUN
    /// row sit directly below the plot, so in-plot extreme labels and sun
    /// times would say everything twice — the large curve stays quiet.
    static let large = CurveStyle(
        insets: .init(top: 22, bottom: 20), strokeWidth: 1.5,
        showsHorizonLine: true, showsHorizonLabel: true,
        showsSunTicks: true, showsSunTimes: false,
        showsExtremeLabels: false, showsExtremeMarkers: true
    )
    /// accessoryRectangular Curve style — 2 pt stroke, markers only.
    static let rect = CurveStyle(
        insets: .init(top: 4, bottom: 2), strokeWidth: 2,
        showsHorizonLine: false, showsHorizonLabel: false,
        showsSunTicks: false, showsSunTimes: false,
        showsExtremeLabels: false, showsExtremeMarkers: true
    )
    /// Tomorrow ghost — bare line.
    static let ghost = CurveStyle(
        insets: .init(top: 2, bottom: 2), strokeWidth: 1,
        showsHorizonLine: false, showsHorizonLabel: false,
        showsSunTicks: false, showsSunTimes: false,
        showsExtremeLabels: false, showsExtremeMarkers: false
    )
}

extension CurveStyle {
    /// Compact accessory geometry (design doc §4.3.5 marker sizes).
    var isCompact: Bool { self == .rect }
    /// HW filled-dot radius: 3 pt (rect-curve 2.5).
    var highMarkerRadius: CGFloat { isCompact ? 2.5 : 3 }
    /// LW open-ring radius: 3.5 pt (rect-curve 3).
    var lowMarkerRadius: CGFloat { isCompact ? 3 : 3.5 }
    /// LW ring stroke: 1.5 pt (rect-curve 1.25).
    var lowMarkerStrokeWidth: CGFloat { isCompact ? 1.25 : 1.5 }
    /// Now-dot radius (§4.1); halo punch adds 2 pt.
    var nowDotRadius: CGFloat { 3.5 }
    /// Threshold line + shading appear at app/medium/large only (§4.3 #6) —
    /// exactly the styles that carry the horizon line.
    var showsThreshold: Bool { showsHorizonLine }
}

/// The shared day-curve renderer (design doc §4): two stacked Canvases —
/// base (fill, horizon, sun, labels, now-line, threshold) + `.widgetAccentable()`
/// overlay (curve stroke, HW/LW markers, punch-out now-dot) — fed by one
/// `CurveLayout` so positions can never disagree.
struct TideCurveView: View {
    let model: TideDayModel
    let style: CurveStyle

    @Environment(\.widgetRenderingMode) private var renderingMode

    init(model: TideDayModel, style: CurveStyle) {
        self.model = model
        self.style = style
    }

    var body: some View {
        GeometryReader { proxy in
            // Computed ONCE and captured by both Canvas closures (§4.1).
            let layout = CurveLayout(
                samples: model.samples,
                extremes: model.extremes,
                bounds: model.bounds,
                size: proxy.size,
                insets: style.insets
            )
            ZStack {
                Canvas { context, _ in
                    drawBase(&context, layout: layout)
                }
                Canvas { context, _ in
                    drawOverlay(&context, layout: layout)
                }
                .widgetAccentable()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityChartDescriptor(TideChartDescriptor(model: model, summary: accessibilitySummary))
    }

    // MARK: Rendering-mode palette (§2.1)

    private var isAccented: Bool { renderingMode == .accented }
    private var isVibrant: Bool { renderingMode == .vibrant }

    /// Curve / marker / now-dot ink (overlay canvas).
    private var inkColor: Color { isVibrant ? .white : .sea }
    /// Sun ticks, sun times, threshold — `dawn` is dropped entirely in
    /// accented mode; the tint never fights a second chroma.
    private var solarColor: Color { isAccented ? .primary.opacity(0.55) : .dawn }
    private var hairlineColor: Color { isAccented ? .primary.opacity(0.14) : .hairline }
    private var secondaryColor: Color { isAccented ? .primary.opacity(0.55) : .seaSecondary }
    private var tertiaryColor: Color { isAccented ? .primary.opacity(0.30) : .seaTertiary }

    // MARK: Base canvas (§4.3 order: fill → horizon → sun → labels → threshold → now-line)

    private func drawBase(_ context: inout GraphicsContext, layout: CurveLayout) {
        drawSeaFill(&context, layout: layout)
        drawHorizon(&context, layout: layout)
        drawSunTicks(&context, layout: layout)
        drawExtremeLabels(&context, layout: layout)
        drawThreshold(&context, layout: layout)
        drawNowLine(&context, layout: layout)
    }

    /// 1. Sea fill — closed path curve→plot-bottom, vertical `seaFill`
    /// gradient. Accented: flat primary @ 8 % (tinting flattens gradients
    /// anyway); vibrant: white @ 15 %.
    private func drawSeaFill(_ context: inout GraphicsContext, layout: CurveLayout) {
        guard let fill = underCurvePath(layout: layout) else { return }
        if isAccented {
            context.fill(fill, with: .color(.primary.opacity(0.08)))
        } else if isVibrant {
            context.fill(fill, with: .color(.white.opacity(0.15)))
        } else {
            context.fill(
                fill,
                with: .linearGradient(
                    Gradient(colors: [.seaFillTop, .seaFillTop.opacity(0)]),
                    startPoint: CGPoint(x: 0, y: layout.plotTop),
                    endPoint: CGPoint(x: 0, y: layout.plotBottom)
                )
            )
        }
    }

    /// 2. Horizon line (signature) — 0.5 pt hairline at `y(mid)`; right-aligned
    /// Meta-size datum label sitting on the line, knocked out with a 2 pt `sky`
    /// rectangle behind it (app + systemLarge only).
    private func drawHorizon(_ context: inout GraphicsContext, layout: CurveLayout) {
        guard style.showsHorizonLine else { return }
        let lineY = layout.y(model.horizonDatum)
        var line = Path()
        line.move(to: CGPoint(x: 0, y: lineY))
        line.addLine(to: CGPoint(x: layout.size.width, y: lineY))
        context.stroke(line, with: .color(hairlineColor), lineWidth: 0.5)

        guard style.showsHorizonLabel else { return }
        let label = context.resolve(
            Text(TideFormatters.heightValue(model.horizonDatum, unit: .metres))
                .font(TideTypography.meta)
                .foregroundStyle(secondaryColor)
        )
        let labelSize = label.measure(in: layout.size)
        let labelRect = CGRect(
            x: layout.size.width - labelSize.width - 4,
            y: lineY - labelSize.height / 2,
            width: labelSize.width,
            height: labelSize.height
        )
        if !isAccented {
            // Knock-out: the hairline passes behind the label, not through it.
            context.fill(Path(labelRect.insetBy(dx: -2, dy: -2)), with: .color(.sky))
        }
        context.draw(label, in: labelRect)
    }

    /// 4. Sun ticks — 1 pt `dawn` verticals, 7 pt tall, rising from plot bottom
    /// at `x(sunrise)` / `x(sunset)`; nullable-safe, x-clamped. Times under the
    /// ticks (Meta, `dawn`) in app + systemLarge only.
    private func drawSunTicks(_ context: inout GraphicsContext, layout: CurveLayout) {
        guard style.showsSunTicks, let sun = model.sun else { return }
        let exclusions = lowLabelExclusions(context, layout: layout)
        for instant in [sun.sunrise, sun.sunset].compactMap({ $0 }) {
            let tickX = min(max(layout.x(instant), 0), layout.size.width)
            var tick = Path()
            tick.move(to: CGPoint(x: tickX, y: layout.plotBottom - 7))
            tick.addLine(to: CGPoint(x: tickX, y: layout.plotBottom))
            context.stroke(tick, with: .color(solarColor), lineWidth: 1)

            guard style.showsSunTimes else { continue }
            let label = context.resolve(
                Text(TideFormatters.time(instant))
                    .font(TideTypography.meta)
                    .foregroundStyle(solarColor)
            )
            let labelSize = label.measure(in: layout.size)
            var labelX = layout.clampedLabelX(tickX - labelSize.width / 2, labelWidth: labelSize.width)
            // The bottom strip is shared with the LW label pairs (§4.3 #4/#5):
            // slide a colliding sun time clear, away from the LW marker
            // (e.g. sunset 21:12 vs the 20:4x evening low).
            for exclusion in exclusions
            where labelX < exclusion.range.upperBound
                && labelX + labelSize.width > exclusion.range.lowerBound {
                labelX = tickX >= exclusion.markerX
                    ? exclusion.range.upperBound + 3
                    : exclusion.range.lowerBound - labelSize.width - 3
            }
            labelX = layout.clampedLabelX(labelX, labelWidth: labelSize.width)
            context.draw(
                label,
                in: CGRect(
                    x: labelX, y: layout.plotBottom + 2,
                    width: labelSize.width, height: labelSize.height
                )
            )
        }
    }

    /// Horizontal spans the LW label pairs occupy in the bottom strip.
    private func lowLabelExclusions(
        _ context: GraphicsContext, layout: CurveLayout
    ) -> [(range: ClosedRange<CGFloat>, markerX: CGFloat)] {
        guard style.showsExtremeLabels else { return [] }
        return model.extremes.filter { !$0.isHigh }.map { extreme in
            let markerX = layout.x(extreme.time)
            let timeWidth = context.resolve(
                Text(TideFormatters.time(extreme.time)).font(TideTypography.chartTime)
            ).measure(in: layout.size).width
            let heightWidth = context.resolve(
                Text(TideFormatters.height(extreme.height, unit: .metres)).font(TideTypography.chartHeight)
            ).measure(in: layout.size).width
            let width = max(timeWidth, heightWidth)
            let x = layout.clampedLabelX(markerX - width / 2, labelWidth: width)
            return (x...(x + width), markerX)
        }
    }

    /// 5 (labels). In-plot extreme text — time (`.caption2` semibold monospaced,
    /// `sea`) above height (`.caption2` monospaced, `seaSecondary`); pair above
    /// the marker for HW, below for LW; x-clamped to `[0, width − labelWidth]`.
    private func drawExtremeLabels(_ context: inout GraphicsContext, layout: CurveLayout) {
        guard style.showsExtremeLabels else { return }
        for extreme in model.extremes {
            let markerX = layout.x(extreme.time)
            let markerY = layout.y(extreme.height)

            let time = context.resolve(
                Text(TideFormatters.time(extreme.time))
                    .font(TideTypography.chartTime)
                    .foregroundStyle(isVibrant ? Color.white : .sea)
            )
            let height = context.resolve(
                Text(TideFormatters.height(extreme.height, unit: .metres))
                    .font(TideTypography.chartHeight)
                    .foregroundStyle(secondaryColor)
            )
            let timeSize = time.measure(in: layout.size)
            let heightSize = height.measure(in: layout.size)
            let blockHeight = timeSize.height + heightSize.height

            // Stack sits above the HW dot, below the LW ring (3 pt gap past the
            // marker radius), nudged back inside the canvas when it would clip.
            var blockTop: CGFloat
            if extreme.isHigh {
                blockTop = markerY - style.highMarkerRadius - 3 - blockHeight
            } else {
                blockTop = markerY + style.lowMarkerRadius + 3
            }
            blockTop = min(max(blockTop, 0), layout.size.height - blockHeight)

            let timeX = layout.clampedLabelX(markerX - timeSize.width / 2, labelWidth: timeSize.width)
            let heightX = layout.clampedLabelX(markerX - heightSize.width / 2, labelWidth: heightSize.width)
            context.draw(
                time,
                in: CGRect(x: timeX, y: blockTop, width: timeSize.width, height: timeSize.height)
            )
            context.draw(
                height,
                in: CGRect(
                    x: heightX, y: blockTop + timeSize.height,
                    width: heightSize.width, height: heightSize.height
                )
            )
        }
    }

    /// 6. Threshold — 0.75 pt dashed (3/3) `dawn` at `y(threshold)`, tiny
    /// right-aligned value label; region above the line clipped to under-curve
    /// shaded `dawnDim @ 12%` (dropped in accented). App + medium/large only.
    private func drawThreshold(_ context: inout GraphicsContext, layout: CurveLayout) {
        guard style.showsThreshold, let threshold = model.threshold else { return }
        let lineY = layout.y(threshold.height)
        guard lineY >= layout.plotTop, lineY <= layout.plotBottom else { return }

        if !isAccented, let underCurve = underCurvePath(layout: layout) {
            var shading = context
            shading.clip(to: Path(CGRect(x: 0, y: 0, width: layout.size.width, height: lineY)))
            shading.fill(underCurve, with: .color(.dawnDim.opacity(0.12)))
        }

        var line = Path()
        line.move(to: CGPoint(x: 0, y: lineY))
        line.addLine(to: CGPoint(x: layout.size.width, y: lineY))
        context.stroke(
            line,
            with: .color(solarColor),
            style: StrokeStyle(lineWidth: 0.75, dash: [3, 3])
        )

        let label = context.resolve(
            Text(TideFormatters.heightValue(threshold.height, unit: .metres))
                .font(TideTypography.chartHeight)
                .foregroundStyle(solarColor)
        )
        let labelSize = label.measure(in: layout.size)
        context.draw(
            label,
            in: CGRect(
                x: layout.size.width - labelSize.width - 4,
                y: lineY - labelSize.height - 2,
                width: labelSize.width,
                height: labelSize.height
            )
        )
    }

    /// 7 (line). Now marker — 0.75 pt `seaTertiary` vertical, full band height,
    /// at `x(now)` clamped `[1, width − 1]`. Today only.
    private func drawNowLine(_ context: inout GraphicsContext, layout: CurveLayout) {
        guard let now = model.nowInstant else { return }
        let nowX = min(max(layout.x(now), 1), layout.size.width - 1)
        var line = Path()
        line.move(to: CGPoint(x: nowX, y: layout.plotTop))
        line.addLine(to: CGPoint(x: nowX, y: layout.plotBottom))
        context.stroke(line, with: .color(tertiaryColor), lineWidth: 0.75)
    }

    // MARK: Overlay canvas (§4.3 order: curve → markers → now-dot)

    private func drawOverlay(_ context: inout GraphicsContext, layout: CurveLayout) {
        // 3. Curve — polyline (no spline: splines overshoot extremes), round
        //    caps/joins; 2 pt at accessory sizes for vibrancy.
        if let curve = curvePath(layout: layout) {
            context.stroke(
                curve,
                with: .color(inkColor),
                style: StrokeStyle(lineWidth: style.strokeWidth, lineCap: .round, lineJoin: .round)
            )
        }

        // 5. Extreme markers — print-legend convention: HW filled dot, LW open
        //    ring; exact instants/heights so they sit on the curve.
        if style.showsExtremeMarkers {
            for extreme in model.extremes {
                let center = CGPoint(x: layout.x(extreme.time), y: layout.y(extreme.height))
                if extreme.isHigh {
                    let r = style.highMarkerRadius
                    context.fill(
                        Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r)),
                        with: .color(inkColor)
                    )
                } else {
                    let r = style.lowMarkerRadius
                    context.stroke(
                        Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r)),
                        with: .color(inkColor),
                        lineWidth: style.lowMarkerStrokeWidth
                    )
                }
            }
        }

        // 7 (dot). Punch a halo (dotR + 2) with destinationOut — mode-agnostic,
        //    no sky-colored paint — then fill the now-dot normally.
        if let now = model.nowInstant, let currentHeight = model.currentHeight {
            let dotX = min(max(layout.x(now), 1), layout.size.width - 1)
            let center = CGPoint(x: dotX, y: layout.y(currentHeight))
            let haloR = style.nowDotRadius + 2
            var punch = context
            punch.blendMode = .destinationOut
            punch.fill(
                Path(ellipseIn: CGRect(
                    x: center.x - haloR, y: center.y - haloR, width: 2 * haloR, height: 2 * haloR
                )),
                with: .color(.black)
            )
            let r = style.nowDotRadius
            context.fill(
                Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r)),
                with: .color(inkColor)
            )
        }
    }

    // MARK: Shared paths

    /// Open polyline through the 10-min samples (`Path.addLines`).
    private func curvePath(layout: CurveLayout) -> Path? {
        guard model.samples.count > 1 else { return nil }
        let points = model.samples.map {
            CGPoint(x: layout.x($0.time), y: layout.y($0.height))
        }
        var path = Path()
        path.move(to: points[0])
        path.addLines(points)
        return path
    }

    /// Closed region curve → plot-bottom (sea fill + threshold shading).
    private func underCurvePath(layout: CurveLayout) -> Path? {
        guard var path = curvePath(layout: layout),
              let first = model.samples.first, let last = model.samples.last else { return nil }
        path.addLine(to: CGPoint(x: layout.x(last.time), y: layout.plotBottom))
        path.addLine(to: CGPoint(x: layout.x(first.time), y: layout.plotBottom))
        path.closeSubpath()
        return path
    }

    // MARK: Accessibility (§4.5)

    /// "Tide curve for today. High water 14:32, 11.2 metres. … Now 8.4 metres
    /// and rising."
    private var accessibilitySummary: String {
        var parts: [String] = []
        let dayName = model.nowInstant != nil ? "today" : TideFormatters.fullDate(model.day)
        parts.append("Tide curve for \(dayName).")
        for extreme in model.extremes {
            let kind = extreme.isHigh ? "High" : "Low"
            let time = TideFormatters.time(extreme.time)
            let height = TideFormatters.heightValue(extreme.height, unit: .metres)
            parts.append("\(kind) water \(time), \(height) metres.")
        }
        if let height = model.currentHeight, let rising = model.isRising {
            let value = TideFormatters.heightValue(height, unit: .metres)
            parts.append("Now \(value) metres and \(rising ? "rising" : "falling").")
        }
        return parts.joined(separator: " ")
    }
}

/// AXChart audio-graph descriptor: x = time across the day, y = height,
/// data points = the 10-min samples (§4.5).
private struct TideChartDescriptor: AXChartDescriptorRepresentable {
    let model: TideDayModel
    let summary: String

    func makeChartDescriptor() -> AXChartDescriptor {
        let hours = model.bounds.duration / 3600
        let xAxis = AXNumericDataAxisDescriptor(
            title: "Time",
            range: 0...max(hours, 1),
            gridlinePositions: []
        ) { value in
            TideFormatters.time(model.bounds.start.addingTimeInterval(value * 3600))
        }

        let heights = model.samples.map(\.height) + model.extremes.map(\.height)
        let lo = heights.min() ?? 0
        let hi = heights.max() ?? 1
        let yAxis = AXNumericDataAxisDescriptor(
            title: "Height",
            range: lo...max(hi, lo + 0.1),
            gridlinePositions: []
        ) { value in
            "\(TideFormatters.heightValue(value, unit: .metres)) metres"
        }

        let series = AXDataSeriesDescriptor(
            name: "Tide height",
            isContinuous: true,
            dataPoints: model.samples.map {
                AXDataPoint(x: $0.time.timeIntervalSince(model.bounds.start) / 3600, y: $0.height)
            }
        )

        return AXChartDescriptor(
            title: "Tide curve",
            summary: summary,
            xAxis: xAxis,
            yAxis: yAxis,
            series: [series]
        )
    }
}
