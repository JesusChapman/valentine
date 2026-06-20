import SwiftUI

struct VolumeControlView: View {
    @ObservedObject var engine: AudioEngine
    
    var body: some View {
        HStack {
            Image(systemName: "speaker.fill")
                .foregroundColor(.secondary)
                .font(.system(size: 14))
            
            Slider(value: $engine.volume, in: 0...1)
                .tint(.primary)
            
            Image(systemName: "speaker.wave.3.fill")
                .foregroundColor(.secondary)
                .font(.system(size: 14))
        }
    }
}
