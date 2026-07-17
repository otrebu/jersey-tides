import Foundation

/// `jerseytides://day/<ISO-date>` → pager target; the consumer clamps to
/// ±14 days (design doc §5.4).
///
/// // CHUNK C FILLS THIS
enum DeepLink {
    static let scheme = "jerseytides"

    /// Parses `jerseytides://day/2026-07-17`; nil for anything else.
    static func parse(_ url: URL) -> CalendarDay? {
        nil // CHUNK C FILLS THIS
    }
}
