//  SpotlightIndexer.swift
//  Indexes the library into Core Spotlight, keyed by file path for deep links.

import Foundation
import CoreSpotlight
import UniformTypeIdentifiers
import AppKit

enum SpotlightIndexer {
    /// Domain groups all our items so we can wipe/rebuild cleanly.
    static let domain = "dev.jesuschapman.Valentine.library"

    /// The activity type used for deep links from Spotlight results.
    static let activityType = "dev.jesuschapman.Valentine.play"

    // MARK: Indexing

    /// Replace the entire Spotlight index with the current library.
    /// Cheap enough to call on library changes (debounced by the caller).
    static func reindex(_ tracks: [Track]) {
        let index = CSSearchableIndex.default()
        index.deleteSearchableItems(withDomainIdentifiers: [domain]) { _ in
            let items = tracks.map { makeItem(for: $0) }
            guard !items.isEmpty else { return }
            index.indexSearchableItems(items) { error in
                if let error { print("Spotlight index error: \(error)") }
            }
        }
    }

    /// Incrementally add/update a few tracks without rebuilding everything.
    static func index(_ tracks: [Track]) {
        guard !tracks.isEmpty else { return }
        CSSearchableIndex.default().indexSearchableItems(tracks.map(makeItem)) { error in
            if let error { print("Spotlight index error: \(error)") }
        }
    }

    /// Remove specific tracks (e.g. after dedupe/prune).
    static func remove(_ tracks: [Track]) {
        let ids = tracks.map { $0.url.standardizedFileURL.path }
        guard !ids.isEmpty else { return }
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: ids) { error in
            if let error { print("Spotlight delete error: \(error)") }
        }
    }

    /// Wipe the whole Valentine index.
    static func clear() {
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [domain], completionHandler: nil)
    }

    // MARK: Item construction

    private static func makeItem(for track: Track) -> CSSearchableItem {
        let attrs = CSSearchableItemAttributeSet(contentType: .audio)
        attrs.title = track.title
        attrs.artist = track.artist
        attrs.album = track.album
        attrs.genre = track.genre
        attrs.duration = NSNumber(value: track.duration)
        attrs.contentDescription = [track.artist, track.album]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " — ")
        // Searchable keywords: artist, album, album artist.
        attrs.keywords = [track.artist, track.album, track.albumArtist]
            .compactMap { $0 }.filter { !$0.isEmpty }
        if let png = track.nsImage?.tiffRepresentation {
            attrs.thumbnailData = png
        }

        // Identifier = stable file path; lets us deep-link back on tap.
        let item = CSSearchableItem(
            uniqueIdentifier: track.url.standardizedFileURL.path,
            domainIdentifier: domain,
            attributeSet: attrs
        )
        return item
    }
}
