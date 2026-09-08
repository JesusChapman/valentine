import AVFoundation
import MetalKit

/// Offline visual review using the same FFT, clock interpolation, envelopes and GPU
/// renderer as the app. Usage: check input.wav ring.metallib output.mp4 ffmpeg-path
@main struct RecordedAudioRingCheck {
    @MainActor static func main() throws {
        precondition(CommandLine.arguments.count == 5)
        let input = CommandLine.arguments[1]
        let file = try AVAudioFile(forReading: URL(fileURLWithPath: input))
        let block = Int(file.processingFormat.sampleRate * 0.02)
        let analyzer = SpectrumAnalyzer(sampleRate: file.processingFormat.sampleRate, blockSize: block)!
        let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(block))!
        var spectrum: [[Float]] = []
        while file.framePosition < file.length {
            try file.read(into: buffer, frameCount: AVAudioFrameCount(block))
            spectrum.append(analyzer.analyze(channels: buffer.floatChannelData!,
                count: Int(buffer.format.channelCount), frames: Int(buffer.frameLength)))
        }
        let device = MTLCreateSystemDefaultDevice()!
        let library = try device.makeLibrary(URL: URL(fileURLWithPath: CommandLine.arguments[2]))
        let renderer = try AudioRingRenderer(device: device, library: library)
        let side = 512
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
            width: side, height: side, mipmapped: false)
        descriptor.storageMode = .shared
        descriptor.usage = [.renderTarget, .shaderRead]
        let target = device.makeTexture(descriptor: descriptor)!
        let encoder = Process()
        encoder.executableURL = URL(fileURLWithPath: CommandLine.arguments[4])
        encoder.arguments = ["-v", "error", "-y", "-f", "rawvideo", "-pixel_format", "bgra",
            "-video_size", "\(side)x\(side)", "-framerate", "60", "-i", "pipe:0", "-i", input,
            "-c:v", "libx264", "-crf", "18", "-pix_fmt", "yuv420p", "-c:a", "aac",
            "-shortest", CommandLine.arguments[3]]
        let pipe = Pipe()
        encoder.standardInput = pipe
        try encoder.run()
        var dynamics = AudioRingDynamics()
        var bytes = [UInt8](repeating: 0, count: side * side * 4)
        var minimumBody: Float = .greatestFiniteMagnitude
        var maximumBody: Float = 0
        let count = Int(Double(file.length) / file.processingFormat.sampleRate * 60)
        for frame in 0..<count {
            let position = max(0, Double(frame) / 60 / 0.02 - 0.5)
            let first = min(spectrum.count - 1, Int(position))
            let second = min(spectrum.count - 1, first + 1)
            let fraction = Float(position - floor(position))
            let bands = (0..<24).map { spectrum[first][$0] + (spectrum[second][$0] - spectrum[first][$0]) * fraction }
            dynamics.advance(bands: bands, delta: 1.0 / 60)
            minimumBody = min(minimumBody, dynamics.body)
            maximumBody = max(maximumBody, dynamics.body)
            let command = renderer.queue.makeCommandBuffer()!
            precondition(renderer.encode(command: command, target: target, dynamics: dynamics,
                tint: SIMD4(0.03, 0.47, 1, 1)))
            command.commit()
            command.waitUntilCompleted()
            if let error = command.error { throw error }
            target.getBytes(&bytes, bytesPerRow: side * 4,
                from: MTLRegionMake2D(0, 0, side, side), mipmapLevel: 0)
            try pipe.fileHandleForWriting.write(contentsOf: Data(bytes))
        }
        try pipe.fileHandleForWriting.close()
        encoder.waitUntilExit()
        precondition(encoder.terminationStatus == 0)
        print("Rendered \(count) frames at 60 fps with recorded audio; deformation range \(minimumBody)...\(maximumBody).")
    }
}
