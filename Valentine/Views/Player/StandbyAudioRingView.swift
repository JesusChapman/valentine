import SwiftUI

/// A folded, luminous membrane, not a circular arrangement of spectrum bars.
/// FFT bands drive its width/detail; bass drives the breathing radius.
struct StandbyAudioRingView: View {
    @ObservedObject var engine: AudioEngine
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private var running: Bool {
        engine.isPlaying && !reduceMotion && scenePhase != .background
    }

    var body: some View {
        AudioRingMetalView(engine: engine, active: running, reduceMotion: reduceMotion,
                           tint: engine.activeControlTint(for: .dark))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
