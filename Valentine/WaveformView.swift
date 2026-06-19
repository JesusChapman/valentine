import SwiftUI

struct WaveformView: View {
    @ObservedObject var engine: AudioEngine
    
    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    if engine.waveformPoints.isEmpty {
                        ForEach(0..<50, id: \.self) { index in
                            let progress = CGFloat(index) / 50.0
                            let isPlayed = progress <= currentProgress
                            Capsule()
                                .fill(isPlayed ? Color.primary : Color.primary.opacity(0.2))
                                .frame(height: 10)
                        }
                    } else {
                        ForEach(Array(engine.waveformPoints.enumerated()), id: \.offset) { index, point in
                            let progress = CGFloat(index) / CGFloat(engine.waveformPoints.count)
                            let isPlayed = progress <= currentProgress
                            
                            Capsule()
                                .fill(isPlayed ? Color.primary : Color.primary.opacity(0.3))
                                .frame(height: max(4, CGFloat(point) * geometry.size.height))
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: point)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            seek(to: value.location.x, in: geometry.size.width)
                        }
                )
            }
            
            HStack {
                Text(formatTime(engine.currentTime))
                Spacer()
                Text("-\(formatTime(max(0, engine.duration - engine.currentTime)))")
            }
            .font(.caption)
            .foregroundColor(.primary.opacity(0.8))
            .monospacedDigit()
        }
    }
    
    private var currentProgress: CGFloat {
        guard engine.duration > 0 else { return 0 }
        return CGFloat(engine.currentTime / engine.duration)
    }
    
    private func seek(to xOffset: CGFloat, in width: CGFloat) {
        let percentage = max(0, min(1, xOffset / width))
        let targetTime = TimeInterval(percentage) * engine.duration
        engine.seek(to: targetTime)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
