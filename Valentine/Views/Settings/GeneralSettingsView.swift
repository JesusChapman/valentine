import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section(header: Text("Appearance")) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("App Theme")
                    ThemeSelectionView(selection: $settings.appTheme)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mini Player Appearance")
                        .font(.body)
                    Text("Choose an appearance for the mini player.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    LiquidGlassSelectionView(selection: $settings.miniPlayerGlassMode)
                        .padding(.top, 4)
                }
                .padding(.vertical, 8)
            }
            
            Section(header: Text("Synced Lyrics Effects")) {
                Toggle("Glow Effect", isOn: $settings.isGlowEffectEnabled)
                Toggle("Neon Effect", isOn: $settings.isNeonEffectEnabled)
            }
            Section(header: Text("Animated Background")) {
                Toggle("Sync Background with Music", isOn: $settings.musicReactiveBackground)
                Text("Gently animate the album colors with the intensity of the music.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section(header: Text("Stand By")) {
                Toggle("Replace Artwork with Audio Ring", isOn: $settings.standbyAudioRing)
                Text("Show a luminous ring that moves with the music instead of the album artwork.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
