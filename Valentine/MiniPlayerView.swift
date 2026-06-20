import SwiftUI

struct MiniPlayerView: View {
    @ObservedObject var engine: AudioEngine
    @State private var showMiniLyrics = false
    @AppStorage("miniPlayerGlassMode") private var miniPlayerGlassMode = 0
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var appearance = LyricsAppearanceManager.shared
    
    private var activeLyricLines: (current: String?, next: String?) {
        guard let lyrics = engine.currentTrack?.lyrics else { return (nil, nil) }
        let time = engine.currentTime
        for i in (0..<lyrics.count).reversed() {
            if time >= lyrics[i].time {
                let current = lyrics[i].text.isEmpty ? "♪" : lyrics[i].text
                let nextText = (i + 1 < lyrics.count) ? lyrics[i + 1].text : nil
                let next = (nextText?.isEmpty == true) ? "♪" : nextText
                return (current, next)
            }
        }
        return (nil, lyrics.first?.text.isEmpty == true ? "♪" : lyrics.first?.text)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        guard time > 0 else { return "0:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 20) {
                if let art = engine.currentTrack?.albumArt {
                    art
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 30))
                                .foregroundColor(.primary.opacity(0.3))
                        )
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(engine.currentTrack?.title ?? "No Track Selected")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            Text(engine.currentTrack?.artist ?? "Unknown")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer(minLength: 16)
                        
                        HStack(spacing: 12) {
                            Button(action: { engine.previousTrack() }) {
                                Image(systemName: "backward.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary)
                                    .frame(width: 24, height: 24)
                            }
                            .buttonStyle(LiquidGlassButtonStyle(cornerRadius: 12, isActive: false))
                            
                            Button(action: { engine.togglePlayback() }) {
                                Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.primary)
                                    .frame(width: 32, height: 32)
                            }
                            .buttonStyle(LiquidGlassButtonStyle(cornerRadius: 16, isActive: engine.isPlaying))
                            
                            Button(action: { engine.nextTrack() }) {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary)
                                    .frame(width: 24, height: 24)
                            }
                            .buttonStyle(LiquidGlassButtonStyle(cornerRadius: 12, isActive: false))
                            
                            Button(action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    showMiniLyrics.toggle()
                                }
                            }) {
                                Image(systemName: "quote.bubble.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary)
                                    .frame(width: 24, height: 24)
                            }
                            .buttonStyle(LiquidGlassButtonStyle(cornerRadius: 12, isActive: showMiniLyrics))
                        }
                    }
                    
                    HStack(spacing: 8) {
                        Text(formatTime(engine.currentTime))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 36, alignment: .trailing)
                        
                        Slider(value: Binding(
                            get: {
                                let validDuration = engine.duration > 0 ? engine.duration : 1
                                return max(0, min(engine.currentTime, validDuration))
                            },
                            set: { engine.seek(to: $0) }
                        ), in: 0...(engine.duration > 0 ? engine.duration : 1))
                        .tint(.primary)
                        .controlSize(.small)
                        
                        Text(formatTime(engine.duration))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 36, alignment: .leading)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            
            if showMiniLyrics {
                VStack(spacing: 4) {
                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.horizontal, 20)
                    
                    VStack(spacing: 8) {
                        let lines = activeLyricLines
                        
                        let isDark = colorScheme == .dark
                        Text(lines.current ?? "♪")
                            .font(.system(size: 18, weight: .bold, design: appearance.getFontDesign(isDark: isDark)))
                            .foregroundColor(engine.isNeonEffectEnabled ? appearance.getNeonColor(isDark: isDark) : appearance.getFontColor(isDark: isDark, isActive: true))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .shadow(color: engine.isNeonEffectEnabled ? appearance.getNeonColor(isDark: isDark).opacity(0.8) : .clear, radius: 6, x: 0, y: 0)
                            .shadow(color: engine.isNeonEffectEnabled ? appearance.getNeonColor(isDark: isDark).opacity(0.4) : .clear, radius: 12, x: 0, y: 0)
                            .shadow(color: engine.isGlowEffectEnabled ? appearance.getGlowColor(isDark: isDark).opacity(0.6) : .clear, radius: 8, x: 0, y: 0)
                            .id("current_" + (lines.current ?? ""))
                            .transition(.push(from: .bottom))
                        
                        if let next = lines.next {
                            Text(next)
                                .font(.system(size: 12, weight: .medium, design: appearance.getFontDesign(isDark: isDark)))
                                .foregroundColor(appearance.getFontColor(isDark: isDark, isActive: false))
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .id("next_" + next)
                                .transition(.push(from: .bottom))
                        }
                    }
                    .frame(height: 60)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: activeLyricLines.current)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(width: 480, height: showMiniLyrics ? 200 : 140)
        .background(
            ZStack {
                if miniPlayerGlassMode == 1 {
                    Color.clear
                        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    Color.clear
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    .blendMode(.overlay)
            )
            .ignoresSafeArea()
        )
    }
}
