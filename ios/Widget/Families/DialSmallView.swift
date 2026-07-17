import SwiftUI
import WidgetKit

/// systemSmall "the dial" — typography only, no curve (design doc §6).
///
/// Honors `config.emphasis` (Next tide / Now) + `config.units`. Rendering-mode
/// contract §2.1: the hero (time or level + arrow) is the only accent group;
/// no `dawn` element exists at this size, so accented mode needs no swaps.
struct DialSmallView: View {
    let entry: TideEntry

    /// Dial-2 hero (§3): 40 pt thin, monospaced digits.
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 40
    /// The 17 pt light height line under the hero (§6).
    @ScaledMetric(relativeTo: .body) private var subheroSize: CGFloat = 17

    private var units: HeightUnit { entry.config.units }

    var body: some View {
        Group {
            if let model = entry.dayModel {
                dial(model)
            } else {
                ErrorTileView(family: .systemSmall)
            }
        }
        .containerBackground(Color.sky, for: .widget)
        .widgetURL(entry.dayModel?.day.deepLinkURL)
    }

    // MARK: Layout

    private func dial(_ model: TideDayModel) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("St Helier").engravingStyle()
            Spacer(minLength: 2)
            switch entry.config.emphasis {
            case .nextTide: nextTideHero(model)
            case .now: nowHero(model)
            }
            Spacer(minLength: 2)
            // The horizon, quoted: full-width hairline above the footer.
            Rectangle().fill(Color.hairline).frame(height: 0.5)
            footer(model)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WidgetVoice.summary(model, units: units))
    }

    /// Default emphasis: `HW` eyebrow · 40 pt thin time · 17 pt light height.
    @ViewBuilder
    private func nextTideHero(_ model: TideDayModel) -> some View {
        if let next = model.nextExtreme {
            VStack(alignment: .leading, spacing: 0) {
                Text(next.isHigh ? "HW" : "LW")
                    .font(TideTypography.unit(parentSize: heroSize))
                    .foregroundStyle(.seaSecondary)
                Text(TideFormatters.time(next.time))
                    .font(TideTypography.dial2(size: heroSize))
                    .foregroundStyle(.sea)
                    .contentTransition(.numericText())
                    .widgetAccentable()
                Text(TideFormatters.height(next.height, unit: units))
                    .font(.system(size: subheroSize, weight: .light))
                    .foregroundStyle(.seaSecondary)
            }
        }
    }

    /// `Now` emphasis (§6): current level 40 pt thin + arrow as hero —
    /// both accentable.
    @ViewBuilder
    private func nowHero(_ model: TideDayModel) -> some View {
        if let height = model.currentHeight {
            VStack(alignment: .leading, spacing: 0) {
                Text("NOW")
                    .font(TideTypography.unit(parentSize: heroSize))
                    .foregroundStyle(.seaSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(TideFormatters.heightValue(height, unit: units))
                        .font(TideTypography.dial2(size: heroSize))
                        .foregroundStyle(.sea)
                        .contentTransition(.numericText())
                        .widgetAccentable()
                    Text(TideFormatters.unitSymbol(units))
                        .font(TideTypography.unit(parentSize: heroSize))
                        .foregroundStyle(.seaSecondary)
                    if let rising = model.isRising {
                        Image(systemName: WidgetVoice.arrowSymbol(rising: rising))
                            .font(.system(size: heroSize * 0.45))
                            .imageScale(.small)
                            .foregroundStyle(.sea)
                            .widgetAccentable()
                    }
                }
            }
        }
    }

    /// Footnote now+next line under the quoted horizon.
    private func footer(_ model: TideDayModel) -> some View {
        Group {
            switch entry.config.emphasis {
            case .nextTide: nowAndNextLine(model)
            case .now: extremesLine(model)
            }
        }
        .font(.footnote.monospacedDigit())
        .foregroundStyle(.seaSecondary)
        .lineLimit(1)
        .minimumScaleFactor(0.85)
    }

    /// `now 8.4 ▲ · LW 20:48` — arrow is an SF symbol, never a text glyph (§3).
    private func nowAndNextLine(_ model: TideDayModel) -> Text {
        var text = Text(verbatim: "")
        if let height = model.currentHeight {
            text = Text("now \(TideFormatters.heightValue(height, unit: units))")
            if let rising = model.isRising {
                text = text + Text(verbatim: " ")
                    + Text(Image(systemName: WidgetVoice.arrowSymbol(rising: rising)))
                        .font(.system(size: 8))
            }
        }
        if let following = model.followingExtreme {
            let tag = following.isHigh ? "HW" : "LW"
            text = text + Text(" · \(tag) \(TideFormatters.time(following.time))")
        }
        return text
    }

    /// `HW 14:32 · LW 20:48` — Now-emphasis footer: the next two extremes.
    private func extremesLine(_ model: TideDayModel) -> Text {
        let parts = [model.nextExtreme, model.followingExtreme]
            .compactMap { $0 }
            .map { "\($0.isHigh ? "HW" : "LW") \(TideFormatters.time($0.time))" }
        return Text(parts.joined(separator: " · "))
    }
}

// MARK: - Shared VoiceOver + symbol fragments (all widget families, §6)

/// Spoken fragments composed from data — "High water 14:32, 11.2 metres.
/// Tide rising, 8.4 metres."
enum WidgetVoice {
    static func arrowSymbol(rising: Bool) -> String {
        rising ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill"
    }

    static func spokenHeight(_ metres: Double, unit: HeightUnit) -> String {
        "\(TideFormatters.heightValue(metres, unit: unit)) \(unit == .feet ? "feet" : "metres")"
    }

    static func spokenExtreme(_ extreme: TideExtreme, unit: HeightUnit) -> String {
        "\(extreme.isHigh ? "High water" : "Low water") \(TideFormatters.time(extreme.time)), "
            + "\(spokenHeight(extreme.height, unit: unit))."
    }

    static func spokenTrend(_ height: Double, rising: Bool, unit: HeightUnit) -> String {
        "Tide \(rising ? "rising" : "falling"), \(spokenHeight(height, unit: unit))."
    }

    /// Next extreme + current trend — the §6 default widget label.
    static func summary(_ model: TideDayModel, units: HeightUnit) -> String {
        var parts: [String] = []
        if let next = model.nextExtreme {
            parts.append(spokenExtreme(next, unit: units))
        }
        if let height = model.currentHeight, let rising = model.isRising {
            parts.append(spokenTrend(height, rising: rising, unit: units))
        }
        return parts.isEmpty ? "Tide data unavailable" : parts.joined(separator: " ")
    }
}
