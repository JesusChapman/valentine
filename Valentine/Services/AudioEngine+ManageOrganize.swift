//  AudioEngine+ManageOrganize.swift
//  Library import, file organize, dedupe, and auto-tag on top of the queue.

import Foundation
import AppKit
import SwiftUI

extension AudioEngine {

    // MARK: - Manage: scan & import folders into the library

    /// Recursively scan folders/files and append new tracks to the library,
    /// skipping anything already present. Persists when done.
    /// Returns the number of tracks added.
    @discardableResult
    func importFromDisk(_ urls: [URL]) async -> Int {
        let scanner = LibraryScanner()
        let existing = Set(queue.map { $0.url.standardizedFileURL })
        let newTracks = await scanner.scan(urls, skipping: existing)
        guard !newTracks.isEmpty else { return 0 }
        queue.append(contentsOf: newTracks)
        if currentTrackIndex == nil { playTrack(at: 0, autoPlay: false) }
        persistLibrary()
        return newTracks.count
    }

    /// Drop library entries whose files no longer exist on disk.
    func pruneMissingTracks() {
        let before = queue.count
        let removed = queue.filter { !FileManager.default.fileExists(atPath: $0.url.path) }
        queue.removeAll { !FileManager.default.fileExists(atPath: $0.url.path) }
        if queue.count != before {
            if let idx = currentTrackIndex, !queue.indices.contains(idx) {
                currentTrackIndex = queue.isEmpty ? nil : 0
            }
            SpotlightIndexer.remove(removed)
            persistLibrary()
        }
    }

    // MARK: - Organize: rename & move files on disk

    /// Preview the organize plan for the whole library (dry run — touches nothing).
    func planOrganize(destinationRoot: URL,
                      pattern: NamingPattern = .standard,
                      copy: Bool = false) -> [OrganizePlan] {
        FileOrganizer(destinationRoot: destinationRoot, pattern: pattern, copyInsteadOfMove: copy)
            .plan(for: queue)
    }

    /// Execute an organize plan, then update each moved Track's url in the
    /// library so playback keeps working. Returns the per-file results.
    @discardableResult
    func applyOrganize(_ plans: [OrganizePlan],
                       destinationRoot: URL,
                       pattern: NamingPattern = .standard,
                       copy: Bool = false,
                       overwrite: Bool = false) -> [OrganizeResult] {
        let organizer = FileOrganizer(destinationRoot: destinationRoot,
                                      pattern: pattern, copyInsteadOfMove: copy)
        let results = organizer.apply(plans, overwrite: overwrite)
        if !copy {
            for r in results where r.succeeded {
                relocateTrack(id: r.trackID, to: r.destination)
            }
            persistLibrary()
        }
        return results
    }

    /// Point a library Track at a new file URL after a move/rename.
    func relocateTrack(id: UUID, to newURL: URL) {
        guard let i = queue.firstIndex(where: { $0.id == id }) else { return }
        var fresh = Track(url: newURL)
        // Preserve already-loaded tags/artwork instead of re-reading.
        let old = queue[i]
        fresh.title = old.title; fresh.artist = old.artist
        fresh.albumArtist = old.albumArtist; fresh.album = old.album
        fresh.albumArt = old.albumArt; fresh.nsImage = old.nsImage
        fresh.duration = old.duration; fresh.trackNumber = old.trackNumber
        fresh.year = old.year; fresh.genre = old.genre; fresh.lyrics = old.lyrics
        queue[i] = fresh
    }

    // MARK: - Organize: duplicates

    func findDuplicates(strategy: DuplicateStrategy = .tagsThenBytes(durationToleranceSeconds: 2)) -> [DuplicateGroup] {
        DuplicateFinder().findDuplicates(in: queue, strategy: strategy)
    }

    /// Trash the non-kept members of each group, then drop them from the library.
    /// Returns how many files were trashed.
    @discardableResult
    func removeDuplicates(_ groups: [DuplicateGroup],
                          keeping rule: KeepRule = .preferFormat(["flac", "alac", "m4a", "aac", "mp3", "ogg"])) -> Int {
        let finder = DuplicateFinder()
        var toRemove: [Track] = []
        for g in groups { toRemove.append(contentsOf: finder.membersToRemove(in: g, rule: rule)) }
        let trashedIDs = Set(finder.moveToTrash(toRemove))
        guard !trashedIDs.isEmpty else { return 0 }
        let trashedTracks = queue.filter { trashedIDs.contains($0.id) }
        queue.removeAll { trashedIDs.contains($0.id) }
        SpotlightIndexer.remove(trashedTracks)
        persistLibrary()
        return trashedIDs.count
    }

    // MARK: - Organize: auto-tag missing metadata / artwork

    /// Fetch and apply metadata for tracks missing core tags. `contact` must be
    /// a real email/URL (MusicBrainz policy). Writes tags to disk via your
    /// existing MetadataWriter and refreshes in-memory artwork.
    /// Returns the number of tracks updated.
    @discardableResult
    func autoTagMissing(contact: String, includeArtwork: Bool = true) async -> Int {
        let fetcher = MetadataFetcher(contact: contact)
        var updated = 0

        for i in queue.indices {
            let track = queue[i]
            let needsTags = track.artist == "Unknown Artist" || track.artist.isEmpty
                || (track.album ?? "").isEmpty
            let needsArt = includeArtwork && track.nsImage == nil
            guard needsTags || needsArt else { continue }

            guard let result = try? await fetcher.fetch(for: track, includeArtwork: needsArt) else { continue }

            // Apply text tags through your existing pipeline (memory + disk + cache).
            applyMetadataEdit(result.edit, toTrackAt: i)

            // Apply artwork in memory, then embed it into the file on disk.
            if let art = result.artwork, queue.indices.contains(i) {
                queue[i].nsImage = art
                queue[i].albumArt = Image(nsImage: art)
                let url = queue[i].url
                Task.detached {
                    url.startAccessing()
                    defer { url.stopAccessing() }
                    try? await ArtworkWriter.write(image: art, to: url)
                }
            }
            updated += 1
        }
        if updated > 0 { persistLibrary() }
        return updated
    }
}
