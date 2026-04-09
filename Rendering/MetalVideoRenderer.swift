import Foundation
import Metal
import CoreVideo

final class MetalVideoRenderer {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState?
    private var textureCache: CVMetalTextureCache?
    private var vertexBuffer: MTLBuffer?
    private var indexBuffer: MTLBuffer?

    private let vrRenderer: VRRenderer?
    private var currentVRFormat: VRFormat = .flat2D

    init?(device: MTLDevice) {
        self.device = device
        guard let queue = device.makeCommandQueue() else { return nil }
        commandQueue = queue
        vrRenderer = VRRenderer(device: device)

        buildFlatPipeline()
        buildFlatBuffers()

        var cache: CVMetalTextureCache?
        guard CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &cache) == kCVReturnSuccess else {
            return nil
        }
        textureCache = cache
    }

    func render(
        pixelBuffer: CVPixelBuffer,
        to drawable: MTLDrawable,
        in renderPassDescriptor: MTLRenderPassDescriptor,
        with vrFormat: VRFormat = .flat2D
    ) {
        currentVRFormat = vrFormat

        if vrFormat.isImmersive {
            vrRenderer?.render(pixelBuffer: pixelBuffer, to: drawable, in: renderPassDescriptor)
            return
        }

        guard
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor),
            let pipelineState,
            let textureCache
        else {
            return
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        var yTextureRef: CVMetalTexture?
        var uvTextureRef: CVMetalTexture?

        CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            pixelBuffer,
            nil,
            .r8Unorm,
            width,
            height,
            0,
            &yTextureRef
        )

        CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            pixelBuffer,
            nil,
            .rg8Unorm,
            width / 2,
            height / 2,
            1,
            &uvTextureRef
        )

        guard
            let yTextureRef,
            let uvTextureRef,
            let yTexture = CVMetalTextureGetTexture(yTextureRef),
            let uvTexture = CVMetalTextureGetTexture(uvTextureRef)
        else {
            encoder.endEncoding()
            commandBuffer.commit()
            return
        }

        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setFragmentTexture(yTexture, index: 0)
        encoder.setFragmentTexture(uvTexture, index: 1)

        if let indexBuffer {
            encoder.drawIndexedPrimitives(
                type: .triangle,
                indexCount: 6,
                indexType: .uint16,
                indexBuffer: indexBuffer,
                indexBufferOffset: 0
            )
        }

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    func configureForVRFormat(_ format: VRFormat) {
        currentVRFormat = format
        Task {
            await DebugCategory.renderer.infoLog(
                "Configured VR format",
                context: ["format": String(describing: format)]
            )
        }

        switch format {
        case .flat2D:
            vrRenderer?.setRenderMode(.flatQuad)
            vrRenderer?.stereoscopicMode = .mono

        case .sideBySide3D:
            vrRenderer?.setRenderMode(.flatQuad)
            vrRenderer?.stereoscopicMode = .sideBySide

        case .topBottom3D:
            vrRenderer?.setRenderMode(.flatQuad)
            vrRenderer?.stereoscopicMode = .topAndBottom

        case .mono180:
            vrRenderer?.setRenderMode(.hemisphere180)
            vrRenderer?.stereoscopicMode = .mono

        case .stereo180SBS:
            vrRenderer?.setRenderMode(.hemisphere180)
            vrRenderer?.stereoscopicMode = .sideBySide

        case .stereo180TAB:
            vrRenderer?.setRenderMode(.hemisphere180)
            vrRenderer?.stereoscopicMode = .topAndBottom

        case .mono360:
            vrRenderer?.setRenderMode(.sphere360)
            vrRenderer?.stereoscopicMode = .mono

        case .stereo360SBS:
            vrRenderer?.setRenderMode(.sphere360)
            vrRenderer?.stereoscopicMode = .sideBySide

        case .stereo360TAB:
            vrRenderer?.setRenderMode(.sphere360)
            vrRenderer?.stereoscopicMode = .topAndBottom
        }
    }

    func flushTextureCache() {
        if let textureCache {
            CVMetalTextureCacheFlush(textureCache, 0)
        }
        vrRenderer?.flushTextureCache()
    }

    private func buildFlatBuffers() {
        let vertices: [Float] = [
            -1, -1, 0, 1,
             1, -1, 1, 1,
             1,  1, 1, 0,
            -1,  1, 0, 0
        ]

        vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Float>.stride)

        let indices: [UInt16] = [0, 1, 2, 0, 2, 3]
        indexBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt16>.stride)
    }

    private func buildFlatPipeline() {
        let source = """
        #include <metal_stdlib>
        using namespace metal;

        struct VertexIn {
            float2 position [[attribute(0)]];
            float2 texCoord [[attribute(1)]];
        };

        struct VertexOut {
            float4 position [[position]];
            float2 texCoord;
        };

        vertex VertexOut vertexMain(VertexIn in [[stage_in]]) {
            VertexOut out;
            out.position = float4(in.position, 0.0, 1.0);
            out.texCoord = in.texCoord;
            return out;
        }

        fragment float4 fragmentMain(
            VertexOut in [[stage_in]],
            texture2d<float> yTexture [[texture(0)]],
            texture2d<float> uvTexture [[texture(1)]]
        ) {
            constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);
            float y = yTexture.sample(s, in.texCoord).r;
            float2 uv = uvTexture.sample(s, in.texCoord).rg;
            float U = uv.x - 0.5;
            float V = uv.y - 0.5;
            float r = y + 1.4020 * V;
            float g = y - 0.3441 * U - 0.7141 * V;
            float b = y + 1.7720 * U;
            return float4(r, g, b, 1.0);
        }
        """

        do {
            let library = try device.makeLibrary(source: source, options: nil)
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: "vertexMain")
            descriptor.fragmentFunction = library.makeFunction(name: "fragmentMain")
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            Task {
                await DebugCategory.metal.errorLog(
                    "MetalVideoRenderer pipeline error",
                    context: ["error": error.localizedDescription]
                )
            }
        }
    }
}
