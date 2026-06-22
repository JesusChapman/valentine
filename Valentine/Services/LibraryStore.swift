import Foundation

/// Persists the library across launches.
///
/// Two things are saved:
///   1. A security-scoped bookmark per file, so a sandboxed app can re-open the
///      same files after relaunch without re-prompting the user.
///   2. Lightweight cached metadata (title/artist/album/duration) so the list
///      can render immediately before AVFoundation re-reads the files.
///
/// NOTE on entitlements: for bookmarks to survive relaunch in a sandboxed app
/// you must enable, in the .entitlements file:
///   com.apple.security.files.user-selected.read-only  = YES
///   com.apple.security.files.bookmarks.app-scope       = YES
/// If the app is NOT sandboxed, plain bookmarks (no .withSecurityScope) are
/// enough; set `useSecurityScope = false` below.

struct PersistedTrack: Codable {
    let bookmark: Data
    let title: String
    let artist: String
    let albumArtist: String?
    let album: String?
    let duration: TimeInterval
    let trackNumber: Int?
    let year: Int?
    let genre: String?
}

enum LibraryStore {
    static let useSecurityScope = false

    private static var storeURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Valentine", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("library.json")
    }

    // MARK: Save

    static func save(_ tracks: [Track]) {
        let persisted: [PersistedTrack] = tracks.compactMap { track in
            guard let bookmark = makeBookmark(for: track.url) else { return nil }
            return PersistedTrack(
                bookmark: bookmark,
                title: track.title,
                artist: track.artist,
                albumArtist: track.albumArtist,
                album: track.album,
                duration: track.duration,
                trackNumber: track.trackNumber,
                year: track.year,
                genre: track.genre
            )
        }
        do {
            let data = try JSONEncoder().encode(persisted)
            try data.write(to: storeURL, options: .atomic)
        } catch {
            print("LibraryStore save failed: \(error)")
        }
    }

    private static func makeBookmark(for url: URL) -> Data? {
        do {
            if useSecurityScope {
                return try url.bookmarkData(options: [.withSecurityScope],
                                           includingResourceValuesForKeys: nil,
                                           relativeTo: nil)
            } else {
                return try url.bookmarkData(options: [],
                                           includingResourceValuesForKeys: nil,
                                           relativeTo: nil)
            }
        } catch {
            print("Bookmark failed for \(url): \(error)")
            return nil
        }
    }

    // MARK: Load

    /// Returns resolved URLs plus their cached metadata. Caller starts
    /// security-scoped access (see `startAccessing`) before playback.
    static func load() -> [(url: URL, cached: PersistedTrack)] {
        guard let data = try? Data(contentsOf: storeURL),
              let persisted = try? JSONDecoder().decode([PersistedTrack].self, from: data)
        else { return [] }

        var results: [(URL, PersistedTrack)] = []
        for entry in persisted {
            var isStale = false
            let options: URL.BookmarkResolutionOptions = useSecurityScope ? [.withSecurityScope] : []
            if let url = try? URL(resolvingBookmarkData: entry.bookmark,
                                  options: options,
                                  relativeTo: nil,
                                  bookmarkDataIsStale: &isStale) {
                results.append((url, entry))
            }
        }
        return results
    }
}

// MARK: - Security-scoped access helpers

extension URL {
    /// Call before reading a bookmarked file; balance with `stopAccessing`.
    @discardableResult
    func startAccessing() -> Bool {
        guard LibraryStore.useSecurityScope else { return true }
        return startAccessingSecurityScopedResource()
    }

    func stopAccessing() {
        guard LibraryStore.useSecurityScope else { return }
        stopAccessingSecurityScopedResource()
    }
}
