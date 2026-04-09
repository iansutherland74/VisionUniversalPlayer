import Foundation

struct HLSVariantPlaylistBuilder {
    static func makeMasterPlaylist(
        selectedBitrate: HLSBitrateRung?,
        selectedAudio: HLSAudioOption?
    ) -> String {
        var lines: [String] = []
        lines.append("#EXTM3U")
        lines.append("#EXT-X-VERSION:6")

        if let selectedAudio {
            let escapedName = selectedAudio.name.replacingOccurrences(of: "\"", with: "")
            let escapedLanguage = selectedAudio.language.replacingOccurrences(of: "\"", with: "")
            lines.append(
                "#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID=\"\(selectedAudio.groupId)\",NAME=\"\(escapedName.isEmpty ? selectedAudio.groupId : escapedName)\",LANGUAGE=\"\(escapedLanguage)\",DEFAULT=YES,AUTOSELECT=YES,URI=\"\(selectedAudio.url.absoluteString)\""
            )
        }

        let bandwidth = max(selectedBitrate?.peakBitrate ?? 0, selectedBitrate?.averageBitrate ?? 0)
        let averageBandwidth = selectedBitrate?.averageBitrate ?? bandwidth
        let width = Int(selectedBitrate?.size.width ?? 1920)
        let height = Int(selectedBitrate?.size.height ?? 1080)
        let codecs = "avc1.640028,mp4a.40.2"

        var streamInfo = "#EXT-X-STREAM-INF:BANDWIDTH=\(max(1, bandwidth)),AVERAGE-BANDWIDTH=\(max(1, averageBandwidth)),RESOLUTION=\(max(1, width))x\(max(1, height)),CODECS=\"\(codecs)\""

        if let selectedAudio {
            streamInfo += ",AUDIO=\"\(selectedAudio.groupId)\""
        }

        lines.append(streamInfo)
        lines.append(selectedBitrate?.url.absoluteString ?? "")
        Task {
            await DebugCategory.hls.infoLog(
                "Built HLS variant playlist",
                context: [
                    "hasBitrate": selectedBitrate == nil ? "false" : "true",
                    "hasAudio": selectedAudio == nil ? "false" : "true",
                    "bandwidth": String(max(1, bandwidth))
                ]
            )
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func writeTemporaryPlaylist(_ content: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("VisionUniversalPlayer-HLS", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let fileURL = tempDir.appendingPathComponent("variant-\(UUID().uuidString).m3u8")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        Task {
            await DebugCategory.hls.infoLog(
                "Wrote temporary HLS playlist",
                context: ["file": fileURL.path, "bytes": String(content.utf8.count)]
            )
        }
        return fileURL
    }
}
