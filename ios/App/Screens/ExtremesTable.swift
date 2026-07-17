import SwiftUI

/// The 4-column extremes table (Almanac graft #3, design doc §5.1):
/// tag (Engraving-cased small) · time · height · swing, hairline rules between
/// rows, heights right-aligned tabular.
///
/// Row emphasis (design doc §5.1): past extremes `seaTertiary`, the **next**
/// extreme full `sea`, later-future rows `seaSecondary`. `nowInstant == nil`
/// (non-today page) renders every row `seaSecondary`.
struct ExtremesTable: View {
    let rows: [ExtremeRow]
    /// Drives row emphasis; nil = non-today page (all rows secondary).
    let nowInstant: Date?
    let units: HeightUnit
    /// App-side time format (design doc §7 #2); widgets keep the default.
    var timeFormat: TimeFormatOption = .system

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index > 0 {
                    Rectangle()
                        .fill(Color.hairline)
                        .frame(height: 0.5)
                        .gridCellUnsizedAxes(.horizontal)
                }
                let color = rowColor(index: index)
                GridRow {
                    Text(row.extreme.isHigh ? "HW" : "LW")
                        .font(TideTypography.engraving)
                        .tracking(1.4)
                        .foregroundStyle(color)
                    Text(TideFormatters.time(row.extreme.time, format: timeFormat))
                        .tableStyle()
                        .foregroundStyle(color)
                    Text(TideFormatters.heightValue(row.extreme.height, unit: units))
                        .tableStyle()
                        .gridColumnAlignment(.trailing)
                        .foregroundStyle(color)
                    if let swing = row.swing {
                        // Text arrow + magnitude, converted with the height unit.
                        Text("\(swing >= 0 ? "↑" : "↓") \(TideFormatters.heightValue(abs(swing), unit: units))")
                            .tableStyle()
                            .gridColumnAlignment(.trailing)
                            .foregroundStyle(swingColor(index: index))
                    } else {
                        Text("")
                    }
                }
                .padding(.vertical, 8)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(accessibilityText(for: row))
            }
        }
    }

    /// Index of the first not-yet-past row — the "next" extreme.
    private var nextIndex: Int? {
        guard let nowInstant else { return nil }
        return rows.firstIndex { $0.extreme.time >= nowInstant }
    }

    private func rowColor(index: Int) -> Color {
        guard let nowInstant else { return .seaSecondary }
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
