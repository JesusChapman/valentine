import SwiftUI

struct PlayerView: View {
    @ObservedObject var engine: AudioEngine
    var togglePlaylist: () -> Void
    var isPlaylistVisible: Bool
    var showToggle: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 8)
            
            if engine.showLyrics {
                LyricsView(engine: engine)
                    .frame(maxWidth: .infinity, minHeight: 160, maxHeight: 325)
                    .layoutPriority(1)
            } else if let art = engine.currentTrack?.albumArt {
                Rectangle()
                    .fill(Color.clear)
                    .frame(minWidth: 160, maxWidth: 325, minHeight: 160, maxHeight: 325)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        art
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 10)
                    .layoutPriority(1)
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .frame(minWidth: 160, maxWidth: 325, minHeight: 160, maxHeight: 325)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 80))
                            .foregroundColor(.white.opacity(0.3))
                    )
                    .layoutPriority(1)
            }
            
            Spacer(minLength: 16)
            
            WaveformView(engine: engine)
                .frame(height: 50)
                .padding(.horizontal, 32)
                .layoutPriority(1)
            
            VStack(spacing: 4) {
                Text(engine.currentTrack?.title ?? "No Track Selected")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(engine.currentTrack?.artist ?? "Unknown Artist")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                if let album = engine.currentTrack?.album, !album.isEmpty {
                    Text(album)
                        .font(.subheadline)
                        .foregroundColor(.secondary.opacity(0.8))
                        .lineLimit(1)
                }
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .layoutPriority(1)
            
            Spacer(minLength: 8)
            
            PlaybackControlsView(engine: engine)
                .layoutPriority(2)
            
            Spacer(minLength: 16)
            
            VolumeControlView(engine: engine)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 32)
                .layoutPriority(2)
            
            Spacer(minLength: 16)
            
            HStack(spacing: 24) {
                Button(action: { /* Toggle Shuffle */ }) {
                    Image(systemName: "shuffle")
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(LiquidGlassButtonStyle(cornerRadius: 16, isActive: false))
                
                Button(action: { /* Toggle Repeat */ }) {
                    Image(systemName: "repeat")
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(LiquidGlassButtonStyle(cornerRadius: 16, isActive: false))
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut) {
                        engine.showLyrics.toggle()
                    }
                }) {
                    Image(systemName: engine.showLyrics ? "quote.bubble.fill" : "quote.bubble")
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(LiquidGlassButtonStyle(cornerRadius: 16, isActive: engine.showLyrics))
                
                Button(action: {
                    engine.showLyricsEditor = true
                }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(LiquidGlassButtonStyle(cornerRadius: 16, isActive: false))
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 12)
            .layoutPriority(2)
            
            Spacer(minLength: 12)
        }
        .safeAreaPadding(.top, 24)
        .safeAreaPadding(.bottom, 16)
    }
}

