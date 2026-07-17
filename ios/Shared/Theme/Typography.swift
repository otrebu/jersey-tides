import SwiftUI

/// Design doc §3 named text styles. One family (SF), extreme weight contrast —
/// ultralight dial numerals vs small semibold engraved caps. Heights always
/// one decimal + thin space + small unit; times always tabular figures.
enum TideTypography {
    /// Dial — app next-tide hero. 84 pt ultralight, monospaced digits.
    /// Apply `@ScaledMetric` clamped 64–96 at the call site.
    static func dial(size: CGFloat = 84) -> Font {
        .system(size: size, weight: .ultraLight).monospacedDigit()
    }

    /// Dial-2 — widget heroes: small 40, large 34, medium 28 (thin).
    static func dial2(size: CGFloat) -> Font {
        .system(size: size, weight: .thin).monospacedDigit()
    }

    /// Unit — the `m` in `11.2 m`, `HW`/`LW` prefixes beside dials.
    /// 0.38 × parent size, light, baseline-aligned, `seaSecondary`.
    static func unit(parentSize: CGFloat) -> Font {
        .system(size: parentSize * 0.38, weight: .light)
    }

    /// Engraving base font — case/tracking/color come from `engravingStyle()`.
    static var engraving: Font { .caption2.weight(.semibold) }

    /// Table — extremes rows, times, heights, swing column.
    static var table: Font { .callout.weight(.regular).monospacedDigit() }

    /// Meta — dates, sun row, springs/neaps line, horizon-line label.
    static var meta: Font { .footnote.weight(.regular) }

    /// In-plot chart time label (semibold, monospaced design; TideCurveView only).
    static var chartTime: Font { .caption2.weight(.semibold).monospaced() }

    /// In-plot chart height label (regular, monospaced design; TideCurveView only).
    static var chartHeight: Font { .caption2.monospaced() }
}

extension View {
    /// `ST HELIER · JERSEY`, `NEXT HIGH WATER`, `TODAY`, `TOMORROW` —
    /// uppercase, tracked 1.4, `seaSecondary`.
    func engravingStyle() -> some View {
        font(TideTypography.engraving)
            .textCase(.uppercase)
            .tracking(1.4)
            .foregroundStyle(Color.seaSecondary)
    }

    /// Table voice.
    func tableStyle() -> some View {
        font(TideTypography.table)
    }

    /// Meta voice (default `seaSecondary`).
    func metaStyle(_ color: Color = .seaSecondary) -> some View {
        font(TideTypography.meta).foregroundStyle(color)
    }
}
