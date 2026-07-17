import SwiftUI

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
    /// systemLarge — labeled horizon, sun ticks + times.
    static let large = CurveStyle(
        insets: .init(top: 22, bottom: 20), strokeWidth: 1.5,
        showsHorizonLine: true, showsHorizonLabel: true,
        showsSunTicks: true, showsSunTimes: true,
        showsExtremeLabels: true, showsExtremeMarkers: true
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

/// The shared day-curve renderer (design doc §4): two stacked Canvases —
/// base (fill, horizon, sun, labels, now-line, threshold) + `.widgetAccentable()`
/// overlay (curve stroke, HW/LW markers, punch-out now-dot) — fed by one
/// `CurveLayout` so positions can never disagree.
///
/// // CHUNK B FILLS THIS — placeholder body.
struct TideCurveView: View {
    let model: TideDayModel
    let style: CurveStyle

    init(model: TideDayModel, style: CurveStyle) {
        self.model = model
        self.style = style
    }

    var body: some View {
        // CHUNK B FILLS THIS (two-Canvas renderer per design doc §4.1–4.3)
        ZStack {
            Rectangle().fill(TideGradients.seaFill)
            Rectangle().fill(Color.hairline).frame(height: 0.5)
            Text("Tide curve").engravingStyle()
        }
    }
}
