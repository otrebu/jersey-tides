import SwiftUI
import WidgetKit

/// The §10 degrade tile — `sky` background, eyebrow + one line, nothing else.
/// Accessory variants per spec. Shown whenever `entry.dayModel == nil`.
///
/// // CHUNK D FILLS THIS — final per-family polish.
struct ErrorTileView: View {
    let family: WidgetFamily

    var body: some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("Tides").font(.caption2)
                Text("unavailable").font(.caption2)
            }
        case .accessoryCircular:
            Text("—")
        case .accessoryInline:
            Text("Tides unavailable")
        default:
            VStack(alignment: .leading, spacing: 8) {
                Text("St Helier · Jersey").engravingStyle()
                Text("Tide data unavailable")
                    .tableStyle()
                    .foregroundStyle(.sea)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding()
        }
    }
}
