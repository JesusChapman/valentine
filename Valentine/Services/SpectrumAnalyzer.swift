import Accelerate
import Foundation

/// Worker-local Fourier analysis; never shared across tasks or actors.
nonisolated final class SpectrumAnalyzer {
    static let bandCount = 24
    private let setup: vDSP_DFT_Setup
    private let size: Int
    private let window: [Float]
    private let ranges: [Range<Int>]
    private var real: [Float]
    private var imaginary: [Float]
    private var outputReal: [Float]
    private var outputImaginary: [Float]

    init?(sampleRate: Double, blockSize: Int) {
        guard sampleRate > 0, blockSize > 0 else { return nil }
        var size = 1
        while size < max(2048, blockSize) { size *= 2 }
        guard let setup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(size), .FORWARD) else { return nil }
        self.setup = setup
        self.size = size
        real = Array(repeating: 0, count: size)
        imaginary = real
        outputReal = real
        outputImaginary = real
        window = (0..<blockSize).map {
            Float(0.5 - 0.5 * cos(2 * .pi * Double($0) / Double(max(1, blockSize - 1))))
        }
        let low = 50.0
        let high = max(low, min(16000, sampleRate / 2))
        ranges = (0..<Self.bandCount).map { band in
            let lower = low * pow(high / low, Double(band) / Double(Self.bandCount))
            let upper = low * pow(high / low, Double(band + 1) / Double(Self.bandCount))
            let first = min(size / 2 - 1, max(1, Int(lower * Double(size) / sampleRate)))
            let end = min(size / 2, max(first + 1, Int(upper * Double(size) / sampleRate)))
            return first..<end
        }
    }

    deinit { vDSP_DFT_DestroySetup(setup) }

    func analyze(channels: UnsafePointer<UnsafeMutablePointer<Float>>, count: Int, frames: Int) -> [Float] {
        var powers = [Float](repeating: 0, count: Self.bandCount)
        let length = min(frames, window.count)
        guard count > 0, length > 0 else { return powers }
        // Sum channel powers, avoiding cancellation from opposite stereo phases.
        for channel in 0..<count {
            for index in 0..<size { real[index] = 0 }
            for index in 0..<length {
                let sample = channels[channel][index]
                real[index] = sample.isFinite ? sample * window[index] : 0
            }
            vDSP_DFT_Execute(setup, real, imaginary, &outputReal, &outputImaginary)
            for band in ranges.indices {
                var peak: Float = 0
                for bin in ranges[band] {
                    peak = max(peak, outputReal[bin] * outputReal[bin] + outputImaginary[bin] * outputImaginary[bin])
                }
                powers[band] += peak / Float(count)
            }
        }
        return powers.indices.map { band in
            let amplitude = sqrt(powers[band]) * 4 / Float(window.count)
            let db = 20 * log10(max(amplitude, 0.000_001))
            // Keep transients intact. The renderer owns the single attack/release stage.
            return min(1, max(0, (db + 65) / 65))
        }
    }
}
