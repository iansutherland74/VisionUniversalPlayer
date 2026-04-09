#if os(visionOS)
import AVFoundation
import CoreMedia
import CoreVideo

@available(visionOS 2.0, *)
final class APMPFrameInjector {
    enum InjectorError: Error {
        case invalidFramePacking
    }

    let renderer = AVSampleBufferVideoRenderer()

    private var cachedFormatDescription: CMFormatDescription?
    private var cachedDimensions: CMVideoDimensions?

    func enqueue(
        pixelBuffer: CVPixelBuffer,
        projection: VideoProjection,
        framePacking: FramePacking,
        presentationTime: CMTime,
        duration: CMTime = .invalid
    ) throws {
        guard framePacking != .none else {
            Task {
                await DebugCategory.immersive.errorLog("APMP enqueue rejected: invalid frame packing")
            }
            throw InjectorError.invalidFramePacking
        }

        let formatDescription = try getAPMPFormatDescription(
            for: pixelBuffer,
            projection: projection,
            framePacking: framePacking
        )

        let timing = CMSampleTimingInfo(
            duration: duration,
            presentationTimeStamp: presentationTime,
            decodeTimeStamp: .invalid
        )

        let sampleBuffer = try CMSampleBuffer(
            imageBuffer: pixelBuffer,
            formatDescription: formatDescription,
            sampleTiming: timing
        )

        if renderer.isReadyForMoreMediaData {
            renderer.enqueue(sampleBuffer)
        } else {
            Task {
                await DebugCategory.immersive.warningLog("APMP renderer not ready for more media data")
            }
        }
    }

    func flush() {
        renderer.flush()
    }

    private func getAPMPFormatDescription(
        for pixelBuffer: CVPixelBuffer,
        projection: VideoProjection,
        framePacking: FramePacking
    ) throws -> CMFormatDescription {
        let dimensions = CMVideoDimensions(
            width: Int32(CVPixelBufferGetWidth(pixelBuffer)),
            height: Int32(CVPixelBufferGetHeight(pixelBuffer))
        )

        if let cachedFormatDescription,
           let cachedDimensions,
           cachedDimensions.width == dimensions.width,
           cachedDimensions.height == dimensions.height {
            return cachedFormatDescription
        }

        let baseFormat = try CMVideoFormatDescription(imageBuffer: pixelBuffer)
        var extensions = baseFormat.extensions

        var baselineValue: Float?
        var disparityValue: Float?

        switch framePacking {
        case .none:
            baselineValue = nil
            disparityValue = nil
        case .sideBySide(let baseline, let horizontalDisparity):
            baselineValue = baseline
            disparityValue = horizontalDisparity
        case .overUnder(let baseline, let horizontalDisparity):
            baselineValue = baseline
            disparityValue = horizontalDisparity
        }

        if #available(visionOS 26.0, *) {
            let packingKind: CMFormatDescription.Extensions.Value.ViewPackingKind
            switch framePacking {
            case .none: packingKind = .sideBySide
            case .sideBySide: packingKind = .sideBySide
            case .overUnder: packingKind = .overUnder
            }
            extensions[.viewPackingKind] = .viewPackingKind(packingKind)
        }

        if let baselineValue {
            extensions[.stereoCameraBaseline] = .number(UInt32(max(0, baselineValue) * 1000))
        }

        if let disparityValue {
            let clamped = min(max(disparityValue, -1.0), 1.0)
            extensions[.horizontalDisparityAdjustment] = .number(Int32(clamped * 10000))
        }

        if #available(visionOS 26.0, *) {
            let projectionKind: CMFormatDescription.Extensions.Value.ProjectionKind
            let horizontalFov: Float

            switch projection {
            case .equirectangular(let fieldOfView, _):
                projectionKind = fieldOfView > 180 ? .equirectangular : .halfEquirectangular
                horizontalFov = max(0, min(360, fieldOfView))
            case .rectangular:
                projectionKind = .rectilinear
                horizontalFov = 65.0
            case .appleImmersive:
                projectionKind = .appleImmersiveVideo
                horizontalFov = 180.0
            }

            extensions[.projectionKind] = .projectionKind(projectionKind)
            extensions[.horizontalFieldOfView] = .number(UInt32(horizontalFov * 1000))
        }

        let formatDescription = try CMVideoFormatDescription(
            videoCodecType: baseFormat.mediaSubType,
            width: Int(baseFormat.dimensions.width),
            height: Int(baseFormat.dimensions.height),
            extensions: extensions
        )

        cachedDimensions = dimensions
        cachedFormatDescription = formatDescription
        Task {
            await DebugCategory.immersive.infoLog(
                "APMP format description updated",
                context: [
                    "width": String(dimensions.width),
                    "height": String(dimensions.height),
                    "projection": String(describing: projection),
                    "framePacking": String(describing: framePacking)
                ]
            )
        }
        return formatDescription
    }
}
#endif
