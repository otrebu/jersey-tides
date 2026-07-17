import SwiftUI

/// Screen 2 — the Fortnight sheet (design doc §5.2): 14 rows (today + 13),
/// compact extremes, 3 pt range bars on a fixed 12.5 m scale, moon-event
/// glyphs (Almanac graft #5c), tap-to-page.
///
/// // CHUNK C FILLS THIS
struct FortnightSheet: View {
    let startDay: CalendarDay
    /// Dismiss + page Today to the tapped day.
    let onSelect: (CalendarDay) -> Void

    var body: some View {
        // CHUNK C FILLS THIS
        List(0..<14, id: \.self) { offset in
            let day = TideTime.addDays(startDay, offset)
            Button {
                onSelect(day)
            } label: {
                Text(TideFormatters.shortDate(day)).metaStyle()
            }
        }
    }
}
