import SwiftUI

/// One day's face inside the pager: hero, curve, table, sun row, tomorrow row
/// (design doc §5.1). Non-today pages hero the day's first HW, drop the now
/// marker, and show the `‹ TODAY` return chip.
///
/// // CHUNK C FILLS THIS
struct DayPage: View {
    let model: TideDayModel
    let isToday: Bool

    var body: some View {
        // CHUNK C FILLS THIS
        VStack(alignment: .leading, spacing: 24) {
            Text(TideFormatters.fullDate(model.day)).metaStyle()
            TideCurveView(model: model, style: .app)
                .frame(height: 200)
            ExtremesTable(rows: model.rows, nowInstant: model.nowInstant, units: .metres)
        }
    }
}
