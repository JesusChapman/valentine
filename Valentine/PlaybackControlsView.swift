import SwiftUI

struct PlaybackControlsView: View {
    @ObservedObject var engine: AudioEngine
    
    var body: some View {
        HStack(spacing: 24) {
            Button(action: {
                engine.previousTrack()
            }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.primary)
                    .frame(width: 43, height: 43)
            }
            .buttonStyle(LiquidGlassButtonStyle(cornerRadius: 21.5, isActive: false))
            
            Button(action: {
                engine.togglePlayback()
            }) {
                Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 25))
                    .foregroundColor(.primary)
                    .frame(width: 58, height: 58)
            }
            .buttonStyle(LiquidGlassButtonStyle(cornerRadius: 29, isActive: engine.isPlaying))
            
            Button(action: {
                engine.nextTrack()
            }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.primary)
                    .frame(width: 43, height: 43)
            }
            .buttonStyle(LiquidGlassButtonStyle(cornerRadius: 21.5, isActive: false))
        }
    }
}
