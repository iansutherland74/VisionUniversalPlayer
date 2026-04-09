import Foundation
import CoreMedia

class FFmpegDemuxer {
    private var handle: Int32 = -1
    private let url: URL
    private(set) var codec: CodecType
    private var isClosed = false
    
    init(url: URL, codec: CodecType) throws {
        self.url = url
        self.codec = codec
        Task {
            await DebugCategory.demuxer.infoLog(
                "Opening FFmpeg demuxer",
                context: ["url": url.absoluteString, "codec": codec.rawValue]
            )
        }
        
        let urlString = url.absoluteString.cString(using: .utf8)!
        handle = ffmpeg_open(urlString)
        
        if handle < 0 {
            Task {
                await DebugCategory.demuxer.errorLog(
                    "FFmpeg demuxer open failed",
                    context: ["code": String(handle), "url": url.absoluteString]
                )
            }
            throw FFmpegDemuxError.openFailed(code: Int(handle))
        }
    }
    
    deinit {
        if !isClosed && handle >= 0 {
            ffmpeg_close(handle)
        }
    }
    
    func nextPacket() async throws -> (Data, CMTime)? {
        if isClosed || handle < 0 {
            return nil
        }
        
        var data: UnsafeMutablePointer<UInt8>? = nil
        var size: Int32 = 0
        var ptsSeconds: Double = 0.0
        
        let result = ffmpeg_read_annexb_packet(handle, &data, &size, &ptsSeconds)
        
        if result < 0 {
            if result == -4 {
                close()
                return nil
            }
            Task {
                await DebugCategory.demuxer.errorLog(
                    "FFmpeg demuxer read failed",
                    context: ["code": String(result)]
                )
            }
            throw FFmpegDemuxError.readFailed(code: Int(result))
        }
        
        guard let data = data, size > 0 else {
            return nil
        }
        
        defer {
            ffmpeg_free_packet(data)
        }
        
        let nalData = Data(bytes: data, count: Int(size))
        let pts = CMTime(seconds: ptsSeconds, preferredTimescale: 1000)
        
        return (nalData, pts)
    }

    func seek(to seconds: TimeInterval) throws {
        if isClosed || handle < 0 {
            throw FFmpegDemuxError.invalidHandle
        }

        let clamped = max(0, seconds)
        let result = ffmpeg_seek_seconds(handle, clamped)
        if result < 0 {
            Task {
                await DebugCategory.demuxer.errorLog(
                    "FFmpeg demuxer seek failed",
                    context: ["code": String(result), "seconds": String(format: "%.3f", clamped)]
                )
            }
            throw FFmpegDemuxError.seekFailed(code: Int(result))
        }
        Task {
            await DebugCategory.demuxer.infoLog(
                "FFmpeg demuxer seek completed",
                context: ["seconds": String(format: "%.3f", clamped)]
            )
        }
    }
    
    func close() {
        if !isClosed && handle >= 0 {
            ffmpeg_close(handle)
            isClosed = true
            Task {
                await DebugCategory.demuxer.infoLog("FFmpeg demuxer closed")
            }
        }
    }
}

enum FFmpegDemuxError: LocalizedError {
    case openFailed(code: Int)
    case readFailed(code: Int)
    case seekFailed(code: Int)
    case invalidHandle
    
    var errorDescription: String? {
        switch self {
        case .openFailed(let code):
            return "Failed to open FFmpeg demuxer (code: \(code))"
        case .readFailed(let code):
            return "Failed to read FFmpeg packet (code: \(code))"
        case .seekFailed(let code):
            return "Failed to seek FFmpeg demuxer (code: \(code))"
        case .invalidHandle:
            return "FFmpeg demuxer handle is invalid"
        }
    }
}
