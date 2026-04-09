import Foundation
import Metal
import simd

enum VisionUIRenderSurface: String, CaseIterable, Identifiable {
    case standard
    case visionMetal
    case immersive
    case converted2DTo3D

    var id: String { rawValue }
}

enum VisionUILayerMode: String, CaseIterable, Identifiable {
    case video
    case vr
    case depth3D

    var id: String { rawValue }
}

struct VisionUIViewport {
    var width: Int
    var height: Int
}

struct VisionUICompositeUniforms {
    var time: Float
    var opacity: Float
    var cornerRadius: Float
    var layerMix: SIMD4<Float>
    var uvScale: SIMD2<Float>
    var uvOffset: SIMD2<Float>
}

extension MTLSize {
    static func grid(for texture: MTLTexture, threadsPerGroup: MTLSize) -> MTLSize {
        MTLSize(
            width: (texture.width + threadsPerGroup.width - 1) / threadsPerGroup.width,
            height: (texture.height + threadsPerGroup.height - 1) / threadsPerGroup.height,
            depth: 1
        )
    }
}
