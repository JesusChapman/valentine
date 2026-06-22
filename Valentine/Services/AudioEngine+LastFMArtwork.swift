//  AudioEngine+LastFMArtwork.swift
//  Fills missing album art from Last.fm, embeds it, caches per album.

import Foundation
import AppKit
import SwiftUI

extension AudioEngine {

    /// Fetch and apply missing cover art using Last.fm. Returns tracks updated.
    @discardableResult
    func autoFetchArtworkLastFM() async -> Int {
        var updated = 0
        var cache: [String: NSImage?] = [:]   // "artist|album" -> image (or nil if none)

        for i in queue.indices {
            let track = queue[i]
            guard track.nsImage == nil else { continue }

            let artist = track.effectiveAlbumArtist
            let album = track.album ?? ""
            guard !album.isEmpty, artist != "Unknown Artist", !artist.isEmpty else { continue }

            let key = "\(artist.lowercased())|\(album.lowercased())"
            let image: NSImage?
            if let cached = cache[key] {
                image = cached
            } else {
                image = await LastFMService.shared.albumArtwork(artist: artist, album: album)
                cache[key] = image
            }
            guard let art = image else { continue }

            if queue.indices.contains(i) {
                queue[i].nsImage = art
                queue[i].albumArt = Image(nsImage: art)
                let url = queue[i].url
                Task.detached {
                    url.startAccessing()
                    defer { url.stopAccessing() }
                    try? await ArtworkWriter.write(image: art, to: url)
                }
                updated += 1
            }
        }
        if updated > 0 { persistLibrary() }
        return updated
    }
}
