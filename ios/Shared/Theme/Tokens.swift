import SwiftUI
import UIKit

/// Design doc §2 color tokens — code-only, no asset catalogs, no images.
/// Exactly two hues: `sea` (everything tidal) and `dawn` (everything solar),
/// plus the `sky` ground. Dark mode is "night watch": same relationships,
/// background pulled to blue-black (never neutral black).

private func dynamicColor(
    light: UInt32, dark: UInt32, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1
) -> Color {
    Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(rgb: dark, alpha: darkAlpha)
            : UIColor(rgb: light, alpha: lightAlpha)
    })
}

private extension UIColor {
    convenience init(rgb: UInt32, alpha: CGFloat) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: alpha
        )
    }
}

extension Color {
    /// App + widget background (`containerBackground(for: .widget)`). `#F4F6F6` / `#0B1417`.
    static let sky = dynamicColor(light: 0xF4F6F6, dark: 0x0B1417)
    /// Primary text, numerals, curve stroke, HW/LW markers, now-dot. `#102530` / `#E9EFF1`.
    static let sea = dynamicColor(light: 0x102530, dark: 0xE9EFF1)
    /// Labels, dates, heights next to times, swing column, secondary extremes — `sea @ 55%`.
    static let seaSecondary = sea.opacity(0.55)
    /// Now-line, past table rows, de-emphasized metadata — `sea @ 30%`.
    static let seaTertiary = sea.opacity(0.30)
    /// Horizon line, dividers, table rules — `sea @ 14%`.
    static let hairline = sea.opacity(0.14)
    /// Sunrise/sunset ticks + times, threshold line, moon glyphs. `#B97E3D` / `#E2AE6B`.
    static let dawn = dynamicColor(light: 0xB97E3D, dark: 0xE2AE6B)
    /// Threshold over-curve shading, day-length line — `dawn @ 45%`.
    static let dawnDim = dawn.opacity(0.45)
    /// Tomorrow ghost sparkline (systemLarge) — `sea @ 40%`.
    static let ghost = sea.opacity(0.40)
    /// Top stop of the under-curve gradient — `sea @ 8%` (light) / `sea @ 9%` (dark).
    static let seaFillTop = dynamicColor(
        light: 0x102530, dark: 0xE9EFF1, lightAlpha: 0.08, darkAlpha: 0.09
    )
}

/// Gradient tokens.
enum TideGradients {
    /// `seaFill` — vertical gradient under the curve, top → transparent bottom.
    static var seaFill: LinearGradient {
        LinearGradient(
            colors: [.seaFillTop, .seaFillTop.opacity(0)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

/// `ShapeStyle` sugar so call sites can write `.foregroundStyle(.sea)`.
extension ShapeStyle where Self == Color {
    static var sky: Color { .sky }
    static var sea: Color { .sea }
    static var seaSecondary: Color { .seaSecondary }
    static var seaTertiary: Color { .seaTertiary }
    static var hairline: Color { .hairline }
    static var dawn: Color { .dawn }
    static var dawnDim: Color { .dawnDim }
    static var ghost: Color { .ghost }
}
