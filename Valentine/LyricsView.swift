import SwiftUI

struct LyricsView: View {
    @ObservedObject var engine: AudioEngine
    
    private var activeLineIndex: Int? {
        guard let lyrics = engine.currentTrack?.lyrics else { return nil }
        let time = engine.currentTime
        for i in (0..<lyrics.count).reversed() {
            if time >= lyrics[i].time {
                return i
            }
        }
        return nil
    }
    
    var body: some View {
        Group {
            if let lyrics = engine.currentTrack?.lyrics, !lyrics.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 24) {
                            ForEach(Array(lyrics.enumerated()), id: \.element.id) { index, line in
                                let isActive = index == activeLineIndex
                                
                                Text(line.text.isEmpty ? "♪" : line.text)
                                    .font(.system(size: isActive ? 28 : 22, weight: isActive ? .bold : .medium, design: .rounded))
                                    .foregroundColor((engine.isNeonEffectEnabled && isActive) ? .white : (isActive ? .primary : .secondary))
                                    .shadow(color: (engine.isNeonEffectEnabled && isActive) ? .white.opacity(0.8) : .clear, radius: 10, x: 0, y: 0)
                                    .shadow(color: (engine.isNeonEffectEnabled && isActive) ? .white.opacity(0.4) : .clear, radius: 20, x: 0, y: 0)
                                    .shadow(color: (engine.isGlowEffectEnabled && isActive) ? .accentColor.opacity(0.8) : .clear, radius: 15, x: 0, y: 0)
                                    .shadow(color: (engine.isGlowEffectEnabled && isActive) ? .accentColor.opacity(0.5) : .clear, radius: 5, x: 0, y: 0)
                                    .multilineTextAlignment(.leading)
                                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isActive)
                                    .id(index)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        engine.seek(to: line.time)
                                    }
                            }
                        }
                        .padding(.vertical, 120)
                        .padding(.horizontal, 32)
                    }
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: .black, location: 0.15),
                                .init(color: .black, location: 0.85),
                                .init(color: .clear, location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .onChange(of: activeLineIndex) { newIndex in
                        if let index = newIndex {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0)) {
                                proxy.scrollTo(index, anchor: .center)
                            }
                        }
                    }
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "music.mic")
                        .font(.system(size: 64))
                        .foregroundColor(.white.opacity(0.3))
                    Text("No Lyrics Available")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
