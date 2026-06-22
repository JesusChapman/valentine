//  AudioEngine+PlayQueue.swift
//
//  Phase 3: separates the LIBRARY from the PLAY QUEUE, foobar-style.
//
//  Design (additive — does not rename or break existing code):
//    * `queue`            : stays as-is = the LIBRARY (everything you own; persisted).
//    * `playQueue`        : ordered list of Track IDs = what actually plays next.
//    * `playQueuePosition`: index into playQueue of the current track.
//
//  Existing `playTrack(at:)` still works for tapping a library row: we wrap it
//  so that tapping a song builds a play queue from the surrounding context.
//
//  To fully activate, route playback through the play queue by having
//  nextTrack()/previousTrack() consult `playQueue` when it is non-empty
//  (see the INTEGRATION note at the bottom).

import Foundation
import Combine

extension AudioEngine {

    // Backing storage via associated objects so this stays a pure extension.
    // If you prefer, move these two into AudioEngine.swift as @Published stored
    // properties instead (recommended for SwiftUI observation — see note below).
    private static var _playQueueKey = 0
    private static var _playQueuePosKey = 0
    private static var _navAlbumKey = 0

    /// Set to an Album.id to request the library navigate to that album.
    /// LibrarySidebar observes this, switches to the Albums tab, and opens it.
    var navigateToAlbumID: String? {
        get { objc_getAssociatedObject(self, &Self._navAlbumKey) as? String }
        set {
            objc_setAssociatedObject(self, &Self._navAlbumKey, newValue, .OBJC_ASSOCIATION_RETAIN)
            objectWillChange.send()
        }
    }

    /// Open the album of the currently-playing track.
    func openCurrentAlbum() {
        guard let t = currentTrack else { return }
        navigateToAlbumID = "\(t.album ?? "Unknown Album")—\(t.effectiveAlbumArtist)"
    }

    var playQueue: [UUID] {
        get { (objc_getAssociatedObject(self, &Self._playQueueKey) as? [UUID]) ?? [] }
        set {
            objc_setAssociatedObject(self, &Self._playQueueKey, newValue, .OBJC_ASSOCIATION_RETAIN)
            objectWillChange.send()
        }
    }

    var playQueuePosition: Int {
        get { (objc_getAssociatedObject(self, &Self._playQueuePosKey) as? Int) ?? 0 }
        set {
            objc_setAssociatedObject(self, &Self._playQueuePosKey, newValue, .OBJC_ASSOCIATION_RETAIN)
            objectWillChange.send()
        }
    }

    // MARK: - Building the queue

    /// Replace the play queue with the given library indices and start playing.
    func playNow(indices: [Int]) {
        let ids = indices.compactMap { queue.indices.contains($0) ? queue[$0].id : nil }
        guard !ids.isEmpty else { return }
        playQueue = ids
        playQueuePosition = 0
        if let firstIndex = libraryIndex(for: ids[0]) {
            playTrack(at: firstIndex)
        }
    }

    /// Append library indices to the end of the play queue (don't interrupt).
    func enqueue(indices: [Int]) {
        let ids = indices.compactMap { queue.indices.contains($0) ? queue[$0].id : nil }
        guard !ids.isEmpty else { return }
        let wasEmpty = playQueue.isEmpty
        playQueue.append(contentsOf: ids)
        if wasEmpty, currentTrackIndex == nil, let firstIndex = libraryIndex(for: ids[0]) {
            playQueuePosition = 0
            playTrack(at: firstIndex, autoPlay: false)
        }
    }

    /// Insert right after the current track ("Play next").
    func playNext(indices: [Int]) {
        let ids = indices.compactMap { queue.indices.contains($0) ? queue[$0].id : nil }
        guard !ids.isEmpty else { return }
        if playQueue.isEmpty {
            enqueue(indices: indices)
        } else {
            let insertAt = min(playQueuePosition + 1, playQueue.count)
            playQueue.insert(contentsOf: ids, at: insertAt)
        }
    }

    /// Shuffle the given indices into the play queue and start playing.
    func shuffleNow(indices: [Int]) {
        playNow(indices: indices.shuffled())
    }

    // Convenience wrappers for albums/artists.
    func playNow(_ album: Album)   { playNow(indices: album.trackIndices) }
    func enqueue(_ album: Album)   { enqueue(indices: album.trackIndices) }
    func playNext(_ album: Album)  { playNext(indices: album.trackIndices) }
    func shuffle(_ album: Album)   { shuffleNow(indices: album.trackIndices) }
    func playNow(_ a: ArtistGroup) { playNow(indices: a.trackIndices) }
    func enqueue(_ a: ArtistGroup) { enqueue(indices: a.trackIndices) }
    func shuffle(_ a: ArtistGroup) { shuffleNow(indices: a.trackIndices) }

    // MARK: - Helpers

    func libraryIndex(for id: UUID) -> Int? {
        queue.firstIndex(where: { $0.id == id })
    }

    /// Advance using the play queue if one exists. Returns the library index to
    /// play next, or nil if the queue is exhausted.
    func nextFromPlayQueue() -> Int? {
        guard !playQueue.isEmpty else { return nil }
        let next = playQueuePosition + 1
        guard next < playQueue.count else {
            if repeatMode == .all { playQueuePosition = 0; return libraryIndex(for: playQueue[0]) }
            return nil
        }
        playQueuePosition = next
        return libraryIndex(for: playQueue[next])
    }

    func previousFromPlayQueue() -> Int? {
        guard !playQueue.isEmpty, playQueuePosition > 0 else { return nil }
        playQueuePosition -= 1
        return libraryIndex(for: playQueue[playQueuePosition])
    }

    // MARK: - Metadata editing

    /// Apply an edit to the track at `index`: update memory, persist the
    /// library cache, and write tags to the file on disk via mutagen.
    func applyMetadataEdit(_ edit: TrackMetadataEdit, toTrackAt index: Int) {
        guard queue.indices.contains(index) else { return }

        // 1) In-memory update for instant UI feedback.
        var track = queue[index]
        track.title = edit.title
        track.artist = edit.artist
        track.albumArtist = edit.albumArtist.isEmpty ? nil : edit.albumArtist
        track.album = edit.album.isEmpty ? nil : edit.album
        track.genre = edit.genre.isEmpty ? nil : edit.genre
        track.year = Int(edit.year)
        track.trackNumber = Int(edit.trackNumber)
        queue[index] = track

        // 2) Persist the lightweight cache.
        persistLibrary()

        // 3) Write to the actual file.
        let url = track.url
        Task.detached {
            do {
                url.startAccessing()
                defer { url.stopAccessing() }
                try await MetadataWriter.write(to: url, edit: edit)
            } catch {
                print("Metadata write failed: \(error)")
            }
        }
    }

    /// Batch edit: apply only the non-nil fields to every index in `indices`.
    /// Each field left nil is preserved per-track.
    func applyBatchEdit(albumArtist: String?, album: String?, genre: String?,
                        year: String?, indices: [Int]) {
        for index in indices where queue.indices.contains(index) {
            var t = queue[index]
            if let v = albumArtist { t.albumArtist = v.isEmpty ? nil : v }
            if let v = album { t.album = v.isEmpty ? nil : v }
            if let v = genre { t.genre = v.isEmpty ? nil : v }
            if let v = year { t.year = Int(v) }
            queue[index] = t

            // Per-track full edit so MetadataWriter sees every current value.
            let edit = TrackMetadataEdit(
                title: t.title,
                artist: t.artist,
                albumArtist: t.albumArtist ?? "",
                album: t.album ?? "",
                genre: t.genre ?? "",
                year: t.year.map(String.init) ?? "",
                trackNumber: t.trackNumber.map(String.init) ?? ""
            )
            let url = t.url
            Task.detached {
                do {
                    url.startAccessing()
                    defer { url.stopAccessing() }
                    try await MetadataWriter.write(to: url, edit: edit)
                } catch {
                    print("Batch metadata write failed for \(url.lastPathComponent): \(error)")
                }
            }
        }
        persistLibrary()
    }
}

/*
 IMPORTANT — observation:
 Associated objects work, but SwiftUI observes @Published best. For clean
 reactivity, prefer moving these two lines into AudioEngine.swift instead of
 using the associated-object getters/setters above:

     @Published var playQueue: [UUID] = []
     @Published var playQueuePosition: Int = 0

 Then delete the `_playQueueKey`/`_playQueuePosKey` and the computed
 `playQueue`/`playQueuePosition` from this file (keep everything else).

 INTEGRATION — make playback honor the play queue (in AudioEngine.swift):

 In nextTrack(isAutomatic:), at the very top after the `.one` repeat check, add:
     if !shuffleMode, let idx = nextFromPlayQueue() { playTrack(at: idx); return }

 In previousTrack(), after the `currentTime > 3.0` rewind check, add:
     if let idx = previousFromPlayQueue() { playTrack(at: idx); return }

 With these two hooks, the existing shuffle/repeat logic remains the fallback
 for when no explicit play queue is active.
*/
