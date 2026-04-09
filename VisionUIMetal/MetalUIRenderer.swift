import Foundation
import MetalKit
import CoreImage

final class MetalUIRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let ciContext: CIContext
    private let pipeline: MetalUIPipeline

    private var vertexBuffer: MTLBuffer
    private var textureCache: CVMetalTextureCache?

    weak var visionRenderer: VisionUIRenderer?
    var overlayTextureProvider: (() -> MTLTexture?)?

    // Snapshot of @MainActor VisionUIRenderer state for use on the render thread.
    // Updated from main thread in MetalUIView.updateUIView via syncCache(from:).
    var cachedDirectTexture: (any MTLTexture)?
    var cachedPixelBuffer: CVPixelBuffer?

    init?(mtkView: MTKView, visionRenderer: VisionUIRenderer) {
        guard
            let device = mtkView.device ?? MTLCreateSystemDefaultDevice(),
            let queue = device.makeCommandQueue()
        else {
            return nil
        }

        self.device = device
        self.commandQueue = queue
        self.ciContext = CIContext(mtlDevice: device)
        self.visionRenderer = visionRenderer

        do {
            self.pipeline = try MetalUIPipeline(device: device, colorPixelFormat: mtkView.colorPixelFormat, depthPixelFormat: .depth32Float)
        } catch {
            return nil
        }

        let quad: [Float] = [
            -1, -1, 0, 1,
             1, -1, 1, 1,
            -1,  1, 0, 0,
             1,  1, 1, 0
        ]
        guard let vb = device.makeBuffer(bytes: quad, length: quad.count * MemoryLayout<Float>.stride) else {
            return nil
        }
        self.vertexBuffer = vb

        super.init()

        var cache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &cache)
        textureCache = cache

        mtkView.device = device
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.depthStencilPixelFormat = .depth32Float
        mtkView.framebufferOnly = false
        mtkView.clearColor = MTLClearColor(red: 0.02, green: 0.03, blue: 0.05, alpha: 1.0)
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }

    func draw(in view: MTKView) {
        guard
            let drawable = view.currentDrawable,
            let descriptor = view.currentRenderPassDescriptor,
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
        else {
            return
        }

        let sourceTexture = resolveSourceTextureFromCache(drawableSize: drawable.texture.size)
        let overlayTexture = overlayTextureProvider?()

        var uniforms = VisionUICompositeUniforms(
            time: Float(CACurrentMediaTime()),
            opacity: visionRenderer?.overlayOpacity ?? 1,
            cornerRadius: 0.08,
            layerMix: SIMD4<Float>(1, visionRenderer?.hudIntensity ?? 0.2, 0, 0),
            uvScale: SIMD2<Float>(1, 1),
            uvOffset: SIMD2<Float>(0, 0)
        )

        encoder.setRenderPipelineState(pipeline.compositePipeline)
        encoder.setDepthStencilState(pipeline.depthStencilState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<VisionUICompositeUniforms>.stride, index: 0)
        encoder.setFragmentTexture(sourceTexture, index: 0)
        encoder.setFragmentTexture(overlayTexture, index: 1)

        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    /// Called on the render thread; uses main-thread-cached values only.
    private func resolveSourceTextureFromCache(drawableSize: MTLSize) -> (any MTLTexture)? {
        if let direct = cachedDirectTexture { return direct }
        if let pixelBuffer = cachedPixelBuffer { return makeTexture(from: pixelBuffer) }
        return nil
    }

    /// Must be called on the main thread (from MetalUIView.updateUIView).
    @MainActor
    func syncCache(from renderer: VisionUIRenderer) {
        renderer.refreshFromPlayerState()
        cachedDirectTexture = renderer.directTexture
        cachedPixelBuffer = renderer.convertedBufferIfNeeded() ?? renderer.pixelBuffer
    }

    private func makeTexture(from pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        guard let textureCache else { return nil }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        var cvTexture: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            pixelBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &cvTexture
        )

        guard status == kCVReturnSuccess,
              let cvTexture,
              let texture = CVMetalTextureGetTexture(cvTexture)
        else {
            return nil
        }

        return texture
    }
}

private extension MTLTexture {
    var size: MTLSize {
        MTLSize(width: width, height: height, depth: 1)
    }
}
