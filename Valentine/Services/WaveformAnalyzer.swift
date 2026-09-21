import Accelerate
import AVFoundation
import CryptoKit
import Foundation

/// A lightweight, exact peak overview, independent of the ring's FFT analysis.
nonisolated enum WaveformAnalyzer {
    static let pointCount = 100
    static let cacheDirectory = URL.cachesDirectory
        .appendingPathComponent("Valentine/Waveforms-v1", isDirectory: true)

    static func cacheKey(for url: URL) throws -> String {
        // Read fresh attributes: URL resource values can retain an old modification date.
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attributes[.size] as? NSNumber)?.int64Value ?? -1
        let modified = (attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let identity = "v1|\(pointCount)|\(url.standardizedFileURL.path)|\(size)|\(modified)"
        return SHA256.hash(data: Data(identity.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func analyze(
        url: URL,
        cacheDirectory: URL = cacheDirectory,
        progress: @Sendable ([Float]) async -> Void = { _ in }
    ) async throws -> [Float] {
        try Task.checkCancellation()
        let key = try cacheKey(for: url)
        let cacheURL = cacheDirectory.appendingPathComponent(key).appendingPathExtension("json")
        if let data = try? Data(contentsOf: cacheURL),
           let points = try? JSONDecoder().decode([Float].self, from: data),
           points.count == pointCount,
           points.allSatisfy({ $0.isFinite && (0...1).contains($0) }) {
            try Task.checkCancellation()
            return points
        }

        let file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
        guard file.length > 0 else { return Array(repeating: 0, count: pointCount) }
        let capacity: AVAudioFrameCount = 65_536
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: capacity) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        var peaks = [Float](repeating: 0, count: pointCount)
        var lastPublication = Date.distantPast
        while file.framePosition < file.length {
            try Task.checkCancellation()
            let start = file.framePosition
            try file.read(into: buffer, frameCount: capacity)
            let count = Int(buffer.frameLength)
            guard count > 0, let channels = buffer.floatChannelData else {
                throw CocoaError(.fileReadCorruptFile)
            }
            var offset = 0
            while offset < count {
                let position = start + Int64(offset)
                let bin = min(pointCount - 1, Int(position * Int64(pointCount) / file.length))
                // Ceiling division exactly matches floor(frame * pointCount / length).
                let boundary = (Int64(bin + 1) * file.length + Int64(pointCount - 1)) / Int64(pointCount)
                let length = min(count - offset, Int(boundary - position))
                for channel in 0..<Int(file.processingFormat.channelCount) {
                    let samples = channels[channel].advanced(by: offset)
                    var peak: Float = 0
                    vDSP_maxmgv(samples, 1, &peak, vDSP_Length(length))
                    if !peak.isFinite {
                        // Malformed floating-point audio must not poison the whole overview.
                        peak = 0
                        for index in 0..<length where samples[index].isFinite {
                            peak = max(peak, abs(samples[index]))
                        }
                    }
                    peaks[bin] = max(peaks[bin], peak)
                }
                offset += length
            }
            // Show real decoded data early; unprocessed portions remain flat.
            if Date().timeIntervalSince(lastPublication) >= 0.08 {
                try Task.checkCancellation()
                await progress(normalized(peaks))
                lastPublication = Date()
            }
        }
        try Task.checkCancellation()
        let result = normalized(peaks)
        // Never reuse analysis if the source was edited during decoding.
        if (try? cacheKey(for: url)) == key {
            // Caching is optional: read-only/full disks must not break playback.
            try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            if let data = try? JSONEncoder().encode(result) {
                try? data.write(to: cacheURL, options: .atomic)
            }
        }
        return result
    }

    private static func normalized(_ peaks: [Float]) -> [Float] {
        let maximum = max(peaks.max() ?? 0, 0.000_001)
        return peaks.map { $0 / maximum }
    }
}
