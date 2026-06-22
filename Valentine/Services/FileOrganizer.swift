//  FileOrganizer.swift
//  Renames/moves files into AlbumArtist/Album/## - Title from tags.
//  plan() is a dry run; apply() never overwrites unless told to.

import Foundation

/// Naming tokens: {artist} {albumArtist} {album} {title} {genre} {year}
/// {track} {track1} {disc} {ext}
struct NamingPattern {
    var raw: String
    init(_ raw: String) { self.raw = raw }

    static let standard = NamingPattern("{albumArtist}/{album}/{track} - {title}")
    static let detailed = NamingPattern("{artist}/{year} - {album}/{track} - {title}")
    static let byGenre  = NamingPattern("{genre}/{artist}/{album}/{track} {title}")
    static let flat     = NamingPattern("{artist} - {title}")
}

struct OrganizePlan: Identifiable {
    var id: UUID { trackID }
    let trackID: UUID
    let source: URL
    let destination: URL
    var willOverwrite: Bool
    var skippedReason: String?
}

struct OrganizeResult {
    let trackID: UUID
    let source: URL
    let destination: URL
    let succeeded: Bool
    let error: String?
}

struct FileOrganizer {
    let destinationRoot: URL
    let pattern: NamingPattern
    let copyInsteadOfMove: Bool

    init(destinationRoot: URL,
         pattern: NamingPattern = .standard,
         copyInsteadOfMove: Bool = false) {
        self.destinationRoot = destinationRoot
        self.pattern = pattern
        self.copyInsteadOfMove = copyInsteadOfMove
    }

    // MARK: Planning (dry run)

    func plan(for tracks: [Track]) -> [OrganizePlan] { tracks.map(plan(for:)) }

    func plan(for track: Track) -> OrganizePlan {
        let ext = track.url.pathExtension.isEmpty ? "mp3" : track.url.pathExtension

        // Need title + artist + album to build a meaningful path.
        let hasCore = !track.title.isEmpty
            && track.artist != "Unknown Artist" && !track.artist.isEmpty
            && !(track.album ?? "").isEmpty
        guard hasCore else {
            return OrganizePlan(trackID: track.id, source: track.url, destination: track.url,
                                willOverwrite: false,
                                skippedReason: "Missing title/artist/album — fetch tags first")
        }

        let relative = render(pattern.raw, track: track, ext: ext)
        let dest = destinationRoot.appendingPathComponent(relative)
        let same = dest.standardizedFileURL == track.url.standardizedFileURL
        let exists = FileManager.default.fileExists(atPath: dest.path)
        return OrganizePlan(trackID: track.id, source: track.url, destination: dest,
                            willOverwrite: exists && !same,
                            skippedReason: same ? "Already organized" : nil)
    }

    // MARK: Apply

    @discardableResult
    func apply(_ plans: [OrganizePlan], overwrite: Bool = false) -> [OrganizeResult] {
        let fm = FileManager.default
        var results: [OrganizeResult] = []

        for plan in plans {
            if let reason = plan.skippedReason {
                results.append(.init(trackID: plan.trackID, source: plan.source,
                                     destination: plan.destination,
                                     succeeded: false, error: reason))
                continue
            }
            do {
                try fm.createDirectory(at: plan.destination.deletingLastPathComponent(),
                                       withIntermediateDirectories: true)
                if fm.fileExists(atPath: plan.destination.path) {
                    guard overwrite else {
                        results.append(.init(trackID: plan.trackID, source: plan.source,
                                             destination: plan.destination, succeeded: false,
                                             error: "Destination exists (overwrite disabled)"))
                        continue
                    }
                    try fm.removeItem(at: plan.destination)
                }
                if copyInsteadOfMove {
                    try fm.copyItem(at: plan.source, to: plan.destination)
                } else {
                    try fm.moveItem(at: plan.source, to: plan.destination)
                }
                results.append(.init(trackID: plan.trackID, source: plan.source,
                                     destination: plan.destination, succeeded: true, error: nil))
            } catch {
                results.append(.init(trackID: plan.trackID, source: plan.source,
                                     destination: plan.destination, succeeded: false,
                                     error: error.localizedDescription))
            }
        }
        if !copyInsteadOfMove { cleanupEmptyDirs(from: plans.map(\.source)) }
        return results
    }

    // MARK: Rendering

    private func render(_ template: String, track: Track, ext: String) -> String {
        let track2 = track.trackNumber.map { String(format: "%02d", $0) } ?? "00"
        let track1 = track.trackNumber.map(String.init) ?? ""
        let map: [String: String] = [
            "artist":      sanitize(track.artist),
            "albumArtist": sanitize(track.effectiveAlbumArtist),
            "album":       sanitize(track.album),
            "title":       sanitize(track.title),
            "genre":       sanitize(track.genre ?? "Unknown Genre"),
            "year":        track.year.map(String.init) ?? "",
            "track":       track2,
            "track1":      track1,
            "disc":        "",
            "ext":         ext
        ]
        var out = template
        for (k, v) in map { out = out.replacingOccurrences(of: "{\(k)}", with: v) }
        out = out.replacingOccurrences(of: #"\s*-\s*-\s*"#, with: " - ", options: .regularExpression)
        out = out.replacingOccurrences(of: #"/{2,}"#, with: "/", options: .regularExpression)
        return out.trimmingCharacters(in: .whitespaces) + "." + ext
    }

    private func sanitize(_ value: String?) -> String {
        let v = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !v.isEmpty else { return "Unknown" }
        let illegal = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let cleaned = v.components(separatedBy: illegal).joined(separator: "_")
        return String(cleaned.prefix(180)).trimmingCharacters(in: CharacterSet(charactersIn: " ."))
    }

    private func cleanupEmptyDirs(from sources: [URL]) {
        let fm = FileManager.default
        for dir in Set(sources.map { $0.deletingLastPathComponent() }) {
            if let c = try? fm.contentsOfDirectory(atPath: dir.path), c.isEmpty {
                try? fm.removeItem(at: dir)
            }
        }
    }
}
