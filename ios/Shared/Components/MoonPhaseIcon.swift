import Foundation
import SwiftUI

/// Two-tone moon disc — the Today screen's MOON glyph (design mockup v2
/// `moonSvg`). A dark disc with a hairline limb, overlaid by the lit fraction
/// bounded by the outer limb (a semicircle) and the terminator (a half-ellipse
/// whose x-radius is `r·|2k−1|`): crescent when the terminator bulges into the
/// lit side, gibbous when it bulges into the shadow.
///
/// `illuminatedFraction` is `k` ∈ 0…1 (fraction of the disc lit). `waxing`
/// picks the lit limb (east when waxing, west when waning). Colours derive from
/// the `dawn`/`sea` tokens at the mockup's opacities — no new tokens, so widget
/// rendering is untouched.
struct MoonPhaseIcon: View {
    let illuminatedFraction: Double
    let waxing: Bool
    /// Disc diameter (mockup 20 pt in the row, 13 pt inline).
    var size: CGFloat = 20

    init(illuminatedFraction: Double, waxing: Bool, size: CGFloat = 20) {
        self.illuminatedFraction = illuminatedFraction
        self.waxing = waxing
        self.size = size
    }

    private let lit = Color.dawn.opacity(0.85)
    private let dark = Color.sea.opacity(0.10)

    var body: some View {
        Canvas { context, canvas in
            let r = canvas.width / 2
            let center = CGPoint(x: r, y: r)

            // Shadowed disc + hairline limb.
            let disc = Path(ellipseIn: CGRect(
                x: 0.5, y: 0.5, width: canvas.width - 1, height: canvas.height - 1
            ))
            context.fill(disc, with: .color(dark))
            context.stroke(disc, with: .color(.hairline), lineWidth: 0.75)

            // Lit region.
            let k = CGFloat(min(max(illuminatedFraction, 0), 1))
            context.fill(litPath(radius: r, center: center, k: k, waxing: waxing), with: .color(lit))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    /// Closed lit shape: outer limb semicircle + terminator half-ellipse, per
    /// the mockup's sweep-flag table.
    private func litPath(radius r: CGFloat, center c: CGPoint, k: CGFloat, waxing: Bool) -> Path {
        let top = CGPoint(x: c.x, y: c.y - r)
        let bottom = CGPoint(x: c.x, y: c.y + r)
        let termRx = r * abs(2 * k - 1)
        let gibbous = k > 0.5
        var path = Path()
        path.move(to: top)
        if waxing {
            appendArc(&path, from: top, to: bottom, rx: r, ry: r, sweep: true)          // east limb
            appendArc(&path, from: bottom, to: top, rx: termRx, ry: r, sweep: gibbous)  // terminator
        } else {
            appendArc(&path, from: top, to: bottom, rx: r, ry: r, sweep: false)         // west limb
            appendArc(&path, from: bottom, to: top, rx: termRx, ry: r, sweep: !gibbous)
        }
        path.closeSubpath()
        return path
    }

    /// Appends an SVG endpoint-form elliptical arc (x-axis-rotation 0, large-arc
    /// false) as a polyline — enough fidelity for a glyph, and it honours the
    /// sweep flag regardless of travel direction (SVG spec F.6.5).
    private func appendArc(
        _ path: inout Path, from p0: CGPoint, to p1: CGPoint,
        rx: CGFloat, ry: CGFloat, sweep: Bool, segments: Int = 24
    ) {
        var rx = max(rx, 0.0001)
        var ry = max(ry, 0.0001)
        let dx = (p0.x - p1.x) / 2      // primed coords (rotation 0)
        let dy = (p0.y - p1.y) / 2
        let lambda = (dx * dx) / (rx * rx) + (dy * dy) / (ry * ry)
        if lambda > 1 { let scale = sqrt(lambda); rx *= scale; ry *= scale }

        let sign: CGFloat = sweep ? -1 : 1      // largeArc(false) != sweep
        var numerator = rx * rx * ry * ry - rx * rx * dy * dy - ry * ry * dx * dx
        let denominator = rx * rx * dy * dy + ry * ry * dx * dx
        if numerator < 0 { numerator = 0 }
        let coef = denominator == 0 ? 0 : sign * sqrt(numerator / denominator)
        let cxp = coef * (rx * dy / ry)
        let cyp = coef * (-ry * dx / rx)
        let cx = cxp + (p0.x + p1.x) / 2
        let cy = cyp + (p0.y + p1.y) / 2

        func angle(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
            let dot = ux * vx + uy * vy
            let len = sqrt((ux * ux + uy * uy) * (vx * vx + vy * vy))
            var a = acos(min(max(len == 0 ? 1 : dot / len, -1), 1))
            if ux * vy - uy * vx < 0 { a = -a }
            return a
        }
        let ux = (dx - cxp) / rx, uy = (dy - cyp) / ry
        let vx = (-dx - cxp) / rx, vy = (-dy - cyp) / ry
        let theta1 = angle(1, 0, ux, uy)
        var sweepAngle = angle(ux, uy, vx, vy)
        if !sweep, sweepAngle > 0 { sweepAngle -= 2 * .pi }
        if sweep, sweepAngle < 0 { sweepAngle += 2 * .pi }

        for i in 0...segments {
            let t = CGFloat(i) / CGFloat(segments)
            let a = theta1 + sweepAngle * t
            path.addLine(to: CGPoint(x: cx + rx * cos(a), y: cy + ry * sin(a)))
        }
    }
}

/// The MOON row: glyph, "MOON" label, phase name, and "NN% lit" (design mockup
/// v2 `moonEl`). Meta voice; Dynamic Type friendly.
struct MoonPhaseRow: View {
    let name: String
    let illuminatedFraction: Double
    let waxing: Bool

    init(name: String, illuminatedFraction: Double, waxing: Bool) {
        self.name = name
        self.illuminatedFraction = illuminatedFraction
        self.waxing = waxing
    }

    private var percentLit: Int { Int((illuminatedFraction * 100).rounded()) }

    var body: some View {
        HStack(spacing: 10) {
            MoonPhaseIcon(illuminatedFraction: illuminatedFraction, waxing: waxing)
            Text("Moon").engravingStyle()
            Text(name).font(TideTypography.meta).foregroundStyle(.sea)
            Spacer(minLength: 8)
            Text("\(percentLit)% lit")
                .font(TideTypography.meta)
                .monospacedDigit()
                .foregroundStyle(.seaSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Moon, \(name), \(percentLit) percent lit")
    }
}

#Preview("Moon phases") {
    VStack(alignment: .leading, spacing: 16) {
        MoonPhaseRow(name: "Waxing Crescent", illuminatedFraction: 0.18, waxing: true)
        MoonPhaseRow(name: "First Quarter", illuminatedFraction: 0.50, waxing: true)
        MoonPhaseRow(name: "Waxing Gibbous", illuminatedFraction: 0.72, waxing: true)
        MoonPhaseRow(name: "Full Moon", illuminatedFraction: 0.99, waxing: true)
        MoonPhaseRow(name: "Waning Gibbous", illuminatedFraction: 0.68, waxing: false)
        MoonPhaseRow(name: "Last Quarter", illuminatedFraction: 0.50, waxing: false)
        MoonPhaseRow(name: "Waning Crescent", illuminatedFraction: 0.22, waxing: false)
    }
    .padding()
    .background(Color.sky)
}

#Preview("Moon disc sizes") {
    HStack(spacing: 16) {
        MoonPhaseIcon(illuminatedFraction: 0.18, waxing: true, size: 44)
        MoonPhaseIcon(illuminatedFraction: 0.72, waxing: true, size: 44)
        MoonPhaseIcon(illuminatedFraction: 0.50, waxing: false, size: 44)
        MoonPhaseIcon(illuminatedFraction: 0.30, waxing: false, size: 44)
    }
    .padding()
    .background(Color.sky)
    .preferredColorScheme(.dark)
}
