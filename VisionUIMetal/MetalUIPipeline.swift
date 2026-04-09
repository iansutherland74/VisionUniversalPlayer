import Foundation
import Metal

final class MetalUIPipeline {
    private(set) var compositePipeline: MTLRenderPipelineState
    private(set) var depthStencilState: MTLDepthStencilState

    init(device: MTLDevice, colorPixelFormat: MTLPixelFormat, depthPixelFormat: MTLPixelFormat = .depth32Float) throws {
        guard let library = device.makeDefaultLibrary() else {
            throw NSError(domain: "MetalUIPipeline", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing default metal library"]) 
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "VisionUICompositePipeline"
        descriptor.vertexFunction = library.makeFunction(name: "visionUIVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "visionUIFragment")
        descriptor.colorAttachments[0].pixelFormat = colorPixelFormat
        descriptor.depthAttachmentPixelFormat = depthPixelFormat
        descriptor.stencilAttachmentPixelFormat = .invalid
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].rgbBlendOperation = .add
        descriptor.colorAttachments[0].alphaBlendOperation = .add
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        compositePipeline = try device.makeRenderPipelineState(descriptor: descriptor)

        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .lessEqual
        depthDescriptor.isDepthWriteEnabled = false
        guard let depthState = device.makeDepthStencilState(descriptor: depthDescriptor) else {
            throw NSError(domain: "MetalUIPipeline", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create depth state"])
        }
        depthStencilState = depthState
    }
}
