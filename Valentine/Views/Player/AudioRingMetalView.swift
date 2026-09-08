import SwiftUI
import MetalKit

struct AudioRingMetalView: NSViewRepresentable {
    let engine: AudioEngine
    let active: Bool
    let reduceMotion: Bool
    let tint: Color

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> MTKView {
        let view = TransparentRingView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColorMake(0, 0, 0, 0)
        view.autoResizeDrawable = false
        view.preferredFramesPerSecond = 60
        view.isPaused = true
        view.wantsLayer = true
        view.layer?.isOpaque = false
        if let device = view.device, let renderer = try? AudioRingRenderer(device: device) {
            context.coordinator.renderer = renderer
            view.delegate = context.coordinator
        } else {
            // A quiet fallback when Metal is unavailable (e.g. remote rendering).
            let fallback = NSHostingView(rootView: Circle().stroke(tint.opacity(0.7), lineWidth: 2).padding(40))
            fallback.frame = view.bounds
            fallback.autoresizingMask = [.width, .height]
            view.addSubview(fallback)
        }
        return view
    }

    func updateNSView(_ view: MTKView, context: Context) {
        let coordinator = context.coordinator
        coordinator.sample = { [weak engine] in engine?.currentSpectrum ?? [] }
        let color = NSColor(tint).usingColorSpace(.sRGB) ?? .white
        let rgba = SIMD4<Float>(Float(color.redComponent), Float(color.greenComponent), Float(color.blueComponent), 1)
        let changed = coordinator.tint != rgba || coordinator.reduceMotion != reduceMotion
            || coordinator.trackID != engine.currentTrack?.id || view.isPaused == active
        if coordinator.trackID != engine.currentTrack?.id {
            coordinator.dynamics = AudioRingDynamics()
            coordinator.trackID = engine.currentTrack?.id
        }
        coordinator.tint = rgba
        coordinator.reduceMotion = reduceMotion
        coordinator.active = active
        view.isPaused = !active || coordinator.renderer == nil
        if !active { coordinator.lastTime = nil }
        if changed { view.draw() }
    }

    static func dismantleNSView(_ view: MTKView, coordinator: Coordinator) {
        view.isPaused = true
        view.delegate = nil
        coordinator.sample = { [] }
        coordinator.renderer = nil
    }

    @MainActor final class Coordinator: NSObject, MTKViewDelegate {
        var renderer: AudioRingRenderer?
        var dynamics = AudioRingDynamics()
        var sample: () -> [Float] = { [] }
        var tint = SIMD4<Float>(repeating: 1)
        var trackID: UUID?
        var lastTime: CFTimeInterval?
        var active = false
        var reduceMotion = false

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            guard let renderer, view.bounds.width > 0, view.bounds.height > 0 else { return }
            let scale = view.window?.backingScaleFactor ?? 2
            let side = min(1024, max(128, min(view.bounds.width, view.bounds.height) * scale))
            let size = CGSize(width: side, height: side)
            if view.drawableSize != size { view.drawableSize = size }
            guard let drawable = view.currentDrawable else { return }
            // Acquiring a drawable can wait for the display. Sample audio afterwards
            // so a blocked frame never carries a spectrum captured before that wait.
            let now = CACurrentMediaTime()
            if active && !reduceMotion {
                dynamics.advance(bands: sample(), delta: lastTime.map { now - $0 } ?? 1.0 / 60)
                lastTime = now
            }
            renderer.draw(drawable: drawable, dynamics: reduceMotion ? AudioRingDynamics() : dynamics, tint: tint)
        }
    }
}

private final class TransparentRingView: MTKView {
    override var isOpaque: Bool { false }
    override func layout() {
        super.layout()
        // MTKView stops requesting frames while paused; still paint after initial layout/resize.
        if isPaused { draw() }
    }
}
