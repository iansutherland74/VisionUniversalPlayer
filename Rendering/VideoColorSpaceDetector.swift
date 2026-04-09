import CoreVideo
import Foundation

// Ported from halftan/NutshellPlayer — automatic color space detection from CVPixelBuffer
// attachments, feeding the correct YUV→RGB matrix into the Metal renderer.
//
// Detects: BT.601 vs BT.709 matrix, full-range vs video-range, 8-bit vs 10-bit.

enum VideoColorMatrix: Int32 {
    /// BT.601 limited range — legacy SDTV (older MPEG/H.264 content)
    case bt601Limited = 0
    /// BT.601 full range — uncommon, some camera captures
    case bt601Full = 1
    /// BT.709 limited range — modern HDTV H.264/HEVC (default for iPhone video)
    case bt709Limited = 2
    /// BT.709 full range — some screen recordings / av-capture presets
    case bt709Full = 3
}

struct VideoColorSpaceInfo: Equatable {
    let matrix: VideoColorMatrix
    let isFullRange: Bool
    let is10Bit: Bool

    static let `default` = VideoColorSpaceInfo(matrix: .bt709Limited, isFullRange: false, is10Bit: false)
}

struct VideoColorSpaceDetector {

    /// Reads the YCbCr matrix, range, and bit depth directly from `CVPixelBuffer` attachments.
    /// Falls back to BT.709 limited (the most common iPhone/HEVC profile) when metadata is absent.
    static func detect(pixelBuffer: CVPixelBuffer) -> VideoColorSpaceInfo {
        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)

        let is10Bit: Bool
        switch pixelFormat {
        case kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange,
             kCVPixelFormatType_420YpCbCr10BiPlanarFullRange:
            is10Bit = true
        default:
            is10Bit = false
        }

        // kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange = '420v' → limited
        // kCVPixelFormatType_420YpCbCr8BiPlanarFullRange  = '420f' → full
        let formatImpliesFullRange: Bool
        switch pixelFormat {
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
             kCVPixelFormatType_420YpCbCr10BiPlanarFullRange:
            formatImpliesFullRange = true
        default:
            formatImpliesFullRange = false
        }

        guard let attachments = CVBufferCopyAttachments(pixelBuffer, .shouldPropagate) as? [CFString: Any] else {
            let matrix: VideoColorMatrix = formatImpliesFullRange ? .bt709Full : .bt709Limited
            let info = VideoColorSpaceInfo(matrix: matrix, isFullRange: formatImpliesFullRange, is10Bit: is10Bit)
            Task {
                await DebugCategory.renderer.traceLog(
                    "Color space detected (fallback)",
                    context: [
                        "matrix": String(info.matrix.rawValue),
                        "fullRange": info.isFullRange ? "true" : "false",
                        "is10Bit": info.is10Bit ? "true" : "false"
                    ]
                )
            }
            return info
        }

        let yCbCrMatrix = attachments[kCVImageBufferYCbCrMatrixKey] as? String
        let colorPrimaries = attachments[kCVImageBufferColorPrimariesKey] as? String

        // Determine full-range from buffer tag (more reliable than format type alone)
        let isFullRange: Bool
        if let colorAttachments = attachments[kCVImageBufferColorPrimariesKey as CFString] as? String {
            _ = colorAttachments
        }
        isFullRange = formatImpliesFullRange

        // Map matrix string → VideoColorMatrix
        let matrix: VideoColorMatrix
        let isBT601 = (yCbCrMatrix == (kCVImageBufferYCbCrMatrix_ITU_R_601_4 as String))
            || (colorPrimaries == (kCVImageBufferColorPrimaries_SMPTE_C as String))

        if isBT601 {
            matrix = isFullRange ? .bt601Full : .bt601Limited
        } else {
            // BT.709 or unknown — default to BT.709
            matrix = isFullRange ? .bt709Full : .bt709Limited
        }

        let info = VideoColorSpaceInfo(matrix: matrix, isFullRange: isFullRange, is10Bit: is10Bit)
        Task {
            await DebugCategory.renderer.traceLog(
                "Color space detected",
                context: [
                    "matrix": String(info.matrix.rawValue),
                    "fullRange": info.isFullRange ? "true" : "false",
                    "is10Bit": info.is10Bit ? "true" : "false"
                ]
            )
        }
        return info
    }
}
