import Foundation

/// Independent rhythmic size and vocal-band membrane envelopes.
/// Vocal-band energy is a proxy, not source separation or singer detection.
nonisolated struct AudioRingDynamics {
    private(set) var bass: Float = 0
    private(set) var body: Float = 0
    private(set) var intensity: Float = 0
    private(set) var treble: Float = 0
    private(set) var transient: Float = 0
    private(set) var evolution: Float = 0
    private var bassAverage: Float = 0
    private var intensityAverage: Float = 0
    private var referencePeak: Float = 0.10
    private var vocalReference: Float = 0.08

    mutating func advance(bands: [Float], delta: Double) {
        let dt = Float(min(max(delta.isFinite ? delta : 0, 0), 0.1))
        guard dt > 0 else { return }
        // Recover linear amplitudes from SpectrumAnalyzer's [-65, 0] dB encoding.
        let amplitudes = (0..<24).map { index -> Float in
            guard bands.indices.contains(index), bands[index].isFinite else { return 0 }
            let level = min(max(bands[index], 0), 1)
            return max(0, pow(10, (level * 65 - 65) / 20) - 0.0018)
        }
        let peak = amplitudes.max() ?? 0
        // Slow gain recovery makes quieter masters responsive without pumping on each kick.
        referencePeak = max(0.008, peak, referencePeak * exp(-dt / 3.0))
        // Leave headroom: sqrt-normalizing to 1 followed by a gain/clamp pinned the
        // deformation at its ceiling during dense music, erasing musical accents.
        let levels = amplitudes.map { min(0.82, pow($0 / (referencePeak * 1.6), 0.72)) }
        func maximum(_ range: Range<Int>) -> Float { range.map { levels[$0] }.max() ?? 0 }
        let low = maximum(0..<7)
        let overall = sqrt(levels.reduce(0) { $0 + $1 * $1 } / Float(levels.count))
        // SpectrumAnalyzer's logarithmic bands: approximately 210–3800 Hz.
        // Taper the edges to emphasize vocal body/presence while excluding bass
        // kicks and the highest cymbals. Instruments in this range still respond.
        let weights: [Float] = [0.25, 0.5, 0.75, 1, 1, 1, 1, 1, 1, 0.75, 0.5, 0.25]
        let vocalPower = weights.enumerated().reduce(Float(0)) { sum, entry in
            // Use linear energy, before the instantaneous global peak gain.
            // Otherwise a stronger syllable raises both numerator and denominator,
            // cancelling the very intensity change the folds should display.
            let level = amplitudes[entry.offset + 6]
            return sum + level * level * entry.element
        }
        let vocalAmplitude = sqrt(vocalPower / weights.reduce(0, +))
        // A separate, slow reference follows phrases, not individual syllables.
        // Preserve fast level changes while allowing different masters to respond.
        let referenceTarget = max(0.008, vocalAmplitude)
        let referenceTime: Float = referenceTarget > vocalReference ? 0.8 : 5.0
        vocalReference += (referenceTarget - vocalReference) * (1 - exp(-dt / referenceTime))
        let vocalRatio = vocalAmplitude / vocalReference
        let vocal = 0.82 * vocalRatio / (vocalRatio + 0.65)
        func follow(_ previous: Float, _ target: Float, attack: Float, release: Float) -> Float {
            previous + (target - previous) * (1 - exp(-dt / (target > previous ? attack : release)))
        }
        bass = follow(bass, low, attack: 0.008, release: 0.075)
        intensity = follow(intensity, overall, attack: 0.015, release: 0.110)
        // Open on each syllable, then retract between syllables without a hard cut.
        body = follow(body, vocal, attack: 0.022, release: 0.100)
        treble = follow(treble, maximum(17..<24), attack: 0.006, release: 0.060)
        let onset = min(1, max(0, low - bassAverage - 0.025) * 3.4
            + max(0, overall - intensityAverage - 0.025) * 1.4)
        transient = follow(transient, onset, attack: 0.004, release: 0.055)
        bassAverage += (low - bassAverage) * (1 - exp(-dt / 0.16))
        intensityAverage += (overall - intensityAverage) * (1 - exp(-dt / 0.20))
        // Smooth advection is independent of beat acceleration; the audio acts directly
        // on the membrane, so each hit deforms it instead of merely speeding up a loop.
        evolution += dt * 0.85
    }
}
