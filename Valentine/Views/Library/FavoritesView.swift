import SwiftUI

/// Reusable heart toggle. Filled accent when active.
struct HeartButton: View {
    let isFavorite: Bool
    let action: () -> Void
    var size: CGFloat = 14

    var body: some View {
        Button(action: action) {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.system(size: size))
                .foregroundColor(isFavorite ? .pink : .secondary)
        }
        .buttonStyle(.plain)
    }
}

/// Favorites tab: favorited albums grid + favorited songs list.
struct FavoritesView: View {
    @ObservedObject var engine: AudioEngine
    @ObservedObject private var favorites = FavoritesStore.shared
    @State private var openedAlbum: Album?

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 20)]

    private var favAlbums: [Album] {
        engine.albums.filter { favorites.isFavoriteAlbum($0) }
    }
    private var favSongIndices: [Int] {
        engine.queue.indices.filter { favorites.isFavoriteSong(engine.queue[$0]) }
    }

    var body: some View {
        Group {
            if let album = openedAlbum {
                ScrollView {
                    AlbumDetailView(engine: engine, album: album) {
                        withAnimation(.easeInOut(duration: 0.2)) { openedAlbum = nil }
                    }
                }
            } else {
                ScrollView { content }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Favorites")
                .font(.system(size: 22, weight: .bold))
                .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 6)

            if favAlbums.isEmpty && favSongIndices.isEmpty {
                emptyState
            } else {
                if !favAlbums.isEmpty {
                    sectionTitle("ALBUMS")
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(favAlbums) { album in
                            AlbumTile(album: album) {
                                withAnimation(.easeInOut(duration: 0.2)) { openedAlbum = album }
                            }
                        }
                    }
                    .padding(.horizontal, 20).padding(.bottom, 12)
                }

                if !favSongIndices.isEmpty {
                    sectionTitle("SONGS")
                    LazyVStack(spacing: 0) {
                        ForEach(favSongIndices, id: \.self) { index in
                            HStack(spacing: 10) {
                                SongRow(track: engine.queue[index],
                                        isPlaying: engine.currentTrackIndex == index)
                                HeartButton(isFavorite: true) {
                                    favorites.toggleSong(engine.queue[index])
                                }
                                .padding(.trailing, 12)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                engine.playNow(indices: Array(favSongIndices.drop { $0 != index }))
                            }
                        }
                    }
                    .padding(.horizontal, 12).padding(.bottom, 16)
                }
            }
        }
    }

    private func sectionTitle(_ s: String) -> some View {
        Text(s).font(.system(size: 11, weight: .semibold)).tracking(0.6)
            .foregroundColor(.secondary)
            .padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 6)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "heart")
                .font(.system(size: 40)).foregroundColor(.secondary.opacity(0.5))
            Text("No favorites yet")
                .font(.system(size: 15, weight: .medium)).foregroundColor(.secondary)
            Text("Tap the heart on any song or album to add it here.")
                .font(.system(size: 12)).foregroundColor(.secondary.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}
