//  AudirvanaProgressBar.swift
//  Waveform seek bar — played bars in accent, drag to scrub.

import SwiftUI

struct AudirvanaProgressBar: View {
    @ObservedObject var engine: AudioEngine
    @State private var dragProgress: CGFloat? = nil
    @State private var hovering = false

    private var progress: CGFloat {
        if let d = dragProgress { return d }
        guard engine.duration > 0 else { return 0 }
        return CGFloat(engine.currentTime / engine.duration)
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(engine.currentTime.asClock)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 42, alignment: .trailing)

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let points = displayPoints(width: w)
                let playedCount = Int((CGFloat(points.count) * progress).rounded())

                HStack(alignment: .center, spacing: barSpacing) {
                    ForEach(points.indices, id: \.self) { i in
                        Capsule()
                            .fill(i < playedCount ? Color.accentColor
                                                  : Color.primary.opacity(0.22))
                            .frame(height: max(3, points[i] * h))
                            .frame(maxWidth: .infinity)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7),
                                       value: points[i])
                    }
                }
                .frame(width: w, height: h, alignment: .center)
                .overlay(alignment: .leading) {
                    // Subtle playhead line on hover/drag.
                    if hovering || dragProgress != nil {
                        Rectangle()
                            .fill(Color.white.opacity(0.85))
                            .frame(width: 1.5, height: h)
                            .offset(x: max(0, min(w, w * progress)))
                    }
                }
                .contentShape(Rectangle())
                .onHover { hovering = $0 }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in dragProgress = clamp(v.location.x / w) }
                        .onEnded { v in
                            let pct = clamp(v.location.x / w)
                            engine.seek(to: TimeInterval(pct) * engine.duration)
                            dragProgress = nil
                        }
                )
            }
            .frame(height: 26)

            Text("-\(max(0, engine.duration - engine.currentTime).asClock)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 46, alignment: .leading)
        }
    }

    private let barSpacing: CGFloat = 2

    /// Use the real waveform when available; otherwise a gentle synthetic
    /// pattern so the bar still looks like a waveform while loading.
    private func displayPoints(width: CGFloat) -> [CGFloat] {
        if !engine.waveformPoints.isEmpty {
            return engine.waveformPoints.map { CGFloat($0) }
        }
        let count = max(24, Int(width / 4))
        return (0..<count).map { i in
            // Soft pseudo-waveform: a couple of sine harmonics, normalized 0.2...1.
            let t = CGFloat(i) / CGFloat(count)
            let v = 0.55 + 0.35 * sin(t * .pi * 6) * sin(t * .pi * 1.3)
            return max(0.2, min(1, v))
        }
    }

    private func clamp(_ x: CGFloat) -> CGFloat { max(0, min(1, x)) }
}
