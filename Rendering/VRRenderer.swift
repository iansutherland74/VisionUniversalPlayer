import Foundation
import Metal
import CoreVideo
import simd

final class VRRenderer {
    enum RenderMode {
        case flatQuad
        case hemisphere180
        case sphere360
    }

    enum StereoscopicMode {
        case mono
        case sideBySide
        case topAndBottom
    }

    enum EyeSelection {
        case left
        case right
    }

    private struct Uniforms {
        var uvScale = SIMD2<Float>(1, 1)
        var uvOffset = SIMD2<Float>(0, 0)
        /// NutshellPlayer port: selects YUV→RGB matrix. See VideoColorMatrix raw values.
        var colorMatrixIndex: Int32 = VideoColorMatrix.bt709Limited.rawValue
    }

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState?
    private var textureCache: CVMetalTextureCache?

    private var quadMesh: QuadMesh?
    private var hemisphereMesh: SphereMesh?
    private var sphereMesh: SphereMesh?

    private(set) var renderMode: RenderMode = .flatQuad
    var stereoscopicMode: StereoscopicMode = .mono
    var eyeSelection: EyeSelection = .left
    var horizontalDisparityAdjustment: Float = 0.0
    /// NutshellPlayer port: auto-detected color space for correct YUV→RGB in the fragment shader.
    var colorSpaceInfo: VideoColorSpaceInfo = .default

    init?(device: MTLDevice) {
        self.device = device
        guard let queue = device.makeCommandQueue() else { return nil }
        commandQueue = queue

        var cache: CVMetalTextureCache?
        guard CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &cache) == kCVReturnSuccess else {
            return nil
        }
        textureCache = cache

        quadMesh = QuadMesh(device: device)
        hemisphereMesh = SphereMesh(device: device, segments: 96, rings: 48, radius: 1.0, isHemisphere: true)
        sphereMesh = SphereMesh(device: device, segments: 128, rings: 64, radius: 1.0, isHemisphere: false)

        buildPipeline()
    }

    func setRenderMode(_ mode: RenderMode) {
        renderMode = mode
        Task {
            await DebugCategory.vr.infoLog(
                "VR render mode changed",
                context: ["mode": String(describing: mode)]
            )
        }
    }

    func applyVisionUILayer(mode: VisionUILayerMode, surface: VisionUIRenderSurface) {
        switch mode {
        case .video:
            renderMode = .flatQuad
            stereoscopicMode = .mono
        case .vr:
            renderMode = surface == .immersive ? .sphere360 : .hemisphere180
        case .depth3D:
            renderMode = .flatQuad
            stereoscopicMode = .sideBySide
        }
    }

    func render(
        pixelBuffer: CVPixelBuffer,
        to drawable: MTLDrawable,
        in renderPassDescriptor: MTLRenderPassDescriptor
    ) {
        guard
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor),
            let pipeline = pipelineState,
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

        var uniforms = uniformsForCurrentStereoMode()

        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(yTexture, index: 0)
        encoder.setFragmentTexture(uvTexture, index: 1)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)

        switch renderMode {
        case .flatQuad:
            quadMesh?.render(with: encoder)
        case .hemisphere180:
            hemisphereMesh?.render(with: encoder)
        case .sphere360:
            sphereMesh?.render(with: encoder)
        }

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    func flushTextureCache() {
        if let textureCache {
            CVMetalTextureCacheFlush(textureCache, 0)
        }
    }

    private func uniformsForCurrentStereoMode() -> Uniforms {
        let matrixIndex = colorSpaceInfo.matrix.rawValue
        switch stereoscopicMode {
        case .mono:
            return Uniforms(uvScale: SIMD2<Float>(1, 1), uvOffset: SIMD2<Float>(0, 0), colorMatrixIndex: matrixIndex)
        case .sideBySide:
            let disparityOffset = max(-0.08, min(0.08, horizontalDisparityAdjustment * 0.04))
            let xOffset: Float = eyeSelection == .left ? disparityOffset : 0.5 - disparityOffset
            return Uniforms(uvScale: SIMD2<Float>(0.5, 1), uvOffset: SIMD2<Float>(xOffset, 0), colorMatrixIndex: matrixIndex)
        case .topAndBottom:
            let disparityOffset = max(-0.08, min(0.08, horizontalDisparityAdjustment * 0.04))
            let yOffset: Float = eyeSelection == .left ? 0.0 : 0.5
            return Uniforms(uvScale: SIMD2<Float>(1, 0.5), uvOffset: SIMD2<Float>(disparityOffset, yOffset), colorMatrixIndex: matrixIndex)
        }
    }

    private func buildPipeline() {
        let source = """
        #include <metal_stdlib>
        using namespace metal;

        struct VertexIn {
            float3 position [[attribute(0)]];
            float2 texCoord [[attribute(1)]];
            float3 normal [[attribute(2)]];
        };

        struct VertexOut {
            float4 position [[position]];
            float2 texCoord;
        };

        struct Uniforms {
            float2 uvScale;
            float2 uvOffset;
            int colorMatrixIndex; // 0=BT601Ltd 1=BT601Full 2=BT709Ltd 3=BT709Full
        };

        vertex VertexOut vertexMain(VertexIn in [[stage_in]]) {
            VertexOut out;
            out.position = float4(in.position, 1.0);
            out.texCoord = in.texCoord;
            return out;
        }

        // NutshellPlayer port: correct per-standard YUV→RGB matrices.
        // Coefficients from BT.601 and BT.709 specifications.
        float4 convertYUV(float y, float2 uv, int matrixIndex) {
            float U = uv.x - 0.5;
            float V = uv.y - 0.5;
            float r, g, b;
            if (matrixIndex == 0) {
                // BT.601 limited range
                float yy = (y - 16.0/255.0) * (255.0/219.0);
                r = yy + 1.5960 * V;
                g = yy - 0.3917 * U - 0.8129 * V;
                b = yy + 2.0172 * U;
            } else if (matrixIndex == 1) {
                // BT.601 full range
                r = y + 1.4020 * V;
                g = y - 0.3441 * U - 0.7141 * V;
                b = y + 1.7720 * U;
            } else if (matrixIndex == 3) {
                // BT.709 full range
                r = y + 1.5748 * V;
                g = y - 0.1873 * U - 0.4681 * V;
                b = y + 1.8556 * U;
            } else {
                // BT.709 limited range (default, most common)
                float yy = (y - 16.0/255.0) * (255.0/219.0);
                r = yy + 1.7927 * V;
                g = yy - 0.2132 * U - 0.5329 * V;
                b = yy + 2.1124 * U;
            }
            return float4(clamp(r,0.0,1.0), clamp(g,0.0,1.0), clamp(b,0.0,1.0), 1.0);
        }

        fragment float4 fragmentMain(
            VertexOut in [[stage_in]],
            texture2d<float> yTexture [[texture(0)]],
            texture2d<float> uvTexture [[texture(1)]],
            constant Uniforms &uniforms [[buffer(0)]]
        ) {
            constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);

            float2 uvCoord = in.texCoord * uniforms.uvScale + uniforms.uvOffset;
            float y = yTexture.sample(s, uvCoord).r;
            float2 uv = uvTexture.sample(s, uvCoord).rg;

            return convertYUV(y, uv, uniforms.colorMatrixIndex);
        }
        """

        do {
            let library = try device.makeLibrary(source: source, options: nil)
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: "vertexMain")
            descriptor.fragmentFunction = library.makeFunction(name: "fragmentMain")
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

            let vertexDescriptor = MTLVertexDescriptor()
            vertexDescriptor.attributes[0].format = .float3
            vertexDescriptor.attributes[0].offset = 0
            vertexDescriptor.attributes[0].bufferIndex = 0

            vertexDescriptor.attributes[1].format = .float2
            vertexDescriptor.attributes[1].offset = MemoryLayout<SIMD3<Float>>.stride
            vertexDescriptor.attributes[1].bufferIndex = 0

            vertexDescriptor.attributes[2].format = .float3
            vertexDescriptor.attributes[2].offset = MemoryLayout<SIMD3<Float>>.stride + MemoryLayout<SIMD2<Float>>.stride
            vertexDescriptor.attributes[2].bufferIndex = 0

            vertexDescriptor.layouts[0].stride = MemoryLayout<MeshVertex>.stride
            descriptor.vertexDescriptor = vertexDescriptor

            pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            Task {
                await DebugCategory.vr.errorLog(
                    "VRRenderer pipeline error",
                    context: ["error": error.localizedDescription]
                )
            }
        }
    }
}
