import SwiftUI
import Combine

struct PlayerView: View {
    @ObservedObject var engine: AudioEngine
    @ObservedObject private var favorites = FavoritesStore.shared
    var togglePlaylist: () -> Void
    var isPlaylistVisible: Bool
    var showToggle: Bool

    var body: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)

            Group {
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
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .clipped()
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
                                .foregroundColor(.primary.opacity(0.3))
                        )
                        .layoutPriority(1)
                }
            }
            .id(engine.currentTrack?.id)
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
            .animation(.easeInOut(duration: 0.4), value: engine.currentTrack?.id)

            Spacer(minLength: 0)
            AudirvanaProgressBar(engine: engine)
                .padding(.horizontal, 32)
                .layoutPriority(1)

            VStack(spacing: 4) {
                Text(engine.currentTrack?.title ?? "No Track Selected")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                // Tap artist to open the album in the library.
                Button { engine.openCurrentAlbum() } label: {
                    Text(engine.currentTrack?.artist ?? "Unknown Artist")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)

                if let album = engine.currentTrack?.album, !album.isEmpty {
                    Button { engine.openCurrentAlbum() } label: {
                        Text(album)
                            .font(.subheadline)
                            .foregroundColor(.secondary.opacity(0.8))
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .layoutPriority(1)

            Spacer(minLength: 0)

            PlaybackControlsView(engine: engine)
                .layoutPriority(2)

            Spacer(minLength: 0)

            VolumeControlView(engine: engine)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 32)
                .layoutPriority(2)

            Spacer(minLength: 0)

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
                .buttonStyle(LiquidGlassButtonStyle(cornerRadius: 16, isActive: engine.shuffleMode))
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
                .buttonStyle(LiquidGlassButtonStyle(cornerRadius: 16, isActive: engine.repeatMode != .off))
                .accessibilityLabel("Repeat \(engine.repeatMode == .off ? "Off" : (engine.repeatMode == .one ? "One" : "All"))")

                Spacer()

                if let t = engine.currentTrack {
                    HeartButton(isFavorite: favorites.isFavoriteSong(t)) {
                        favorites.toggleSong(t)
                    }
                    .frame(width: 32, height: 32)
                }

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
            .padding(.bottom, 12)
            .layoutPriority(2)

            Spacer(minLength: 0)
        }
        .safeAreaPadding(.top, 24)
        .safeAreaPadding(.bottom, 16)
    }
}
