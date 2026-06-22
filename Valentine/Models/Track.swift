import Foundation
import AVFoundation
import SwiftUI

struct LyricLine: Identifiable, Hashable {
    let id = UUID()
    let time: TimeInterval
    let text: String
}

struct Track: Identifiable, Hashable {
    let id: UUID
    let url: URL
    var title: String
    var artist: String
    var albumArtist: String?
    var album: String?
    var albumArt: Image?
    var nsImage: NSImage?
    var duration: TimeInterval
    var trackNumber: Int?
    var year: Int?
    var genre: String?
    var lyrics: [LyricLine]?

    /// The artist used to group albums. Falls back to track artist.
    var effectiveAlbumArtist: String {
        if let a = albumArtist, !a.isEmpty { return a }
        return artist
    }

    init(url: URL) {
        self.id = UUID()
        self.url = url
        self.title = url.deletingPathExtension().lastPathComponent
        self.artist = "Unknown Artist"
        self.albumArtist = nil
        self.album = nil
        self.albumArt = nil
        self.nsImage = nil
        self.duration = 0
        self.trackNumber = nil
        self.year = nil
        self.genre = nil
        self.lyrics = nil
    }

    mutating func loadMetadata() async {
        let asset = AVURLAsset(url: url)

        do {
            self.duration = try await asset.load(.duration).seconds

            let formats = try await asset.load(.availableMetadataFormats)
            var foundLyricsText: String? = nil

            for format in formats {
                let metadata = try await asset.loadMetadata(for: format)
                for item in metadata {
                    if item.identifier == .iTunesMetadataLyrics ||
                       item.identifier?.rawValue == "id3/USLT" ||
                       item.identifier?.rawValue == "id3/SYLT" ||
                       item.key as? String == "USLT" ||
                       item.key as? String == "SYLT" {
                        if let value = try? await item.load(.stringValue) {
                            foundLyricsText = value
                        }
                    }

                    // Album artist (no common key — read format-specific identifiers).
                    if item.identifier == .iTunesMetadataAlbumArtist ||
                       item.identifier?.rawValue == "id3/TPE2" ||
                       item.key as? String == "TPE2" ||
                       item.key as? String == "aART" {
                        if let value = try? await item.load(.stringValue), !value.isEmpty {
                            self.albumArtist = value
                        }
                    }

                    // Track number (e.g. "3" or "3/12").
                    if item.identifier == .iTunesMetadataTrackNumber ||
                       item.identifier?.rawValue == "id3/TRCK" ||
                       item.key as? String == "TRCK" ||
                       item.key as? String == "trkn" {
                        if let str = try? await item.load(.stringValue),
                           let n = Int(str.split(separator: "/").first.map(String.init) ?? str) {
                            self.trackNumber = n
                        } else if let num = try? await item.load(.numberValue) {
                            self.trackNumber = num.intValue
                        }
                    }

                    // Year / release date.
                    if item.commonKey?.rawValue == AVMetadataKey.commonKeyCreationDate.rawValue ||
                       item.identifier?.rawValue == "id3/TYER" ||
                       item.identifier?.rawValue == "id3/TDRC" ||
                       item.key as? String == "TYER" ||
                       item.key as? String == "©day" {
                        if let str = try? await item.load(.stringValue),
                           let y = Int(str.prefix(4)) {
                            self.year = y
                        }
                    }

                    // Genre.
                    if item.commonKey?.rawValue == AVMetadataKey.commonKeyType.rawValue ||
                       item.identifier?.rawValue == "id3/TCON" ||
                       item.key as? String == "TCON" ||
                       item.key as? String == "©gen" {
                        if let str = try? await item.load(.stringValue), !str.isEmpty {
                            self.genre = str
                        }
                    }

                    guard let commonKey = item.commonKey?.rawValue else { continue }

                    switch commonKey {
                    case AVMetadataKey.commonKeyTitle.rawValue:
                        if let value = try await item.load(.stringValue) {
                            self.title = value
                        }
                    case AVMetadataKey.commonKeyArtist.rawValue:
                        if let value = try await item.load(.stringValue) {
                            self.artist = value
                        }
                    case AVMetadataKey.commonKeyAlbumName.rawValue:
                        if let value = try await item.load(.stringValue) {
                            self.album = value
                        }
                    case AVMetadataKey.commonKeyArtwork.rawValue:
                        if let value = try await item.load(.dataValue),
                           let image = NSImage(data: value) {
                            self.nsImage = image
                            self.albumArt = Image(nsImage: image)
                        }
                    default:
                        break
                    }
                }
            }

            if let lyricsText = foundLyricsText {
                self.lyrics = parseLRC(lyricsText)
            }

        } catch {
            print("Failed to load metadata for \(url): \(error)")
        }
    }

    mutating func updateLyrics(from text: String) {
        self.lyrics = parseLRC(text)
    }

    private func parseLRC(_ text: String) -> [LyricLine]? {
        var lines: [LyricLine] = []
        let pattern = "\\[(\\d{2}):(\\d{2})\\.(\\d{2,3})\\](.*)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }

        let stringLines = text.components(separatedBy: .newlines)
        for line in stringLines {
            let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
            if let match = regex.firstMatch(in: line, options: [], range: nsRange) {
                if let minRange = Range(match.range(at: 1), in: line),
                   let secRange = Range(match.range(at: 2), in: line),
                   let fracRange = Range(match.range(at: 3), in: line),
                   let textRange = Range(match.range(at: 4), in: line) {

                    let min = Double(line[minRange]) ?? 0
                    let sec = Double(line[secRange]) ?? 0
                    let fracString = String(line[fracRange])
                    let frac = (Double(fracString) ?? 0) / pow(10.0, Double(fracString.count))

                    let time = (min * 60) + sec + frac
                    let text = String(line[textRange]).trimmingCharacters(in: .whitespaces)

                    lines.append(LyricLine(time: time, text: text))
                }
            }
        }

        return lines.isEmpty ? nil : lines.sorted(by: { $0.time < $1.time })
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Track, rhs: Track) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Duration formatting

extension TimeInterval {
    /// "3:45" / "1:02:03"
    var asClock: String {
        guard isFinite, self >= 0 else { return "0:00" }
        let total = Int(self)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}
