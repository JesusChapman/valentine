//  MetadataFetcher.swift
//  Looks up missing tags/artwork from MusicBrainz + Cover Art Archive.
//  Throttled to ~1 req/sec; MusicBrainz requires a contact string.

import Foundation
import AppKit

struct FetchedMetadata {
    let edit: TrackMetadataEdit
    let artwork: NSImage?
    let musicBrainzReleaseID: String?
    let score: Int            // 0...100 MusicBrainz match confidence
}

actor MetadataFetcher {
    private let userAgent: String
    private let session: URLSession
    private let minInterval: TimeInterval
    private var lastRequest: Date = .distantPast

    /// - contact: a real email/URL, required by MusicBrainz policy.
    ///   Produces e.g. "Valentine/1.2 ( you@example.com )".
    init(appName: String = "Valentine",
         version: String = "1.2",
         contact: String,
         minInterval: TimeInterval = 1.1,
         session: URLSession = .shared) {
        self.userAgent = "\(appName)/\(version) ( \(contact) )"
        self.minInterval = minInterval
        self.session = session
    }

    // MARK: Public

    /// Look up metadata for a Track using its current tags, falling back to
    /// parsing "Artist - Title" from the filename when tags are empty.
    func fetch(for track: Track, includeArtwork: Bool = true) async throws -> FetchedMetadata {
        let (artist, title) = searchTerms(for: track)
        guard !title.isEmpty else { throw FetchError.noMatch }

        guard let rec = try await searchRecording(artist: artist, title: title, album: track.album) else {
            throw FetchError.noMatch
        }

        let edit = TrackMetadataEdit(
            title:       rec.title ?? track.title,
            artist:      rec.artist ?? track.artist,
            albumArtist: rec.artist ?? (track.albumArtist ?? ""),
            album:       rec.album ?? (track.album ?? ""),
            genre:       track.genre ?? "",
            year:        rec.year.map(String.init) ?? (track.year.map(String.init) ?? ""),
            trackNumber: rec.trackNumber.map(String.init) ?? (track.trackNumber.map(String.init) ?? "")
        )

        var art: NSImage?
        if includeArtwork, track.nsImage == nil, let mbid = rec.releaseID {
            if let data = try? await frontCover(releaseID: mbid) { art = NSImage(data: data) }
        }

        return FetchedMetadata(edit: edit, artwork: art,
                               musicBrainzReleaseID: rec.releaseID, score: rec.score)
    }

    /// Fetch the front cover image data for a known release MBID.
    func frontCover(releaseID: String, size: Int = 500) async throws -> Data {
        let url = URL(string: "https://coverartarchive.org/release/\(releaseID)/front-\(size)")!
        var req = URLRequest(url: url)
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200, !data.isEmpty else {
            throw FetchError.noMatch
        }
        return data
    }

    enum FetchError: LocalizedError {
        case noMatch, network
        var errorDescription: String? {
            switch self {
            case .noMatch: return "No metadata match found."
            case .network: return "Network unavailable."
            }
        }
    }

    // MARK: MusicBrainz

    private struct Recording {
        var title: String?
        var artist: String?
        var album: String?
        var releaseID: String?
        var year: Int?
        var trackNumber: Int?
        var score: Int
    }

    private func searchRecording(artist: String, title: String, album: String?) async throws -> Recording? {
        try await throttle()

        var lucene = "recording:\"\(escapeLucene(title))\""
        if !artist.isEmpty, artist != "Unknown Artist" {
            lucene += " AND artist:\"\(escapeLucene(artist))\""
        }
        if let album, !album.isEmpty { lucene += " AND release:\"\(escapeLucene(album))\"" }

        var comps = URLComponents(string: "https://musicbrainz.org/ws/2/recording")!
        comps.queryItems = [
            .init(name: "query", value: lucene),
            .init(name: "fmt", value: "json"),
            .init(name: "limit", value: "5"),
            .init(name: "inc", value: "releases")
        ]
        var req = URLRequest(url: comps.url!)
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw FetchError.network }
        guard http.statusCode == 200 else { throw FetchError.noMatch }
        return parseTop(data)
    }

    private func parseTop(_ data: Data) -> Recording? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let recordings = root["recordings"] as? [[String: Any]],
              let top = recordings.first else { return nil }

        let title = top["title"] as? String
        let score = (top["score"] as? Int) ?? Int(top["score"] as? String ?? "") ?? 0

        var artist: String?
        if let credits = top["artist-credit"] as? [[String: Any]], let first = credits.first {
            artist = (first["name"] as? String) ?? ((first["artist"] as? [String: Any])?["name"] as? String)
        }

        var album: String?, releaseID: String?, year: Int?, trackNumber: Int?
        if let releases = top["releases"] as? [[String: Any]] {
            let chosen = releases.first { ($0["status"] as? String)?.lowercased() == "official" } ?? releases.first
            if let r = chosen {
                album = r["title"] as? String
                releaseID = r["id"] as? String
                if let date = r["date"] as? String, let y = Int(date.prefix(4)) { year = y }
                if let media = r["media"] as? [[String: Any]], let m = media.first,
                   let tracks = m["track"] as? [[String: Any]], let t = tracks.first {
                    if let n = t["number"] as? String { trackNumber = Int(n) }
                    else if let n = t["position"] as? Int { trackNumber = n }
                }
            }
        }

        return Recording(title: title, artist: artist, album: album,
                         releaseID: releaseID, year: year,
                         trackNumber: trackNumber, score: score)
    }

    // MARK: Helpers

    private func searchTerms(for track: Track) -> (artist: String, title: String) {
        if !track.title.isEmpty,
           track.title != track.url.deletingPathExtension().lastPathComponent {
            return (track.artist, track.title)
        }
        // Tags look empty/defaulted — try "Artist - Title" from the filename.
        let base = track.url.deletingPathExtension().lastPathComponent
        let parts = base.components(separatedBy: " - ")
        if parts.count >= 2 {
            return (parts[0].trimmingCharacters(in: .whitespaces),
                    parts[1...].joined(separator: " - ").trimmingCharacters(in: .whitespaces))
        }
        return (track.artist, track.title.isEmpty ? base : track.title)
    }

    private func escapeLucene(_ s: String) -> String {
        let special = CharacterSet(charactersIn: "+-&|!(){}[]^\"~*?:\\/")
        var out = ""
        for u in s.unicodeScalars {
            if special.contains(u) { out.append("\\") }
            out.unicodeScalars.append(u)
        }
        return out
    }

    private func throttle() async throws {
        let elapsed = Date().timeIntervalSince(lastRequest)
        if elapsed < minInterval {
            try await Task.sleep(nanoseconds: UInt64((minInterval - elapsed) * 1_000_000_000))
        }
        lastRequest = .now
    }
}
