import Foundation

/// Pure entry planning for widget timelines (design doc §9): :00/:30 grid
/// across the local day + exact extreme instants + sunrise/sunset + 6-entry
/// hourly slack tail past next midnight, deduped within 90 s of grid entries.
/// Budget: 40–70 entries/day (≈ 58–62 typical).
///
/// // CHUNK D FILLS THIS
enum EntryPlanner {
    /// All entry instants for the local day containing `now`, sorted ascending.
    static func planEntries(day: CalendarDay, engine: any TideEngine, now: Date) -> [Date] {
        // CHUNK D FILLS THIS — placeholder returns a single instant.
        [now]
    }
}
