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
    var album: String?
    var albumArt: Image?
    var duration: TimeInterval
    var lyrics: [LyricLine]?

    init(url: URL) {
        self.id = UUID()
        self.url = url
        self.title = url.deletingPathExtension().lastPathComponent
        self.artist = "Unknown Artist"
        self.album = nil
        self.albumArt = nil
        self.duration = 0
        self.lyrics = nil
    }
    
    mutating func loadMetadata() async {
        let asset = AVAsset(url: url)
        
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
                           let nsImage = NSImage(data: value) {
                            self.albumArt = Image(nsImage: nsImage)
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
