import MetalKit
import MetalPerformanceShaders

/// Shared GPU pipeline used by the live view and the offscreen regression checks.
@MainActor final class AudioRingRenderer {
    struct Uniforms {
        var motion: SIMD4<Float>
        var color: SIMD4<Float>
        var viewport: SIMD4<Float>
        var energy: SIMD4<Float>
    }
    let device: MTLDevice
    let queue: MTLCommandQueue
    private let particles: MTLRenderPipelineState
    private let fieldPipeline: MTLComputePipelineState
    private let field: MTLTexture
    private let composite: MTLRenderPipelineState
    private let blur: MPSImageGaussianBlur
    private var density: MTLTexture?
    private var bloom: MTLTexture?
    private let inFlight = DispatchSemaphore(value: 1)

    init(device: MTLDevice, library: MTLLibrary? = nil) throws {
        self.device = device
        guard let queue = device.makeCommandQueue(), let library = library ?? device.makeDefaultLibrary() else {
            throw NSError(domain: "AudioRing", code: 1, userInfo: [NSLocalizedDescriptionKey: "Metal library unavailable"])
        }
        self.queue = queue
        guard let function = library.makeFunction(name: "audioRingField") else {
            throw NSError(domain: "AudioRing", code: 2)
        }
        fieldPipeline = try device.makeComputePipelineState(function: function)
        let fieldDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float,
            width: 128, height: 128, mipmapped: false)
        fieldDescriptor.usage = [.shaderRead, .shaderWrite]
        fieldDescriptor.storageMode = .private
        guard let field = device.makeTexture(descriptor: fieldDescriptor) else {
            throw NSError(domain: "AudioRing", code: 3)
        }
        self.field = field
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "audioRingParticle")
        descriptor.fragmentFunction = library.makeFunction(name: "audioRingDensity")
        descriptor.colorAttachments[0].pixelFormat = .r16Float
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .one
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .one
        particles = try device.makeRenderPipelineState(descriptor: descriptor)
        let final = MTLRenderPipelineDescriptor()
        final.vertexFunction = library.makeFunction(name: "audioRingQuad")
        final.fragmentFunction = library.makeFunction(name: "audioRingComposite")
        final.colorAttachments[0].pixelFormat = .bgra8Unorm
        composite = try device.makeRenderPipelineState(descriptor: final)
        blur = MPSImageGaussianBlur(device: device, sigma: 3.5)
        blur.edgeMode = .zero
    }

    func draw(drawable: CAMetalDrawable, dynamics: AudioRingDynamics, tint: SIMD4<Float>) {
        guard inFlight.wait(timeout: .now()) == .success else { return }
        guard let command = queue.makeCommandBuffer(),
              encode(command: command, target: drawable.texture, dynamics: dynamics, tint: tint) else {
            inFlight.signal()
            return
        }
        let semaphore = inFlight
        command.addCompletedHandler { _ in semaphore.signal() }
        command.present(drawable)
        command.commit()
    }

    @discardableResult
    func encode(command: MTLCommandBuffer, target: MTLTexture,
                dynamics: AudioRingDynamics, tint: SIMD4<Float>) -> Bool {
        if density?.width != target.width || density?.height != target.height {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r16Float,
                width: target.width, height: target.height, mipmapped: false)
            descriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
            descriptor.storageMode = .private
            density = device.makeTexture(descriptor: descriptor)
            bloom = device.makeTexture(descriptor: descriptor)
        }
        guard let density, let bloom else { return false }
        let grid = min(448, max(256, target.width / 2))
        var uniforms = Uniforms(
            motion: SIMD4(dynamics.evolution, dynamics.bass, dynamics.body, dynamics.treble),
            color: tint, viewport: SIMD4(Float(target.width), Float(target.height), Float(grid), dynamics.transient),
            energy: SIMD4(dynamics.intensity, 0, 0, 0))
        guard let fieldEncoder = command.makeComputeCommandEncoder() else { return false }
        fieldEncoder.setComputePipelineState(fieldPipeline)
        fieldEncoder.setTexture(field, index: 0)
        fieldEncoder.setBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        fieldEncoder.dispatchThreads(MTLSize(width: 128, height: 128, depth: 1),
            threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
        fieldEncoder.endEncoding()
        func pass(_ texture: MTLTexture) -> MTLRenderPassDescriptor {
            let pass = MTLRenderPassDescriptor()
            pass.colorAttachments[0].texture = texture
            pass.colorAttachments[0].loadAction = .clear
            pass.colorAttachments[0].storeAction = .store
            pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
            return pass
        }
        guard let points = command.makeRenderCommandEncoder(descriptor: pass(density)) else { return false }
        points.setRenderPipelineState(particles)
        points.setVertexTexture(field, index: 0)
        points.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        points.drawPrimitives(type: .point, vertexStart: 0, vertexCount: grid * grid)
        points.endEncoding()
        blur.encode(commandBuffer: command, sourceTexture: density, destinationTexture: bloom)
        guard let finish = command.makeRenderCommandEncoder(descriptor: pass(target)) else { return false }
        finish.setRenderPipelineState(composite)
        finish.setFragmentTexture(density, index: 0)
        finish.setFragmentTexture(bloom, index: 1)
        finish.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        finish.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        finish.endEncoding()
        return true
    }
}
