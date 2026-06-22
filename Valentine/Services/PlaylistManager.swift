//
//  PlaylistManager.swift
//  Valentine — Manage & Organize
//
//  MediaMonkey "Organize → set up playlists".
//
//  • Manual playlists: ordered lists, persisted as JSON.
//  • Smart playlists: rule-based, evaluated live against AudioEngine.queue.
//  • Import/export standard .m3u8 for interop with other players.
//
//  Persistence keys tracks by FILE PATH, not Track.id — your Track.id is a
//  fresh UUID per launch (see Track.init), so paths are the only stable key.
//  Resolve a stored playlist back to live Tracks via `resolve(_:in:)`.
//

import Foundation
import Observation

struct Playlist: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var trackPaths: [String]      // standardized file paths, ordered
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), name: String, trackPaths: [String] = []) {
        self.id = id; self.name = name; self.trackPaths = trackPaths
        self.createdAt = .now; self.updatedAt = .now
    }
}

// MARK: - Smart playlists

struct SmartRule {
    enum Field { case artist, album, albumArtist, genre, title, year }
    enum Op { case contains, equals, beginsWith, greaterThan, lessThan }

    let field: Field
    let op: Op
    let value: String

    init(_ field: Field, _ op: Op, _ value: String) {
        self.field = field; self.op = op; self.value = value
    }

    func matches(_ t: Track) -> Bool {
        let target: String?
        switch field {
        case .artist:      target = t.artist
        case .album:       target = t.album
        case .albumArtist: target = t.effectiveAlbumArtist
        case .genre:       target = t.genre
        case .title:       target = t.title
        case .year:        target = t.year.map(String.init)
        }
        let lhs = (target ?? "").lowercased(), rhs = value.lowercased()
        switch op {
        case .contains:    return lhs.contains(rhs)
        case .equals:      return lhs == rhs
        case .beginsWith:  return lhs.hasPrefix(rhs)
        case .greaterThan: return (Double(lhs) ?? .nan) > (Double(rhs) ?? .nan)
        case .lessThan:    return (Double(lhs) ?? .nan) < (Double(rhs) ?? .nan)
        }
    }
}

struct SmartPlaylist {
    enum Match { case all, any }
    let name: String
    let match: Match
    let rules: [SmartRule]
    let limit: Int?

    init(name: String, match: Match = .all, rules: [SmartRule], limit: Int? = nil) {
        self.name = name; self.match = match; self.rules = rules; self.limit = limit
    }

    func evaluate(over tracks: [Track]) -> [Track] {
        let filtered = tracks.filter { t in
            switch match {
            case .all: return rules.allSatisfy { $0.matches(t) }
            case .any: return rules.contains { $0.matches(t) }
            }
        }
        if let limit { return Array(filtered.prefix(limit)) }
        return filtered
    }
}

@MainActor
@Observable
final class PlaylistManager {
    private(set) var playlists: [Playlist] = []
    private let storeURL: URL

    init(storeURL: URL? = nil) {
        if let storeURL {
            self.storeURL = storeURL
        } else {
            let dir = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Valentine", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.storeURL = dir.appendingPathComponent("playlists.json")
        }
        load()
    }

    // MARK: CRUD

    @discardableResult
    func create(name: String, tracks: [Track] = []) -> Playlist {
        let pl = Playlist(name: name, trackPaths: tracks.map { $0.url.standardizedFileURL.path })
        playlists.append(pl); persist(); return pl
    }

    func rename(_ id: UUID, to name: String) {
        guard let i = idx(id) else { return }
        playlists[i].name = name; playlists[i].updatedAt = .now; persist()
    }

    func delete(_ id: UUID) { playlists.removeAll { $0.id == id }; persist() }

    func add(_ tracks: [Track], to id: UUID) {
        guard let i = idx(id) else { return }
        let existing = Set(playlists[i].trackPaths)
        let new = tracks.map { $0.url.standardizedFileURL.path }.filter { !existing.contains($0) }
        playlists[i].trackPaths.append(contentsOf: new)
        playlists[i].updatedAt = .now; persist()
    }

    func remove(_ tracks: [Track], from id: UUID) {
        guard let i = idx(id) else { return }
        let drop = Set(tracks.map { $0.url.standardizedFileURL.path })
        playlists[i].trackPaths.removeAll { drop.contains($0) }
        playlists[i].updatedAt = .now; persist()
    }

    func reorder(_ id: UUID, trackPaths: [String]) {
        guard let i = idx(id) else { return }
        playlists[i].trackPaths = trackPaths; playlists[i].updatedAt = .now; persist()
    }

    /// Materialize a stored playlist into live Tracks from AudioEngine.queue,
    /// preserving playlist order and dropping any files no longer in the library.
    func resolve(_ playlist: Playlist, in library: [Track]) -> [Track] {
        let byPath = Dictionary(library.map { ($0.url.standardizedFileURL.path, $0) }) { a, _ in a }
        return playlist.trackPaths.compactMap { byPath[$0] }
    }

    /// Snapshot a smart playlist's current matches into a static playlist.
    @discardableResult
    func snapshotSmart(_ smart: SmartPlaylist, over library: [Track]) -> Playlist {
        create(name: smart.name, tracks: smart.evaluate(over: library))
    }

    // MARK: M3U

    @discardableResult
    func exportM3U(_ playlist: Playlist, to url: URL, library: [Track]) throws -> URL {
        let tracks = resolve(playlist, in: library)
        var lines = ["#EXTM3U"]
        for t in tracks {
            lines.append("#EXTINF:\(Int(t.duration)),\(t.artist) - \(t.title)")
            lines.append(t.url.path)
        }
        try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    @discardableResult
    func importM3U(from url: URL, name: String? = nil) throws -> Playlist {
        let text = try String(contentsOf: url, encoding: .utf8)
        let base = url.deletingLastPathComponent()
        var paths: [String] = []
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            let entry = line.hasPrefix("/") ? URL(fileURLWithPath: line) : base.appendingPathComponent(line)
            paths.append(entry.standardizedFileURL.path)
        }
        let pl = Playlist(name: name ?? url.deletingPathExtension().lastPathComponent, trackPaths: paths)
        playlists.append(pl); persist(); return pl
    }

    // MARK: Persistence

    private func idx(_ id: UUID) -> Int? { playlists.firstIndex { $0.id == id } }

    private func persist() {
        guard let data = try? JSONEncoder().encode(playlists) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: storeURL),
              let decoded = try? JSONDecoder().decode([Playlist].self, from: data) else { return }
        playlists = decoded
    }
}
