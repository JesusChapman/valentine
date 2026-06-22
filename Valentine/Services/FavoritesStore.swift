import Foundation
import Combine

/// Persists favorite songs and albums to UserDefaults.
/// Songs are keyed by file path; albums by their Album.id ("Album—AlbumArtist").
final class FavoritesStore: ObservableObject {
    static let shared = FavoritesStore()

    @Published private(set) var songKeys: Set<String> = []
    @Published private(set) var albumKeys: Set<String> = []

    private let songsKey = "favoriteSongs"
    private let albumsKey = "favoriteAlbums"

    init() {
        songKeys = Set(UserDefaults.standard.stringArray(forKey: songsKey) ?? [])
        albumKeys = Set(UserDefaults.standard.stringArray(forKey: albumsKey) ?? [])
    }

    // MARK: Songs

    func isFavoriteSong(_ track: Track) -> Bool { songKeys.contains(track.url.path) }

    func toggleSong(_ track: Track) {
        let k = track.url.path
        if songKeys.contains(k) { songKeys.remove(k) } else { songKeys.insert(k) }
        UserDefaults.standard.set(Array(songKeys), forKey: songsKey)
    }

    // MARK: Albums

    func isFavoriteAlbum(_ album: Album) -> Bool { albumKeys.contains(album.id) }

    func toggleAlbum(_ album: Album) {
        if albumKeys.contains(album.id) { albumKeys.remove(album.id) } else { albumKeys.insert(album.id) }
        UserDefaults.standard.set(Array(albumKeys), forKey: albumsKey)
    }
}
