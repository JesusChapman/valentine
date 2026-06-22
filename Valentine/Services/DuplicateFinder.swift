//  DuplicateFinder.swift
//  Finds duplicate tracks by byte hash and/or tags. moveToTrash is reversible.

import Foundation
import CryptoKit

enum DuplicateStrategy {
    case exactBytes
    case tags(durationToleranceSeconds: Double)
    case tagsThenBytes(durationToleranceSeconds: Double)
}

struct DuplicateGroup: Identifiable {
    let id = UUID()
    let members: [Track]
    let reason: String
}

enum KeepRule {
    case largestFile
    case smallestFile
    case preferFormat([String])   // e.g. ["flac","m4a","mp3"] — earliest wins
}

struct DuplicateFinder {

    func findDuplicates(in tracks: [Track], strategy: DuplicateStrategy) -> [DuplicateGroup] {
        switch strategy {
        case .exactBytes:
            return byBytes(tracks)
        case .tags(let tol):
            return byTags(tracks, tolerance: tol)
        case .tagsThenBytes(let tol):
            return byTags(tracks, tolerance: tol).flatMap { byBytes($0.members) }
        }
    }

    func memberToKeep(in group: DuplicateGroup, rule: KeepRule) -> Track? {
        switch rule {
        case .largestFile:  return group.members.max { fileSize($0) < fileSize($1) }
        case .smallestFile: return group.members.min { fileSize($0) < fileSize($1) }
        case .preferFormat(let order):
            return group.members.min { rank($0.url.pathExtension, order) < rank($1.url.pathExtension, order) }
        }
    }

    func membersToRemove(in group: DuplicateGroup, rule: KeepRule) -> [Track] {
        guard let keeper = memberToKeep(in: group, rule: rule) else { return [] }
        return group.members.filter { $0.id != keeper.id }
    }

    /// Move chosen duplicates to the Trash (reversible). Returns trashed Track ids.
    @discardableResult
    func moveToTrash(_ tracks: [Track]) -> [UUID] {
        var trashed: [UUID] = []
        for t in tracks {
            t.url.startAccessing()
            defer { t.url.stopAccessing() }
            var out: NSURL?
            if (try? FileManager.default.trashItem(at: t.url, resultingItemURL: &out)) != nil {
                trashed.append(t.id)
            }
        }
        return trashed
    }

    // MARK: Strategies

    private func byBytes(_ tracks: [Track]) -> [DuplicateGroup] {
        var buckets: [String: [Track]] = [:]
        for t in tracks {
            guard let hash = quickHash(of: t.url) else { continue }
            buckets["\(hash)-\(fileSize(t))", default: []].append(t)
        }
        return buckets.values.filter { $0.count > 1 }
            .map { DuplicateGroup(members: $0, reason: "Byte-identical files") }
    }

    private func byTags(_ tracks: [Track], tolerance: Double) -> [DuplicateGroup] {
        func norm(_ s: String?) -> String {
            (s ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        }
        var buckets: [String: [Track]] = [:]
        for t in tracks {
            guard !t.title.isEmpty, t.artist != "Unknown Artist", !t.artist.isEmpty else { continue }
            buckets["\(norm(t.artist))|\(norm(t.title))|\(norm(t.album))", default: []].append(t)
        }

        var groups: [DuplicateGroup] = []
        for members in buckets.values where members.count > 1 {
            if tolerance > 0 {
                groups.append(contentsOf: splitByDuration(members, tolerance: tolerance))
            } else {
                groups.append(DuplicateGroup(members: members, reason: "Same artist / title / album"))
            }
        }
        return groups
    }

    private func splitByDuration(_ members: [Track], tolerance: Double) -> [DuplicateGroup] {
        var remaining = members
        var groups: [DuplicateGroup] = []
        while let seed = remaining.first {
            let (matches, rest) = remaining.reduce(into: ([Track](), [Track]())) { acc, t in
                abs(seed.duration - t.duration) <= tolerance ? acc.0.append(t) : acc.1.append(t)
            }
            remaining = rest
            if matches.count > 1 {
                groups.append(DuplicateGroup(members: matches,
                    reason: "Same tags, within \(Int(tolerance))s duration"))
            }
        }
        return groups
    }

    // MARK: Helpers

    private func fileSize(_ t: Track) -> Int64 {
        (try? FileManager.default.attributesOfItem(atPath: t.url.path)[.size] as? Int64) ?? 0
    }

    private func rank(_ ext: String, _ order: [String]) -> Int {
        order.firstIndex(of: ext.lowercased()) ?? order.count
    }

    /// Hash the first MB of a file — enough to flag byte-identical copies cheaply.
    private func quickHash(of url: URL, sampleBytes: Int = 1_048_576) -> String? {
        url.startAccessing()
        defer { url.stopAccessing() }
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let data = (try? handle.read(upToCount: sampleBytes)) ?? Data()
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
