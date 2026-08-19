import SwiftUI

/// The extremes table (Almanac graft #3, design doc §5.1; redesign mockup v2
/// `tableEl`): full-bleed rows edge-to-edge — tag (Engraving-cased small) ·
/// time · height · swing — separated by hairline rules, with the **next**
/// extreme carried on a full-bleed `dawn`-tinted highlight band.
///
/// Row emphasis (mockup): on the today page past extremes are `seaTertiary`,
/// the next extreme full `sea` (and highlighted), later-future rows
/// `seaSecondary`. `nowInstant == nil` (a non-today page) renders every row
/// full `sea` — nothing is past or pending, so nothing is dimmed.
struct ExtremesTable: View {
    let rows: [ExtremeRow]
    /// Drives row emphasis + the highlight; nil = non-today page.
    let nowInstant: Date?
    let units: HeightUnit
    /// App-side time format (design doc §7 #2); widgets keep the default.
    var timeFormat: TimeFormatOption = .system
    /// Horizontal inset that re-aligns row content with the page margin after
    /// the parent bleeds the table to the screen edges (mockup `padding 24`).
    var contentInset: CGFloat = 24

    var body: some View {
        VStack(spacing: 0) {
            rule // top rule of the table
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                rowView(index: index, row: row)
                rule // rule under every row (last row gets its bottom rule here)
            }
        }
    }

    /// 0.5 pt full-bleed hairline (mockup `.exrow` border-top / last border-bottom).
    private var rule: some View {
        Rectangle()
            .fill(Color.hairline)
            .frame(height: 0.5)
    }

    private func rowView(index: Int, row: ExtremeRow) -> some View {
        let color = rowColor(index: index)
        return HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(row.extreme.isHigh ? "HW" : "LW")
                .font(TideTypography.engraving)
                .tracking(1.4)
                .foregroundStyle(color)
                .frame(width: 30, alignment: .leading)
            Text(TideFormatters.time(row.extreme.time, format: timeFormat))
                .tableStyle()
                .foregroundStyle(color)
            Spacer(minLength: 8)
            Text(TideFormatters.height(row.extreme.height, unit: units))
                .tableStyle()
                .foregroundStyle(color)
            // Swing sits smaller (Meta) than the emphasized height, per mockup.
            Group {
                if let swing = row.swing {
                    Text("\(swing >= 0 ? "↑" : "↓") \(TideFormatters.heightValue(abs(swing), unit: units))")
                } else {
                    Text("")
                }
            }
            .font(TideTypography.meta)
            .monospacedDigit()
            .foregroundStyle(swingColor(index: index))
            .frame(minWidth: 52, alignment: .trailing)
        }
        .padding(.horizontal, contentInset)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(index == nextIndex ? Color.dawn.opacity(0.10) : Color.clear)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText(for: row))
    }

    /// Index of the first not-yet-past row — the "next" extreme (highlighted).
    private var nextIndex: Int? {
        guard let nowInstant else { return nil }
        return rows.firstIndex { $0.extreme.time >= nowInstant }
    }

    private func rowColor(index: Int) -> Color {
        guard let nowInstant else { return .sea } // non-today: every row full sea
        if rows[index].extreme.time < nowInstant { return .seaTertiary }
        return index == nextIndex ? .sea : .seaSecondary
    }

    /// Swing column stays `seaSecondary` (design doc §5.1) but dims with past rows.
    private func swingColor(index: Int) -> Color {
        guard let nowInstant else { return .seaSecondary }
        return rows[index].extreme.time < nowInstant ? .seaTertiary : .seaSecondary
    }

    private func accessibilityText(for row: ExtremeRow) -> String {
        let kind = row.extreme.isHigh ? "High water" : "Low water"
        let time = TideFormatters.time(row.extreme.time, format: timeFormat)
        let height = TideFormatters.height(row.extreme.height, unit: units)
        let swing = row.swing.map {
            ", \($0 >= 0 ? "up" : "down") \(TideFormatters.heightValue(abs($0), unit: units))"
        } ?? ""
        return "\(kind) \(time), \(height)\(swing)"
    }
}
