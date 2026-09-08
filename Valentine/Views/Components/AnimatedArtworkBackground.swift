import SwiftUI

/// A small offscreen artwork layer keeps the cost independent of window size.
struct AnimatedArtworkBackground: View {
    let artwork: Image?
    let artworkID: UUID?
    let engine: AudioEngine
    @ObservedObject private var settings = AppSettings.shared

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var epoch = Date()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(nsColor: .windowBackgroundColor)

                if let artwork {
                    TimelineView(ArtworkTimelineSchedule(
                        start: epoch,
                        paused: reduceMotion || scenePhase == .background
                    )) { context in
                        let time = reduceMotion ? 0 : context.date.timeIntervalSince(epoch)
                        artwork
                            .resizable()
                            .scaledToFill()
                            .frame(width: 320, height: 320)
                            .clipped()
                            .blur(radius: 18, opaque: true)
                            .layerEffect(
                                ShaderLibrary.artworkFlow(
                                    .float(Float(time)),
                                    .float(settings.musicReactiveBackground ? engine.backgroundPulse : 0)
                                ),
                                maxSampleOffset: CGSize(width: 320, height: 320),
                                isEnabled: !reduceMotion
                            )
                            .saturation(colorScheme == .dark ? 1.15 : 0.85)
                            .scaleEffect(
                                x: geometry.size.width / 320,
                                y: geometry.size.height / 320
                            )
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                    .id(artworkID)
                    .transition(.opacity)

                    (colorScheme == .dark ? Color.black : Color.white)
                        .opacity(colorScheme == .dark ? 0.36 : 0.58)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .animation(reduceMotion ? nil : .easeInOut(duration: 1.4), value: artworkID)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A periodic clock also runs when a visible macOS window loses key status.
/// A paused schedule emits one frame and then stops requesting updates.
private struct ArtworkTimelineSchedule: TimelineSchedule {
    let start: Date
    let paused: Bool

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> AnySequence<Date> {
        if paused {
            return AnySequence([startDate])
        }
        return AnySequence(PeriodicTimelineSchedule(from: start, by: 1.0 / 30.0)
            .entries(from: startDate, mode: mode))
    }
}
