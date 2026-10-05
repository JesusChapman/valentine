import SwiftUI

struct PlayerView: View {
    @ObservedObject var engine: AudioEngine
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.colorScheme) private var colorScheme
    var togglePlaylist: () -> Void
    var isPlaylistVisible: Bool
    var showToggle: Bool

    private var activeControlTint: Color {
        engine.activeControlTint(for: colorScheme)
    }
    
    var body: some View {
        GeometryReader { proxy in
            let bottomControlsHeight: CGFloat = 280
            let bottomPadding: CGFloat = 28
            let topPadding: CGFloat = 12
            let artworkControlsGap: CGFloat = 16
            let availableHeight = max(proxy.size.height - bottomControlsHeight - bottomPadding - topPadding - artworkControlsGap, 100)
            let availableWidth = max(proxy.size.width - 48, 100)
            let ringSide = max(min(min(availableWidth, availableHeight), 480), 100)
            let artworkSide = max(min(min(availableWidth, availableHeight), 325), 100)

            VStack(spacing: 0) {
                // Visual slot (Ring, Artwork, Lyrics)
                Group {
                    if engine.showLyrics {
                        LyricsView(engine: engine)
                            .frame(maxWidth: .infinity, maxHeight: availableHeight)
                    } else if settings.mainPlayerAudioRing {
                        StandbyAudioRingView(engine: engine, tintColorScheme: colorScheme)
                            .frame(width: ringSide, height: ringSide)
                    } else if let art = engine.currentTrack?.albumArt {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: artworkSide, height: artworkSide)
                            .overlay(
                                art
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .clipped()
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 10)
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .frame(width: artworkSide, height: artworkSide)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: min(artworkSide * 0.25, 80)))
                                    .foregroundColor(.primary.opacity(0.3))
                            )
                    }
                }
                .id(engine.currentTrack?.id)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .animation(.easeInOut(duration: 0.4), value: engine.currentTrack?.id)
                .frame(maxWidth: .infinity, maxHeight: availableHeight, alignment: .bottom)

                Spacer()
                    .frame(height: artworkControlsGap)

                // Controls area
                VStack(spacing: 8) {
                    WaveformView(engine: engine)
                        .frame(height: 50)
                        .padding(.horizontal, 32)
                    
                    VStack(spacing: 2) {
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
                    
                    Spacer(minLength: 4)
                    
                    PlaybackControlsView(engine: engine)
                    
                    Spacer(minLength: 4)
                    
                    VolumeControlView(engine: engine)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 32)
                    
                    Spacer(minLength: 4)
                    
                    HStack(spacing: 24) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                engine.shuffleMode.toggle()
                            }
                        }) {
                            Image(systemName: "shuffle")
                                .font(.system(size: 14))
                                .foregroundColor(engine.shuffleMode ? .primary : .primary.opacity(0.4))
                                .frame(width: 32, height: 32)
                        }
                        .contentTransition(.symbolEffect(.replace))
                        .buttonStyle(LiquidGlassButtonStyle(
                            cornerRadius: 16,
                            isActive: engine.shuffleMode,
                            activeTint: activeControlTint
                        ))
                        .accessibilityLabel(engine.shuffleMode ? "Shuffle On" : "Shuffle Off")
                        
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                switch engine.repeatMode {
                                case .off: engine.repeatMode = .one
                                case .one: engine.repeatMode = .all
                                case .all: engine.repeatMode = .off
                                }
                            }
                        }) {
                            Group {
                                if engine.repeatMode == .one {
                                    Image(systemName: "repeat.1")
                                        .foregroundColor(.primary)
                                } else if engine.repeatMode == .all {
                                    Image(systemName: "repeat")
                                        .foregroundColor(.primary)
                                } else {
                                    Image(systemName: "repeat")
                                        .foregroundColor(.primary.opacity(0.4))
                                }
                            }
                            .font(.system(size: 14))
                            .frame(width: 32, height: 32)
                        }
                        .contentTransition(.symbolEffect(.replace))
                        .buttonStyle(LiquidGlassButtonStyle(
                            cornerRadius: 16,
                            isActive: engine.repeatMode != .off,
                            activeTint: activeControlTint
                        ))
                        .accessibilityLabel("Repeat \(engine.repeatMode == .off ? "Off" : (engine.repeatMode == .one ? "One" : "All"))")
                        
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
                        .buttonStyle(LiquidGlassButtonStyle(
                            cornerRadius: 16,
                            isActive: engine.showLyrics,
                            activeTint: activeControlTint
                        ))
                        .accessibilityLabel(engine.showLyrics ? "Hide Lyrics" : "Show Lyrics")
                        
                        Button(action: {
                            engine.checkAndShowLyricsEditor()
                        }) {
                            Image(systemName: "pencil")
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(LiquidGlassButtonStyle(cornerRadius: 16, isActive: false))
                        .accessibilityLabel("Edit Lyrics")
                    }
                    .padding(.horizontal, 40)
                }
                .frame(height: bottomControlsHeight)
            }
            .padding(.top, topPadding)
            .padding(.bottom, bottomPadding)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}
