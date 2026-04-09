import AVFoundation
import CoreMedia
import Foundation

// Ported from mikeswanson/SpatialPlayer — automatic MV-HEVC spatial metadata extraction.
// Reads "ProjectionKind" and kCMFormatDescriptionExtension_HorizontalFieldOfView directly
// from CMFormatDescription extensions without any user input.

struct SpatialProbeResult {
    enum ProjectionKind: Equatable {
        case equirectangular(fieldOfView: Float)
        case halfEquirectangular(fieldOfView: Float)
        case rectangular
        case unknown(raw: String?)
    }

    let isMVHEVC: Bool
    let projection: ProjectionKind
    let naturalSize: CGSize

    // MARK: - Mapped project types

    var suggestedVideoProjection: VideoProjection {
        switch projection {
        case .equirectangular(let fov), .halfEquirectangular(let fov):
            return .equirectangular(fieldOfView: fov)
        case .rectangular, .unknown:
            return .rectangular
        }
    }

    var suggestedFramePacking: FramePacking {
        isMVHEVC ? .sideBySide() : .none
    }

    var suggestedVRFormat: VRFormat {
        switch projection {
        case .equirectangular(let fov), .halfEquirectangular(let fov):
            let is360 = fov >= 340
            if isMVHEVC {
                return is360 ? .stereo360SBS : .stereo180SBS
            } else {
                return is360 ? .mono360 : .mono180
            }
        case .rectangular:
            return isMVHEVC ? .sideBySide3D : .flat2D
        case .unknown:
            return .flat2D
        }
    }

    // MARK: - Display

    var projectionDisplay: String {
        switch projection {
        case .equirectangular(let fov):
            return String(format: "Equirect %.0f°", fov)
        case .halfEquirectangular(let fov):
            return String(format: "HalfEquirect %.0f°", fov)
        case .rectangular:
            return "Rectangular"
        case .unknown(let raw):
            return raw != nil ? "Unknown (\(raw!))" : "Unknown"
        }
    }

    var stereoDisplay: String {
        isMVHEVC ? "MV-HEVC stereo" : "Mono"
    }

    var summaryDisplay: String {
        "\(projectionDisplay) · \(stereoDisplay)"
    }
}

// MARK: - Probe

struct SpatialVideoProbe {

    /// Asynchronously reads the first video track's CMFormatDescription to extract spatial metadata.
    /// Returns nil if the asset has no video track or the format cannot be loaded.
    static func probe(url: URL) async -> SpatialProbeResult? {
        await DebugCategory.decoder.traceLog("Spatial probe started", context: ["url": url.absoluteString])
        let asset = AVURLAsset(url: url)

        guard let videoTrack = try? await asset.loadTracks(withMediaType: .video).first else {
            await DebugCategory.decoder.warningLog("Spatial probe found no video track")
            return nil
        }

        guard
            let (naturalSize, formatDescriptions, mediaCharacteristics) =
                try? await videoTrack.load(.naturalSize, .formatDescriptions, .mediaCharacteristics),
            let formatDesc = formatDescriptions.first
        else {
            await DebugCategory.decoder.warningLog("Spatial probe failed to load track metadata")
            return nil
        }

        let isMVHEVC: Bool
        if #available(iOS 17, macOS 14, visionOS 1.0, *) {
            isMVHEVC = mediaCharacteristics.contains(.containsStereoMultiviewVideo)
        } else {
            isMVHEVC = false
        }

        let (rawKind, fov) = extractProjectionExtensions(from: formatDesc)

        let projection: SpatialProbeResult.ProjectionKind
        switch rawKind?.uppercased() {
        case "EQUI":
            projection = .equirectangular(fieldOfView: fov ?? 360.0)
        case "HEQU":
            projection = .halfEquirectangular(fieldOfView: fov ?? 180.0)
        case "RECT":
            projection = .rectangular
        default:
            if rawKind != nil {
                projection = .unknown(raw: rawKind)
            } else if fov != nil {
                // Has FOV hint but no kind — assume equirect
                projection = .equirectangular(fieldOfView: fov!)
            } else {
                projection = .rectangular
            }
        }

        let result = SpatialProbeResult(
            isMVHEVC: isMVHEVC,
            projection: projection,
            naturalSize: naturalSize
        )
        await DebugCategory.decoder.infoLog(
            "Spatial probe completed",
            context: [
                "isMVHEVC": result.isMVHEVC ? "true" : "false",
                "projection": result.projectionDisplay,
                "width": String(format: "%.0f", result.naturalSize.width),
                "height": String(format: "%.0f", result.naturalSize.height)
            ]
        )
        return result
    }

    // MARK: - Private helpers

    private static func extractProjectionExtensions(
        from formatDescription: CMFormatDescription
    ) -> (kind: String?, fov: Float?) {
        guard let extensions = CMFormatDescriptionGetExtensions(formatDescription) as Dictionary? else {
            return (nil, nil)
        }

        // "ProjectionKind" is undocumented but present in MV-HEVC / 360 video files.
        let rawKind = extensions["ProjectionKind" as CFString] as? String

        let fov: Float?
        if let milliDegrees = extensions[kCMFormatDescriptionExtension_HorizontalFieldOfView] as? UInt32 {
            fov = Float(milliDegrees) / 1000.0
        } else {
            fov = nil
        }

        return (rawKind, fov)
    }
}
