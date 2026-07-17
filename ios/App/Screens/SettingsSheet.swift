import SwiftUI

/// Screen 3 — the Settings sheet (design doc §5.3, §7 app side): grouped list
/// (Units, Time format, Sun events, Mark a height) + About footer with the
/// station line and engine version.
///
/// // CHUNK C FILLS THIS
struct SettingsSheet: View {
    var body: some View {
        // CHUNK C FILLS THIS
        Form {
            Section {
                Text("Chunk C fills this sheet").metaStyle()
            } footer: {
                Text(
                    "Harmonic predictions computed on-device · Station: \(EngineProvider.engine.stationName) · engine \(EngineProvider.engine.engineVersion)"
                )
                .metaStyle()
            }
        }
    }
}
