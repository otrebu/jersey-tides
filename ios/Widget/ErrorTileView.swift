import SwiftUI
import WidgetKit

/// The §10 degrade tile — `sky` background, eyebrow + one line, nothing else.
/// Shown whenever `entry.dayModel == nil`; the owning timeline retries in
/// 15 min (`EntryPlanner.errorReloadDate`).
struct ErrorTileView: View {
    let family: WidgetFamily

    var body: some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("Tides").font(.caption2)
                Text("unavailable").font(.caption2).foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Tides unavailable")
        case .accessoryCircular:
            // Em-dash in place of the gauge value.
            Text("—")
                .font(.title3.weight(.medium))
                .accessibilityLabel("Tides unavailable")
        case .accessoryInline:
            Text("Tides unavailable")
        default:
            // All system families: eyebrow + one Table-voice line on `sky`.
            VStack(alignment: .leading, spacing: 8) {
                Text("St Helier · Jersey").engravingStyle()
                Text("Tide data unavailable")
                    .tableStyle()
                    .foregroundStyle(Color.sea)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("St Helier, Jersey. Tide data unavailable.")
        }
    }
}
