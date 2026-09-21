// Run with swiftc alongside WaveformAnalyzer.swift and SpectrumAnalyzer.swift.
import AVFoundation
import Foundation

actor ProgressProbe {
    var first: Date?
    var count = 0
    func record() { if first == nil { first = Date() }; count += 1 }
}

@main struct WaveformChecks {
    static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("fixture.caf")
        let cache = root.appendingPathComponent("cache")
        try fixture(url, frames: 44_100 * 60)
        let start = Date()
        let expected = try legacy(url)
        let legacyTime = Date().timeIntervalSince(start)
        let probe = ProgressProbe()
        let fastStart = Date()
        let actual = try await WaveformAnalyzer.analyze(url: url, cacheDirectory: cache) { _ in
            await probe.record()
        }
        let fastTime = Date().timeIntervalSince(fastStart)
        precondition(zip(expected, actual).allSatisfy { abs($0 - $1) < 0.00001 }, "Peak mismatch")
        let first = await probe.first
        precondition(first != nil, "Missing progressive results")
        let hitProbe = ProgressProbe()
        let hitStart = Date()
        let cached = try await WaveformAnalyzer.analyze(url: url, cacheDirectory: cache) { _ in
            await hitProbe.record()
        }
        let hitTime = Date().timeIntervalSince(hitStart)
        let hitCount = await hitProbe.count
        precondition(cached == actual && hitCount == 0, "Cache miss")
        let key = try WaveformAnalyzer.cacheKey(for: url)
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let modification = attributes[.modificationDate] as! Date
        try FileManager.default.setAttributes([.modificationDate: modification.addingTimeInterval(2)], ofItemAtPath: url.path)
        let changedKey = try WaveformAnalyzer.cacheKey(for: url)
        precondition(key != changedKey, "Stale file identity")
        let brokenCache = cache.appendingPathComponent(changedKey).appendingPathExtension("json")
        try Data("broken".utf8).write(to: brokenCache)
        let repaired = try await WaveformAnalyzer.analyze(url: url, cacheDirectory: cache)
        precondition(repaired == expected, "Corrupted cache was not rebuilt")
        let cancelled = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await WaveformAnalyzer.analyze(url: url, cacheDirectory: cache)
        }
        do { _ = try await cancelled.value; preconditionFailure("Ignored cancellation") }
        catch is CancellationError {}
        let cancelledCache = root.appendingPathComponent("cancelled-cache")
        let midDecode = Task {
            try await WaveformAnalyzer.analyze(url: url, cacheDirectory: cancelledCache) { _ in
                withUnsafeCurrentTask { $0?.cancel() }
            }
        }
        do { _ = try await midDecode.value; preconditionFailure("Ignored mid-decode cancellation") }
        catch is CancellationError {}
        precondition(!FileManager.default.fileExists(atPath: cancelledCache.path), "Cached incomplete data")
        for frames in [0, 1, 53, 101] {
            let short = root.appendingPathComponent("short-\(frames).caf")
            try fixture(short, frames: frames, silent: true)
            let points = try await WaveformAnalyzer.analyze(url: short, cacheDirectory: cache)
            precondition(points.count == 100 && points.allSatisfy { $0 == 0 }, "Silent/short file failed")
        }
        print(String(format: "60s stereo fixture: old FFT+wave %.3fs; new wave %.3fs; first update %.3fs; disk cache %.4fs",
                     legacyTime, fastTime, first!.timeIntervalSince(fastStart), hitTime))
        let aac = root.appendingPathComponent("compressed.m4a")
        try fixture(aac, frames: 44_100 * 60, compressed: true)
        let aacOldStart = Date()
        let aacExpected = try legacy(aac)
        let aacOldTime = Date().timeIntervalSince(aacOldStart)
        let aacProbe = ProgressProbe()
        let aacStart = Date()
        let aacPoints = try await WaveformAnalyzer.analyze(url: aac, cacheDirectory: cache) { _ in
            await aacProbe.record()
        }
        let aacTime = Date().timeIntervalSince(aacStart)
        let aacFirst = await aacProbe.first!
        precondition(zip(aacPoints, aacExpected).allSatisfy { abs($0 - $1) < 0.00001 }, "AAC peak mismatch")
        print(String(format: "60s AAC fixture: old FFT+wave %.3fs; new wave %.3fs; first update %.3fs",
                     aacOldTime, aacTime, aacFirst.timeIntervalSince(aacStart)))
        print("PASS: exact peaks, progressive loading, disk cache, invalidation, corrupt cache, cancellation, silence and short files")
    }

    static func fixture(_ url: URL, frames: Int, silent: Bool = false, compressed: Bool = false) throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        var settings = format.settings
        settings[AVLinearPCMIsNonInterleaved] = false
        if compressed {
            settings = [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44_100,
                        AVNumberOfChannelsKey: 2, AVEncoderBitRateKey: 192_000]
        }
        let file = try AVAudioFile(forWriting: url, settings: settings)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 8192)!
        var offset = 0
        while offset < frames {
            let count = min(8192, frames - offset)
            buffer.frameLength = AVAudioFrameCount(count)
            for i in 0..<count {
                let position = offset + i
                let amplitude = Float(0.1 + 0.9 * Double((position / 4410) % 10) / 9)
                let value = silent ? 0 : amplitude * Float(sin(Double(position) * 0.063))
                buffer.floatChannelData![0][i] = value
                buffer.floatChannelData![1][i] = -value * 0.7
            }
            try file.write(from: buffer)
            offset += count
        }
    }

    // Original wave + FFT loop retained here solely for correctness and timing comparison.
    static func legacy(_ url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let capacity = AVAudioFrameCount(file.processingFormat.sampleRate * 0.02)
        let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: capacity)!
        let analyzer = SpectrumAnalyzer(sampleRate: file.processingFormat.sampleRate, blockSize: Int(capacity))!
        var peaks = [Float](repeating: 0, count: 100)
        var spectra: [[Float]] = []
        var energy: Double = 0
        while file.framePosition < file.length {
            let offset = file.framePosition
            try file.read(into: buffer, frameCount: capacity)
            let samples = buffer.floatChannelData!
            let length = Int(buffer.frameLength)
            for i in 0..<length {
                let bin = min(99, Int((offset + Int64(i)) * 100 / file.length))
                for channel in 0..<2 {
                    let value = samples[channel][i]
                    peaks[bin] = max(peaks[bin], abs(value))
                    energy += Double(value) * Double(value)
                }
            }
            spectra.append(analyzer.analyze(channels: samples, count: 2, frames: length))
        }
        precondition(!spectra.isEmpty && energy > 0)
        let maximum = max(peaks.max() ?? 0, 0.000001)
        return peaks.map { $0 / maximum }
    }
}
