//  LibraryScanner.swift
//  Recursively scans folders into Track values for the library.

import Foundation
import Observation
#if os(macOS)
import AppKit
#endif

enum AudioFileTypes {
    static let supported: Set<String> =
        ["mp3", "m4a", "m4b", "wav", "aac", "flac", "ogg", "aiff", "alac", "opus"]

    static func isAudio(_ url: URL) -> Bool {
        supported.contains(url.pathExtension.lowercased())
    }
}

struct ScanProgress: Sendable {
    var found: Int
    var loaded: Int
    var currentFile: String?
}

@MainActor
@Observable
final class LibraryScanner {
    private(set) var isScanning = false
    private(set) var progress = ScanProgress(found: 0, loaded: 0, currentFile: nil)

    func scan(_ urls: [URL], skipping existingURLs: Set<URL> = []) async -> [Track] {
        isScanning = true
        defer { isScanning = false }

        let files = collectFiles(urls).filter { !existingURLs.contains($0.standardizedFileURL) }
        progress = ScanProgress(found: files.count, loaded: 0, currentFile: nil)

        var tracks: [Track] = []
        for (i, url) in files.enumerated() {
            var track = Track(url: url)
            await track.loadMetadata()
            tracks.append(track)
            progress = ScanProgress(found: files.count, loaded: i + 1,
                                    currentFile: url.lastPathComponent)
        }
        return tracks
    }

    #if os(macOS)
    func pickAndScanFolders(skipping existingURLs: Set<URL> = []) async -> [Track] {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        guard panel.runModal() == .OK else { return [] }
        return await scan(panel.urls, skipping: existingURLs)
    }
    #endif

    private func collectFiles(_ urls: [URL]) -> [URL] {
        var result: [URL] = []
        let fm = FileManager.default
        for url in urls {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { continue }
            if !isDir.boolValue {
                if AudioFileTypes.isAudio(url) { result.append(url) }
                continue
            }
            if let en = fm.enumerator(at: url,
                                      includingPropertiesForKeys: [.isRegularFileKey],
                                      options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
                for case let f as URL in en where AudioFileTypes.isAudio(f) {
                    result.append(f)
                }
            }
        }
        return result
    }
}
