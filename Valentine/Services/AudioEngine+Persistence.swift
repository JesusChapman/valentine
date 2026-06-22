//  AudioEngine+Persistence.swift
//
//  Wires LibraryStore into AudioEngine. Add the three calls noted at the
//  bottom into your EXISTING AudioEngine.swift — the rest can live here.

import Foundation
import AVFoundation

extension AudioEngine {

    /// Save the current library. Call whenever `queue` changes
    /// (after addTracks, removeTrack, removeTracks, clearPlaylist).
    func persistLibrary() {
        LibraryStore.save(queue)
    }

    /// Restore the saved library at launch. Renders cached metadata
    /// immediately, then refreshes full metadata/artwork in the background.
    func restoreLibrary() {
        let entries = LibraryStore.load()
        guard !entries.isEmpty else { return }

        // 1) Fast path: build tracks from cached metadata so the UI populates now.
        var restored: [Track] = []
        for (url, cached) in entries {
            url.startAccessing()              // keep scope open for the session
            var track = Track(url: url)
            track.title = cached.title
            track.artist = cached.artist
            track.albumArtist = cached.albumArtist
            track.album = cached.album
            track.duration = cached.duration
            track.trackNumber = cached.trackNumber
            track.year = cached.year
            track.genre = cached.genre
            restored.append(track)
        }
        self.queue = restored
        if self.currentTrackIndex == nil && !restored.isEmpty {
            self.playTrack(at: 0, autoPlay: false)
        }

        // 2) Slow path: re-read artwork + lyrics that aren't cached.
        Task {
            for i in self.queue.indices {
                var track = self.queue[i]
                await track.loadMetadata()
                if self.queue.indices.contains(i) {
                    self.queue[i] = track
                }
            }
        }
    }
}

/*
 INTEGRATION — three edits inside the existing AudioEngine.swift:

 1. In `init()`, after setup, add:
        restoreLibrary()

 2. At the end of `addTracks(_:)` (inside the Task, after the loop and the
    currentTrackIndex check), add:
        persistLibrary()

 3. At the end of `removeTrack(at:)`, `removeTracks(withIds:)`, and
    `clearPlaylist()`, add:
        persistLibrary()

 That's it — saving piggybacks on every mutation, loading happens once at launch.
*/
