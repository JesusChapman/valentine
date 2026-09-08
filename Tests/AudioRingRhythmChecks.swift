import AVFoundation
import Foundation

/// Offline PCM -> FFT -> playback-time sampling -> ring response regression.
@main struct AudioRingRhythmChecks {
    static func main() {
        checkResponseMapping()
        checkVocalPhrasing()
        for bpm in [120.0, 180.0, 240.0] {
            for amplitude: Float in [0.65, 0.04] {
                check(bpm: bpm, amplitude: amplitude)
            }
        }
    }

    static func checkVocalPhrasing() {
        func bands(_ level: Float) -> [Float] {
            var result = [Float](repeating: 0, count: 24)
            for index in 8..<16 { result[index] = level }
            return result
        }
        var state = AudioRingDynamics()
        for _ in 0..<120 { state.advance(bands: bands(0.65), delta: 1.0 / 60) }
        for _ in 0..<4 {
            for _ in 0..<12 { state.advance(bands: bands(0.50), delta: 1.0 / 60) }
            let quiet = state.body
            for _ in 0..<3 { state.advance(bands: bands(0.85), delta: 1.0 / 60) }
            let strong = state.body
            precondition(strong > quiet + 0.15, "Louder vocal syllables must open folds within 50 ms")
            for _ in 0..<9 { state.advance(bands: bands(0.50), delta: 1.0 / 60) }
            precondition(state.body < strong - 0.15, "Folds must retract when the vocal level falls")
            precondition(strong < 0.82, "Vocal response must remain bounded")
        }
        // No bass or percussion in this fixture: the old instantaneous peak
        // normalization flattened this vocal-only amplitude change.
        precondition(state.bass == 0)
        print("PASS repeated vocal-only syllables: stronger folds within 50 ms, retraction within 150 ms")
    }

    static func checkResponseMapping() {
        func settled(_ range: Range<Int>) -> AudioRingDynamics {
            var state = AudioRingDynamics()
            var bands = [Float](repeating: 0, count: 24)
            for index in range { bands[index] = 0.85 }
            for _ in 0..<120 { state.advance(bands: bands, delta: 1.0 / 60) }
            return state
        }
        let kick = settled(0..<4)
        let vocalBand = settled(8..<16)
        let cymbal = settled(20..<24)
        precondition(kick.bass > 0.5 && kick.intensity > 0.2)
        precondition(kick.body < 0.001 && cymbal.body < 0.001,
            "Bass and high percussion must not drive vocal-band folds")
        precondition(vocalBand.body > 0.4 && vocalBand.body < 0.85)
        precondition(vocalBand.bass < 0.001 && vocalBand.intensity > 0.2,
            "Music without bass must still affect overall size")
        var released = vocalBand
        for _ in 0..<120 { released.advance(bands: [], delta: 1.0 / 60) }
        precondition(released.body < 0.001 && released.intensity < 0.001)
        print("PASS independent size/vocal-band response and silence decay")
    }

    static func check(bpm: Double, amplitude: Float) {
        let rate = 48000.0
        let block = 960
        let step = Double(block) / rate
        let period = 60 / bpm
        let duration = 4.0
        let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(block))!
        buffer.frameLength = AVAudioFrameCount(block)
        let channels = buffer.floatChannelData!
        let analyzer = SpectrumAnalyzer(sampleRate: rate, blockSize: block)!
        var spectra: [[Float]] = []
        for frame in 0..<Int(duration / step) {
            for index in 0..<block {
                let time = Double(frame * block + index) / rate
                let phase = max(0, time - 0.5).truncatingRemainder(dividingBy: period)
                let envelope = time >= 0.5 && phase < 0.08 ? exp(-phase / 0.022) : 0
                let wave = sin(2 * .pi * 70 * phase) + 0.25 * sin(2 * .pi * 2500 * phase)
                channels[0][index] = amplitude * Float(envelope * wave)
                channels[1][index] = -channels[0][index] // Opposite-phase stereo must not cancel.
            }
            spectra.append(analyzer.analyze(channels: channels, count: 2, frames: block))
        }
        var dynamics = AudioRingDynamics()
        var responses: [(time: Double, bass: Float, pulse: Float)] = []
        for frame in 0..<Int(duration * 60) {
            let time = Double(frame) / 60
            let position = max(0, time / step - 0.5)
            let index = min(Int(position), spectra.count - 1)
            let next = min(index + 1, spectra.count - 1)
            let fraction = Float(position - Double(index))
            let bands = zip(spectra[index], spectra[next]).map { $0 * (1 - fraction) + $1 * fraction }
            dynamics.advance(bands: bands, delta: 1.0 / 60)
            responses.append((time, dynamics.bass, dynamics.transient))
        }
        var delays: [Double] = []
        var beat = 0.5
        while beat < duration - period {
            // Check the sustained bass envelope as well as onset decay, not only
            // the short transient signal consumed by the shader.
            let hit = responses.first { $0.time >= beat - 0.0001 && $0.time <= beat + 0.05 && $0.bass > 0.15 }
            precondition(hit != nil, "Missed beat at \(bpm) BPM / amplitude \(amplitude)")
            delays.append(hit!.time - beat)
            let trough = responses.last { $0.time < beat + period - 0.035 }!
            precondition(trough.pulse < 0.23, "Transient must settle between beats")
            beat += period
        }
        precondition(responses.filter { $0.time < 0.45 }.allSatisfy { $0.bass == 0 && $0.pulse == 0 })
        print("PASS \(Int(bpm)) BPM, amplitude \(amplitude): max onset delay \(Int((delays.max() ?? 0) * 1000)) ms; distinct beats, silent lead-in, stereo-safe")
    }
}
