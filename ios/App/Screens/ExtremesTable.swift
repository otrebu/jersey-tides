import SwiftUI

/// The 4-column extremes table (Almanac graft #3, design doc §5.1):
/// tag · time · height · swing, hairline rules, heights right-aligned tabular.
/// Row emphasis: past `seaTertiary`, next full `sea`, later `seaSecondary`.
///
/// // CHUNK C FILLS THIS — placeholder rows.
struct ExtremesTable: View {
    let rows: [ExtremeRow]
    /// Drives row emphasis; nil = non-today page (all rows secondary).
    let nowInstant: Date?
    let units: HeightUnit

    var body: some View {
        // CHUNK C FILLS THIS
        VStack(alignment: .leading, spacing: 8) {
            ForEach(rows, id: \.extreme) { row in
                HStack(spacing: 16) {
                    Text(row.extreme.isHigh ? "HW" : "LW").engravingStyle()
                    Text(TideFormatters.time(row.extreme.time)).tableStyle()
                    Spacer()
                    Text(TideFormatters.heightValue(row.extreme.height, unit: units))
                        .tableStyle()
                    if let swing = row.swing {
                        Text(TideFormatters.swing(swing))
                            .tableStyle()
                            .foregroundStyle(.seaSecondary)
                    }
                }
                .foregroundStyle(.sea)
            }
        }
    }
}
