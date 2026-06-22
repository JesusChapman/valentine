//  LastFMService+Info.swift
//  Album/artist info and artwork via Last.fm (uses the existing API key).

import Foundation
import AppKit

struct LastFMAlbumInfo {
    var title: String?
    var artist: String?
    var imageURL: URL?
    var tags: [String]
    var summary: String?
}

struct LastFMArtistInfo {
    var name: String?
    var imageURL: URL?
    var tags: [String]
    var bio: String?
    var similar: [String]
}

extension LastFMService {

    /// Last.fm's placeholder image hash — skip these (they're not real art).
    private static let placeholderHashes = [
        "2a96cbd8b46e442fc41c2b86b821562f", // generic star
        "c6f59c1e5e7240a4c0d427abd71f3dbb"
    ]

    private var apiKeyValue: String { Secrets.lastFMApiKey }

    // MARK: Album

    func albumInfo(artist: String, album: String) async -> LastFMAlbumInfo? {
        guard !apiKeyValue.isEmpty else { return nil }
        var comps = URLComponents(string: "https://ws.audioscrobbler.com/2.0/")!
        comps.queryItems = [
            .init(name: "method", value: "album.getinfo"),
            .init(name: "api_key", value: apiKeyValue),
            .init(name: "artist", value: artist),
            .init(name: "album", value: album),
            .init(name: "format", value: "json")
        ]
        guard let url = comps.url,
              let (data, resp) = try? await URLSession.shared.data(from: url),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let a = root["album"] as? [String: Any] else { return nil }

        return LastFMAlbumInfo(
            title: a["name"] as? String,
            artist: a["artist"] as? String,
            imageURL: Self.bestImageURL(a["image"] as? [[String: Any]]),
            tags: Self.parseTags(a["tags"]),
            summary: ((a["wiki"] as? [String: Any])?["summary"] as? String).map(Self.stripHTML)
        )
    }

    // MARK: Artist

    func artistInfo(artist: String) async -> LastFMArtistInfo? {
        guard !apiKeyValue.isEmpty else { return nil }
        var comps = URLComponents(string: "https://ws.audioscrobbler.com/2.0/")!
        comps.queryItems = [
            .init(name: "method", value: "artist.getinfo"),
            .init(name: "api_key", value: apiKeyValue),
            .init(name: "artist", value: artist),
            .init(name: "format", value: "json")
        ]
        guard let url = comps.url,
              let (data, resp) = try? await URLSession.shared.data(from: url),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let a = root["artist"] as? [String: Any] else { return nil }

        let similar = ((a["similar"] as? [String: Any])?["artist"] as? [[String: Any]])?
            .compactMap { $0["name"] as? String } ?? []

        return LastFMArtistInfo(
            name: a["name"] as? String,
            imageURL: Self.bestImageURL(a["image"] as? [[String: Any]]),
            tags: Self.parseTags(a["tags"]),
            bio: ((a["bio"] as? [String: Any])?["summary"] as? String).map(Self.stripHTML),
            similar: similar
        )
    }

    /// Download cover art for an album from Last.fm. Returns nil if the only
    /// image available is a placeholder.
    func albumArtwork(artist: String, album: String) async -> NSImage? {
        guard let info = await albumInfo(artist: artist, album: album),
              let url = info.imageURL,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let image = NSImage(data: data) else { return nil }
        return image
    }

    // MARK: Parsing helpers

    /// Pick the largest non-placeholder image from a Last.fm image array.
    private static func bestImageURL(_ images: [[String: Any]]?) -> URL? {
        guard let images else { return nil }
        // Order of preference: mega, extralarge, large, medium.
        let order = ["mega", "extralarge", "large", "medium", "small"]
        let bySize = Dictionary(uniqueKeysWithValues:
            images.compactMap { img -> (String, String)? in
                guard let size = img["size"] as? String,
                      let text = img["#text"] as? String, !text.isEmpty else { return nil }
                return (size, text)
            })
        for size in order {
            if let urlStr = bySize[size],
               !placeholderHashes.contains(where: { urlStr.contains($0) }),
               let url = URL(string: urlStr) {
                return url
            }
        }
        return nil
    }

    private static func parseTags(_ raw: Any?) -> [String] {
        guard let tags = (raw as? [String: Any])?["tag"] as? [[String: Any]] else { return [] }
        return tags.compactMap { $0["name"] as? String }
    }

    private static func stripHTML(_ s: String) -> String {
        s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
         .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
