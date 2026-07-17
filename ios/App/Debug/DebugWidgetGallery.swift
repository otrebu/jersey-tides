#if DEBUG
import SwiftUI
import WidgetKit

/// `-harness widgets`: renders every widget entry view directly at family size
/// for the (frozen) clock (widgets cannot be scripted onto the sim home
/// screen). Spec: implementation plan §4 "DebugWidgetGallery spec" — frames
/// are iPhone 17 Pro sizes.
///
/// // CHUNK F FILLS THIS — both intent variants per family, error tile rows,
/// `-harness-day <ISO>` + `-harness-mode standard|accented|vibrant` selectors.
struct DebugWidgetGallery: View {
    private let entry = TideEntry.make(at: EngineProvider.clock.now)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                galleryRow("systemSmall — Dial") {
                    DialSmallView(entry: entry).frame(width: 170, height: 170)
                }
                galleryRow("systemMedium — Chart") {
                    ChartMediumView(entry: entry).frame(width: 364, height: 170)
                }
                galleryRow("systemLarge — Chart") {
                    ChartLargeView(entry: entry).frame(width: 364, height: 382)
                }
                galleryRow("accessoryRectangular") {
                    RectAccessoryView(entry: entry).frame(width: 160, height: 72)
                }
                galleryRow("accessoryCircular") {
                    CircularAccessoryView(entry: entry).frame(width: 76, height: 76)
                }
                galleryRow("accessoryInline") {
                    InlineAccessoryView(entry: entry).frame(width: 234, height: 26)
                }
                galleryRow("error tile — systemSmall") {
                    ErrorTileView(family: .systemSmall).frame(width: 170, height: 170)
                }
            }
            .padding(24)
        }
        .background(Color.sky.ignoresSafeArea())
    }

    private func galleryRow(
        _ label: String, @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).metaStyle()
            content()
                .background(Color.sky)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Color.hairline))
        }
    }
}
#endif
