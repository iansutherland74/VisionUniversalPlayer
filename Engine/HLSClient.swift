import Foundation
import Combine

class HLSClient {
    private let urlSession: URLSession
    private let baseURL: URL
    
    init(url: URL) {
        self.baseURL = url
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.timeoutIntervalForResource = 60
        self.urlSession = URLSession(configuration: config)
        Task {
            await DebugCategory.hls.infoLog(
                "Initialized HLS client",
                context: ["baseURL": url.absoluteString]
            )
        }
    }
    
    func fetchPlaylist() async throws -> HLSPlaylist {
        await DebugCategory.hls.traceLog("Fetching HLS playlist", context: ["url": baseURL.absoluteString])
        let data = try await urlSession.data(from: baseURL).0
        guard let content = String(data: data, encoding: .utf8) else {
            await DebugCategory.hls.errorLog("Playlist decode failed", context: ["url": baseURL.absoluteString])
            throw HLSClientError.invalidPlaylist
        }
        let playlist = parsePlaylist(content)
        await DebugCategory.hls.infoLog(
            "Parsed HLS playlist",
            context: [
                "segments": String(playlist.segments.count),
                "targetDuration": String(format: "%.2f", playlist.targetDuration),
                "mediaSequence": String(playlist.mediaSequence),
                "finished": playlist.isFinished ? "true" : "false"
            ]
        )
        return playlist
    }
    
    func fetchSegment(url: URL) async throws -> Data {
        await DebugCategory.hls.traceLog("Fetching HLS segment", context: ["url": url.absoluteString])
        do {
            let data = try await urlSession.data(from: url).0
            await DebugCategory.hls.traceLog(
                "Fetched HLS segment",
                context: ["bytes": String(data.count)]
            )
            return data
        } catch {
            await DebugCategory.hls.errorLog(
                "Failed to fetch HLS segment",
                context: ["url": url.absoluteString, "error": error.localizedDescription]
            )
            throw error
        }
    }
    
    private func parsePlaylist(_ content: String) -> HLSPlaylist {
        var segments: [HLSSegment] = []
        var duration: TimeInterval = 0
        var targetDuration: TimeInterval = 0
        var mediaSequence: Int = 0
        var finished = false
        
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.hasPrefix("#EXT-X-TARGETDURATION:") {
                let durationStr = trimmed.replacingOccurrences(of: "#EXT-X-TARGETDURATION:", with: "")
                targetDuration = TimeInterval(Double(durationStr) ?? 10)
            } else if trimmed.hasPrefix("#EXT-X-MEDIA-SEQUENCE:") {
                let seqStr = trimmed.replacingOccurrences(of: "#EXT-X-MEDIA-SEQUENCE:", with: "")
                mediaSequence = Int(seqStr) ?? 0
            } else if trimmed.hasPrefix("#EXTINF:") {
                let durationStr = trimmed.replacingOccurrences(of: "#EXTINF:", with: "").split(separator: ",")[0]
                duration = TimeInterval(Double(durationStr) ?? targetDuration)
            } else if trimmed.hasPrefix("#EXT-X-ENDLIST") {
                finished = true
            } else if !trimmed.isEmpty && !trimmed.hasPrefix("#") {
                let segmentURL: URL
                if trimmed.hasPrefix("http") {
                    segmentURL = URL(string: trimmed) ?? baseURL
                } else {
                    segmentURL = baseURL.deletingLastPathComponent().appendingPathComponent(trimmed)
                }
                segments.append(HLSSegment(url: segmentURL, duration: duration))
            }
        }
        
        return HLSPlaylist(
            segments: segments,
            targetDuration: targetDuration,
            mediaSequence: mediaSequence,
            isFinished: finished
        )
    }
}

struct HLSPlaylist {
    let segments: [HLSSegment]
    let targetDuration: TimeInterval
    let mediaSequence: Int
    let isFinished: Bool
}

struct HLSSegment {
    let url: URL
    let duration: TimeInterval
}

enum HLSClientError: LocalizedError {
    case invalidPlaylist
    case downloadFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidPlaylist:
            return "Invalid HLS playlist"
        case .downloadFailed(let error):
            return "Download failed: \(error.localizedDescription)"
        }
    }
}
