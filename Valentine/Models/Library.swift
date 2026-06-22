import Foundation
import SwiftUI

// MARK: - Derived groupings over the track library

struct Album: Identifiable, Hashable {
    let id: String          // stable key: "Album—AlbumArtist"
    let title: String
    let albumArtist: String
    let artwork: Image?
    let year: Int?
    let trackIndices: [Int] // indices into AudioEngine.queue, sorted by track number
    let totalDuration: TimeInterval

    static func == (lhs: Album, rhs: Album) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct ArtistGroup: Identifiable, Hashable {
    let id: String          // album-artist name
    let name: String
    let albumCount: Int
    let trackCount: Int
    let trackIndices: [Int]

    static func == (lhs: ArtistGroup, rhs: ArtistGroup) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension AudioEngine {
    /// Albums grouped by ALBUM ARTIST (not track artist), so compilations and
    /// "feat." tracks stay together. Tracks within an album sort by track number.
    var albums: [Album] {
        let grouped = Dictionary(grouping: queue.indices) { i -> String in
            let t = queue[i]
            return "\(t.album ?? "Unknown Album")—\(t.effectiveAlbumArtist)"
        }
        return grouped.map { key, indices -> Album in
            let sorted = indices.sorted {
                let a = queue[$0].trackNumber ?? Int.max
                let b = queue[$1].trackNumber ?? Int.max
                if a != b { return a < b }
                return $0 < $1
            }
            let first = queue[sorted[0]]
            let total = sorted.reduce(0.0) { $0 + queue[$1].duration }
            return Album(
                id: key,
                title: first.album ?? "Unknown Album",
                albumArtist: first.effectiveAlbumArtist,
                artwork: sorted.compactMap { queue[$0].albumArt }.first,
                year: sorted.compactMap { queue[$0].year }.first,
                trackIndices: sorted,
                totalDuration: total
            )
        }
        .sorted {
            if $0.albumArtist != $1.albumArtist {
                return $0.albumArtist.localizedCaseInsensitiveCompare($1.albumArtist) == .orderedAscending
            }
            return ($0.year ?? 0) < ($1.year ?? 0)
        }
    }

    /// Artists grouped by ALBUM ARTIST.
    var artists: [ArtistGroup] {
        let grouped = Dictionary(grouping: queue.indices) { i in queue[i].effectiveAlbumArtist }
        return grouped.map { name, indices -> ArtistGroup in
            let sorted = indices.sorted()
            let distinctAlbums = Set(sorted.map { queue[$0].album ?? "Unknown Album" })
            return ArtistGroup(
                id: name,
                name: name,
                albumCount: distinctAlbums.count,
                trackCount: sorted.count,
                trackIndices: sorted
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Albums belonging to one artist (for the Roon-style artist detail grid).
    func albums(for artist: ArtistGroup) -> [Album] {
        albums.filter { $0.albumArtist == artist.name }
    }
}
