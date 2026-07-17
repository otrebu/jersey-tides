import SwiftUI

/// Screen 3 — the Settings sheet (design doc §5.3, §7 table 1): one grouped
/// list — Units, Time format, Sun events, Mark a height — plus the About
/// footer with the station line and engine version.
struct SettingsSheet: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Units", selection: $settings.units) {
                        Text("Metres").tag(HeightUnit.metres)
                        Text("Feet").tag(HeightUnit.feet)
                    }
                    Picker("Time format", selection: $settings.timeFormat) {
                        Text("Follow system").tag(TimeFormatOption.system)
                        Text("24-hour").tag(TimeFormatOption.twentyFourHour)
                        Text("12-hour").tag(TimeFormatOption.twelveHour)
                    }
                    Toggle("Sun events", isOn: $settings.sunEvents)
                }
                Section {
                    Toggle("Mark a height", isOn: markEnabled)
                    if let height = settings.markedHeight {
                        Stepper(value: markHeight, in: 0.5...12.0, step: 0.1) {
                            HStack {
                                Text("Height")
                                Spacer()
                                Text(TideFormatters.height(height, unit: .metres))
                                    .monospacedDigit()
                                    .foregroundStyle(.seaSecondary)
                            }
                        }
                        TextField("Name (optional)", text: $settings.markedLabel)
                            .autocorrectionDisabled()
                    }
                } footer: {
                    aboutFooter
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    /// About footer (§5.3) — Meta voice.
    private var aboutFooter: some View {
        Text(
            "Harmonic predictions computed on-device, fitted to Jersey Coastguard (gov.je) tables · Station: \(EngineProvider.engine.stationName) · engine v\(EngineProvider.engine.engineVersion)"
        )
        .metaStyle()
        .padding(.top, 8)
    }

    /// Off / On for the marked height; On restores a sensible default (§7 #4).
    private var markEnabled: Binding<Bool> {
        Binding(
            get: { settings.markedHeight != nil },
            set: { enabled in
                settings.markedHeight = enabled ? (settings.markedHeight ?? 9.5) : nil
            }
        )
    }

    private var markHeight: Binding<Double> {
        Binding(
            get: { settings.markedHeight ?? 9.5 },
            set: { settings.markedHeight = ($0 * 10).rounded() / 10 }
        )
    }
}
