import SwiftUI
import Combine

/// Audirvana-style bottom transport bar: three zones —
/// left identity (art + title/artist/album + heart), center controls with the
/// progress bar directly underneath, right volume + extras.
struct BottomBarView: View {
    @ObservedObject var engine: AudioEngine
    @ObservedObject private var favorites = FavoritesStore.shared
    var onExpand: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            leftIdentity
                .frame(width: 260, alignment: .leading)

            Spacer(minLength: 12)

            centerControls
                .frame(maxWidth: 460)

            Spacer(minLength: 12)

            rightControls
                .frame(width: 200, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(Divider(), alignment: .top)
    }

    // MARK: Left — now-playing identity

    private var leftIdentity: some View {
        HStack(spacing: 12) {
            Button(action: onExpand) {
                AlbumArtView(image: engine.currentTrack?.albumArt, size: 50, corner: 6)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Button { engine.openCurrentAlbum() } label: {
                    Text(engine.currentTrack?.title ?? "Not Playing")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary).lineLimit(1)
                }.buttonStyle(.plain)

                Button { engine.openCurrentAlbum() } label: {
                    Text(engine.currentTrack?.artist ?? "—")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary).lineLimit(1)
                }.buttonStyle(.plain)

                if let album = engine.currentTrack?.album, !album.isEmpty {
                    Text(album)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.7)).lineLimit(1)
                }
            }

            if let t = engine.currentTrack {
                HeartButton(isFavorite: favorites.isFavoriteSong(t)) {
                    favorites.toggleSong(t)
                }
            }
        }
    }

    // MARK: Center — controls + progress underneath

    private var centerControls: some View {
        VStack(spacing: 4) {
            PlaybackControlsView(engine: engine)
            AudirvanaProgressBar(engine: engine)
        }
    }

    // MARK: Right — volume + lyrics

    private var rightControls: some View {
        HStack(spacing: 12) {
            Spacer()
            VolumeControlView(engine: engine)
                .frame(width: 110)
            Button {
                withAnimation(.easeInOut) { engine.showLyrics.toggle() }
            } label: {
                Image(systemName: engine.showLyrics ? "quote.bubble.fill" : "quote.bubble")
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
        }
    }
}
