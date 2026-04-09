import Foundation
import Metal
import CoreImage
import CoreVideo

final class Depth3DConverter {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let ciContext: CIContext

    private var depthPipeline: MTLComputePipelineState?
    private var stereoSBSPipeline: MTLComputePipelineState?
    private var stereoTABPipeline: MTLComputePipelineState?

    var depthStrength: Float = 1.0
    var convergence: Float = 1.0
    var maxDisparityPixels: Float = 6.5
    var stabilityAmount: Float = 0.35
    var colorBoost: Float = 1.4

    init?(device: MTLDevice) {
        self.device = device
        guard let queue = device.makeCommandQueue() else { return nil }
        self.commandQueue = queue
        self.ciContext = CIContext(mtlDevice: device)
        do {
            try buildPipelines()
            Task {
                await DebugCategory.depth3D.infoLog("Depth3DConverter pipelines initialized")
            }
        } catch {
            Task {
                await DebugCategory.depth3D.errorLog(
                    "Depth3DConverter pipeline error",
                    context: ["error": error.localizedDescription]
                )
            }
            return nil
        }
    }

    func convert2DToStereo3DSBS(
        pixelBuffer: CVPixelBuffer,
        convergence: Float,
        depthStrength: Float
    ) -> CVPixelBuffer? {
        self.convergence = convergence
        self.depthStrength = depthStrength
        return convert(pixelBuffer: pixelBuffer, outputMode: .sideBySide3D)
    }

    func convert2DToStereo3DTAB(
        pixelBuffer: CVPixelBuffer,
        convergence: Float,
        depthStrength: Float
    ) -> CVPixelBuffer? {
        self.convergence = convergence
        self.depthStrength = depthStrength
        return convert(pixelBuffer: pixelBuffer, outputMode: .topBottom3D)
    }

    func convertForVisionUI(
        pixelBuffer: CVPixelBuffer,
        surface: VisionUIRenderSurface,
        convergence: Float,
        depthStrength: Float
    ) -> CVPixelBuffer? {
        switch surface {
        case .converted2DTo3D:
            return convert2DToStereo3DSBS(pixelBuffer: pixelBuffer, convergence: convergence, depthStrength: depthStrength)
        default:
            return pixelBuffer
        }
    }

    private func convert(pixelBuffer: CVPixelBuffer, outputMode: VRFormat) -> CVPixelBuffer? {
        Task {
            await DebugCategory.depth3D.traceLog(
                "Starting 2D to 3D conversion",
                context: ["mode": String(describing: outputMode)]
            )
        }
        guard
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let sourceTexture = makeSourceTexture(from: pixelBuffer)
        else {
            Task {
                await DebugCategory.depth3D.errorLog("Failed to create command buffer or source texture")
            }
            return nil
        }

        let width = sourceTexture.width
        let height = sourceTexture.height
        let outputWidth = outputMode == .sideBySide3D ? width * 2 : width
        let outputHeight = outputMode == .topBottom3D ? height * 2 : height

        guard
            let depthTexture = makeTexture(pixelFormat: .r16Float, width: width, height: height),
            let outputTexture = makeTexture(pixelFormat: .bgra8Unorm, width: outputWidth, height: outputHeight)
        else {
            return nil
        }

        runDepthPass(source: sourceTexture, destination: depthTexture, commandBuffer: commandBuffer)

        if outputMode == .sideBySide3D {
            runStereoPass(
                pipeline: stereoSBSPipeline,
                source: sourceTexture,
                depth: depthTexture,
                output: outputTexture,
                commandBuffer: commandBuffer
            )
        } else {
            runStereoPass(
                pipeline: stereoTABPipeline,
                source: sourceTexture,
                depth: depthTexture,
                output: outputTexture,
                commandBuffer: commandBuffer
            )
        }

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        Task {
            await DebugCategory.depth3D.traceLog(
                "Completed 2D to 3D conversion",
                context: [
                    "outputWidth": String(outputWidth),
                    "outputHeight": String(outputHeight)
                ]
            )
        }
        return makePixelBuffer(from: outputTexture)
    }

    private func buildPipelines() throws {
        guard let library = device.makeDefaultLibrary() else {
            throw NSError(domain: "Depth3DConverter", code: 10, userInfo: [NSLocalizedDescriptionKey: "Default Metal library unavailable"])
        }

        depthPipeline = try device.makeComputePipelineState(function: library.makeFunction(name: "depthMapKernel")!)
        stereoSBSPipeline = try device.makeComputePipelineState(function: library.makeFunction(name: "stereoSBSKernel")!)
        stereoTABPipeline = try device.makeComputePipelineState(function: library.makeFunction(name: "stereoTABKernel")!)
    }

    private func makeTexture(pixelFormat: MTLPixelFormat, width: Int, height: Int) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        return device.makeTexture(descriptor: descriptor)
    }

    private func makeSourceTexture(from pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        guard let texture = makeTexture(pixelFormat: .bgra8Unorm, width: width, height: height) else {
            return nil
        }

        let image = CIImage(cvPixelBuffer: pixelBuffer)
        ciContext.render(image, to: texture, commandBuffer: nil, bounds: image.extent, colorSpace: CGColorSpaceCreateDeviceRGB())
        return texture
    }

    private func runDepthPass(source: MTLTexture, destination: MTLTexture, commandBuffer: MTLCommandBuffer) {
        guard let pipeline = depthPipeline, let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
        var strength = depthStrength
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(source, index: 0)
        encoder.setTexture(destination, index: 1)
        encoder.setBytes(&strength, length: MemoryLayout<Float>.stride, index: 0)
        dispatch(encoder: encoder, pipeline: pipeline, width: destination.width, height: destination.height)
        encoder.endEncoding()
    }

    private func runStereoPass(
        pipeline: MTLComputePipelineState?,
        source: MTLTexture,
        depth: MTLTexture,
        output: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) {
        guard let pipeline, let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
        var maxDisparity = maxDisparityPixels
        var convergence = convergence
        var colorBoost = colorBoost
        var stabilityAmount = stabilityAmount
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(source, index: 0)
        encoder.setTexture(depth, index: 1)
        encoder.setTexture(output, index: 2)
        encoder.setBytes(&maxDisparity, length: MemoryLayout<Float>.stride, index: 0)
        encoder.setBytes(&convergence, length: MemoryLayout<Float>.stride, index: 1)
        encoder.setBytes(&colorBoost, length: MemoryLayout<Float>.stride, index: 2)
        encoder.setBytes(&stabilityAmount, length: MemoryLayout<Float>.stride, index: 3)
        dispatch(encoder: encoder, pipeline: pipeline, width: output.width, height: output.height)
        encoder.endEncoding()
    }

    private func dispatch(encoder: MTLComputeCommandEncoder, pipeline: MTLComputePipelineState, width: Int, height: Int) {
        let threadsPerThreadgroup = MTLSize(width: 8, height: 8, depth: 1)
        let threadgroups = MTLSize(
            width: (width + threadsPerThreadgroup.width - 1) / threadsPerThreadgroup.width,
            height: (height + threadsPerThreadgroup.height - 1) / threadsPerThreadgroup.height,
            depth: 1
        )
        encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
    }

    private func makePixelBuffer(from texture: MTLTexture) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            texture.width,
            texture.height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let region = MTLRegionMake2D(0, 0, texture.width, texture.height)
        texture.getBytes(baseAddress, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        return pixelBuffer
    }
}
