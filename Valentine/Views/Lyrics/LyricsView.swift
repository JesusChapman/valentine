import SwiftUI

struct LyricsView: View {
    @ObservedObject var engine: AudioEngine
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var appearance = LyricsAppearanceManager.shared
    @ObservedObject private var settings = AppSettings.shared
    
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

    private func neonColor(isDark: Bool) -> Color {
        if appearance.usesAlbumColorForNeon,
           let albumColor = engine.dominantArtworkColor(for: colorScheme) {
            return albumColor
        }
        return appearance.getNeonColor(isDark: isDark)
    }

    private func glowColor(isDark: Bool) -> Color {
        if appearance.usesAlbumColorForGlow,
           let albumColor = engine.dominantArtworkColor(for: colorScheme) {
            return albumColor
        }
        return appearance.getGlowColor(isDark: isDark)
    }

    private func lineOffset(
        for index: Int,
        activeIndex: Int?,
        isActive: Bool,
        transition: LyricsTransitionStyle
    ) -> CGFloat {
        if transition == .slide, let activeIndex {
            return isActive ? 0 : (index < activeIndex ? -transition.inactiveOffset : transition.inactiveOffset)
        }
        if transition == .bounce {
            return isActive ? -6 : transition.inactiveOffset
        }
        return isActive ? 0 : transition.inactiveOffset
    }
    
    var body: some View {
        Group {
            if let track = engine.currentTrack,
               let lyrics = track.lyrics,
               !lyrics.isEmpty {
                GeometryReader { geo in
                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 24) {
                                ForEach(Array(lyrics.enumerated()), id: \.element.id) { index, line in
                                    let isActive = index == activeLineIndex
                                    let transition = appearance.transitionStyle
                                    
                                    let isDark = colorScheme == .dark
                                    Text(line.text.isEmpty ? "♪" : line.text)
                                        .font(.system(size: isActive ? 28 : 22, weight: isActive ? .bold : .medium, design: appearance.getFontDesign(isDark: isDark)))
                                        .foregroundColor((settings.isNeonEffectEnabled && isActive) ? neonColor(isDark: isDark) : appearance.getFontColor(isDark: isDark, isActive: isActive))
                                        .shadow(color: (settings.isNeonEffectEnabled && isActive) ? neonColor(isDark: isDark).opacity(0.8) : .clear, radius: 10, x: 0, y: 0)
                                        .shadow(color: (settings.isNeonEffectEnabled && isActive) ? neonColor(isDark: isDark).opacity(0.4) : .clear, radius: 20, x: 0, y: 0)
                                        .shadow(color: (settings.isGlowEffectEnabled && isActive) ? glowColor(isDark: isDark).opacity(0.8) : .clear, radius: 15, x: 0, y: 0)
                                        .shadow(color: (settings.isGlowEffectEnabled && isActive) ? glowColor(isDark: isDark).opacity(0.5) : .clear, radius: 5, x: 0, y: 0)
                                        .opacity(isActive ? 1 : transition.inactiveOpacity)
                                        .scaleEffect(isActive ? transition.activeScale : transition.inactiveScale, anchor: .leading)
                                        .offset(y: lineOffset(for: index, activeIndex: activeLineIndex, isActive: isActive, transition: transition))
                                        .blur(radius: isActive ? 0 : transition.inactiveBlur)
                                        .multilineTextAlignment(.leading)
                                        .animation(transition.animation, value: activeLineIndex)
                                        .animation(transition.animation, value: appearance.lyricsTransitionStyle)
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
                        .onChange(of: activeLineIndex) { _, newIndex in
                            if let index = newIndex {
                                withAnimation(appearance.transitionStyle.animation) {
                                    proxy.scrollTo(index, anchor: .center)
                                }
                            }
                        }
                        .onChange(of: geo.size) { _, _ in
                            if let index = activeLineIndex {
                                proxy.scrollTo(index, anchor: .center)
                            }
                        }
                        .onAppear {
                            if let index = activeLineIndex {
                                proxy.scrollTo(index, anchor: .center)
                            }
                        }
                    }
                }
                .id(track.id)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "music.mic")
                        .font(.system(size: 64))
                        .foregroundColor(.primary.opacity(0.3))
                    Text("No Lyrics Available")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.primary.opacity(0.5))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
