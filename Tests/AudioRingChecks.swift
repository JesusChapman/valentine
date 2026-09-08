import AppKit
import MetalKit

@main struct RingChecks {
    @MainActor static func main() throws {
        var thirty = AudioRingDynamics()
        var sixty = AudioRingDynamics()
        for _ in 0..<30 { thirty.advance(bands: [Float](repeating: 0.8, count: 24), delta: 1.0 / 30) }
        for _ in 0..<60 { sixty.advance(bands: [Float](repeating: 0.8, count: 24), delta: 1.0 / 60) }
        precondition(abs(thirty.bass - sixty.bass) < 0.001)
        var dynamics = AudioRingDynamics()
        for _ in 0..<120 { dynamics.advance(bands: [Float](repeating: 0.85, count: 24), delta: 1.0 / 60) }
        precondition(dynamics.bass > 0.5 && dynamics.body > 0.2 && dynamics.body < 0.9)
        for _ in 0..<120 { dynamics.advance(bands: [], delta: 1.0 / 60) }
        precondition(dynamics.bass < 0.001 && dynamics.body < 0.001)
        dynamics.advance(bands: [.nan, .infinity, -1], delta: .nan)
        precondition(dynamics.evolution.isFinite && dynamics.bass.isFinite)
        guard let device = MTLCreateSystemDefaultDevice() else { fatalError("No GPU") }
        let library = try device.makeLibrary(URL: URL(fileURLWithPath: "\(CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/valentine-ring.metallib")"))
        let renderer = try AudioRingRenderer(device: device, library: library)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 800, height: 800, mipmapped: false)
        descriptor.storageMode = .shared
        descriptor.usage = [.renderTarget, .shaderRead]
        let target = device.makeTexture(descriptor: descriptor)!
        var frames: [[UInt8]] = []
        var gpuTimes: [Double] = []
        for frame in 0..<4 {
            for index in 0..<360 {
                let bands = (0..<24).map { band in Float(0.65 + 0.27 * sin(Double(index) * 0.12 + Double(band) * 0.15)) }
                dynamics.advance(bands: bands, delta: 1.0 / 60)
            }
            let command = renderer.queue.makeCommandBuffer()!
            precondition(renderer.encode(command: command, target: target, dynamics: dynamics, tint: SIMD4(0.03, 0.47, 1, 1)))
            command.commit()
            command.waitUntilCompleted()
            if let error = command.error { throw error }
            gpuTimes.append((command.gpuEndTime - command.gpuStartTime) * 1000)
            var bytes = [UInt8](repeating: 0, count: 800 * 800 * 4)
            target.getBytes(&bytes, bytesPerRow: 3200, from: MTLRegionMake2D(0, 0, 800, 800), mipmapLevel: 0)
            frames.append(bytes)
            precondition(bytes.enumerated().contains { $0.offset % 4 == 3 && $0.element > 32 }, "Ring must be visible")
            precondition(bytes[3] == 0, "Corners must remain transparent")
            let provider = CGDataProvider(data: Data(bytes) as CFData)!
            let cg = CGImage(width: 800, height: 800, bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: 3200, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue).union(.byteOrder32Little),
                provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
            let context = CGContext(data: nil, width: 800, height: 800, bitsPerComponent: 8, bytesPerRow: 3200,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.setFillColor(NSColor.black.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: 800, height: 800))
            context.draw(cg, in: CGRect(x: 0, y: 0, width: 800, height: 800))
            let image = NSBitmapImageRep(cgImage: context.makeImage()!)
            try image.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "/tmp")/valentine-metal-ring-\(frame).png"))
        }
        precondition(frames[0] != frames[1], "Animation must change geometry")
        // Hold bass and phase constant. A louder mid/high spectrum must create
        // interior folds, not merely enlarge the silhouette of the circle.
        var quiet = AudioRingDynamics()
        var folded = AudioRingDynamics()
        var quietBands = [Float](repeating: 0.25, count: 24)
        // Band 6 is already in the tapered vocal range, so exclude it from
        // the bass-only fixture used to measure independent vocal deformation.
        for band in 0..<6 { quietBands[band] = 0.90 }
        var foldedBands = quietBands
        for band in 7..<21 { foldedBands[band] = 0.90 }
        for _ in 0..<360 {
            quiet.advance(bands: quietBands, delta: 1.0 / 60)
            folded.advance(bands: foldedBands, delta: 1.0 / 60)
        }
        precondition(abs(quiet.bass - folded.bass) < 0.001)
        precondition(quiet.evolution == folded.evolution)
        func interiorDensity(_ state: AudioRingDynamics) throws -> Double {
            let command = renderer.queue.makeCommandBuffer()!
            precondition(renderer.encode(command: command, target: target, dynamics: state,
                tint: SIMD4(0.03, 0.47, 1, 1)))
            command.commit()
            command.waitUntilCompleted()
            if let error = command.error { throw error }
            var pixels = [UInt8](repeating: 0, count: 800 * 800 * 4)
            target.getBytes(&pixels, bytesPerRow: 3200, from: MTLRegionMake2D(0, 0, 800, 800), mipmapLevel: 0)
            var density: Double = 0
            // Normalize the sampling region by the independently driven radius:
            // louder vocals also increase overall energy, but size is not a fold.
            let radius = Double(0.66 + state.bass * 0.12 + state.intensity * 0.07 + state.transient * 0.055) * 400
            let interiorRadiusSquared = pow(radius * 0.85, 2)
            for y in 0..<800 {
                for x in 0..<800 where Double((x - 400) * (x - 400) + (y - 400) * (y - 400)) < interiorRadiusSquared {
                    density += Double(pixels[(y * 800 + x) * 4 + 3]) / 255
                }
            }
            return density / (.pi * interiorRadiusSquared)
        }
        let quietInterior = try interiorDensity(quiet)
        let foldedInterior = try interiorDensity(folded)
        precondition(foldedInterior > quietInterior * 1.5,
            "Mid/high energy must visibly fold the membrane into the interior at constant bass")
        print("PASS interior density at constant bass/phase: \(quietInterior) -> \(foldedInterior)")
        // Warm-frame budget across changing input, not four cold screenshots.
        var timings: [Double] = []
        for frame in 0..<180 {
            dynamics.advance(bands: (0..<24).map { Float(0.6 + 0.3 * sin(Double(frame) * 0.1 + Double($0))) }, delta: 1.0 / 60)
            let command = renderer.queue.makeCommandBuffer()!
            precondition(renderer.encode(command: command, target: target, dynamics: dynamics, tint: SIMD4(0.03, 0.47, 1, 1)))
            command.commit()
            command.waitUntilCompleted()
            if let error = command.error { throw error }
            if frame >= 20 { timings.append((command.gpuEndTime - command.gpuStartTime) * 1000) }
        }
        timings.sort()
        print("GPU warm frames at 800px: median \(timings[timings.count / 2]) ms, p95 \(timings[Int(Double(timings.count) * 0.95)]) ms; 60Hz budget 16.67 ms (offscreen, excludes UI/presentation).")
        print("PASS envelopes, silence, invalid input, GPU rendering, transparency, changing frames. GPU ms: \(gpuTimes)")
    }
}
