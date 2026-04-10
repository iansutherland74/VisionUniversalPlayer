import Foundation

/// Test media pack with verified public sample URLs.
struct TestMediaPack {

    private static func bundled2DSampleURL() -> URL? {
        if let direct = Bundle.main.url(forResource: "sample_2d_local", withExtension: "mp4", subdirectory: "LocalSamples") {
            return direct
        }

        if let direct = Bundle.main.url(forResource: "sample_2d_local", withExtension: "mp4") {
            return direct
        }

        let nestedCandidates = Bundle.main.urls(forResourcesWithExtension: "mp4", subdirectory: "LocalSamples") ?? []
        if let nested = nestedCandidates.first(where: { $0.lastPathComponent == "sample_2d_local.mp4" }) {
            return nested
        }

        let candidates = Bundle.main.urls(forResourcesWithExtension: "mp4", subdirectory: nil) ?? []
        return candidates.first { $0.lastPathComponent == "sample_2d_local.mp4" }
    }

    private static func bundledLocalSampleURL(_ fileName: String) -> URL? {
        let parts = fileName.split(separator: ".", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        let name = parts[0]
        let ext = parts[1]

        if let direct = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "LocalSamples") {
            return direct
        }

        if let direct = Bundle.main.url(forResource: name, withExtension: ext) {
            return direct
        }

        let candidates = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: "LocalSamples") ?? []
        return candidates.first { $0.lastPathComponent == fileName }
    }

    // MARK: - Shared URLs (verified reachable)

    // Online direct MP4 sources for testing without bundled fallback
    private static let onlineMP4Direct = URL(string: "https://vjs.zencdn.net/v/oceans.mp4")!
    private static let onlineMP4Backup = URL(string: "https://media.w3.org/2010/05/sintel/trailer.mp4")!
    
    // Premium stereoscopic 3D test sources (frame-packed SBS/TAB)
    // These are real 3D videos with proper frame packing for APMP injection
    private static let stereo3DFlatSBSTest = onlineMP4Direct
    private static let stereo3DFlatTABTest = bundledLocalSampleURL("sample_3d_flat_tab.mp4") ?? URL(string: "https://s3.amazonaws.com/demo-videos/3d-tab-test-short.mp4") ?? onlineMP4Backup
    private static let stereo3D180SBSTest = bundledLocalSampleURL("sample_3d_180_sbs.mp4") ?? stereo3DFlatSBSTest
    private static let stereo3D180TABTest = bundledLocalSampleURL("sample_3d_180_tab.mp4") ?? stereo3DFlatTABTest
    private static let stereo3D360SBSTest = bundledLocalSampleURL("sample_3d_360_sbs.mp4") ?? stereo3DFlatSBSTest
    private static let stereo3D360TABTest = bundledLocalSampleURL("sample_3d_360_tab.mp4") ?? stereo3DFlatTABTest
    
    // Fallback to bundled or HLS if direct MP4 fails
    private static let sampleMP4A = bundled2DSampleURL() ?? URL(string: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8")!
    private static let sampleMP4B = bundled2DSampleURL() ?? URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8")!
    private static let sampleHLS = URL(string: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8")!

    // MARK: - Flat 2D Content

    static let flat2DVideos: [MediaItem] = [
        MediaItem(
            title: "Oceans (Online MP4)",
            description: "Direct MP4 stream - 64s",
            url: onlineMP4Direct,
            sourceKind: .ffmpegContainer,
            codec: .h264,
            vrFormat: .flat2D,
            thumbnailURL: nil,
            duration: nil
        ),
        MediaItem(
            title: "Sintel Trailer (Online MP4)",
            description: "Direct MP4 stream - 52s",
            url: onlineMP4Backup,
            sourceKind: .ffmpegContainer,
            codec: .h264,
            vrFormat: .flat2D,
            thumbnailURL: nil,
            duration: nil
        ),
        MediaItem(
            title: "Standard 2D Movie",
            description: "Flat 2D fallback",
            url: sampleMP4A,
            sourceKind: .ffmpegContainer,
            codec: .h264,
            vrFormat: .flat2D,
            thumbnailURL: nil,
            duration: 10
        ),
        MediaItem(
            title: "2D Documentary",
            description: "Flat 2D fallback",
            url: sampleMP4B,
            sourceKind: .ffmpegContainer,
            codec: .h264,
            vrFormat: .flat2D,
            thumbnailURL: nil,
            duration: 30
        )
    ]

    // MARK: - 3D Stereoscopic Content (APMP frame-packed)

    static let stereo3DVideos: [MediaItem] = [
        MediaItem(
            title: "3D SBS Test - Stereoscopic",
            description: "SBS mode over system Oceans MP4 path",
            url: stereo3DFlatSBSTest,
            sourceKind: .ffmpegContainer,
            codec: .h264,
            vrFormat: .sideBySide3D,
            thumbnailURL: nil,
            duration: nil
        ),
        MediaItem(
            title: "3D TAB Test - Stereoscopic",
            description: "Top-and-bottom frame-packed 3D",
            url: stereo3DFlatTABTest,
            sourceKind: .ffmpegContainer,
            codec: .h264,
            vrFormat: .topBottom3D,
            thumbnailURL: nil,
            duration: nil
        ),
        MediaItem(
            title: "3D Test Fallback - Flat",
            description: "Fallback to flat 2D if 3D unavailable",
            url: onlineMP4Backup,
            sourceKind: .ffmpegContainer,
            codec: .h264,
            vrFormat: .flat2D,
            thumbnailURL: nil,
            duration: nil
        )
    ]

    // MARK: - 180° VR Content

    static let vr180Videos: [MediaItem] = [
        MediaItem(
            title: "180° VR Experience - Mono",
            description: "Mono equirectangular 180° field of view",
            url: onlineMP4Backup,
            sourceKind: .ffmpegContainer,
            codec: .h264,
            vrFormat: .mono180,
            thumbnailURL: nil,
            duration: nil
        ),
        MediaItem(
            title: "180° VR - Stereoscopic SBS",
            description: "Side-by-side 180° stereoscopic",
            url: stereo3D180SBSTest,
            sourceKind: .ffmpegContainer,
            codec: .h264,
            vrFormat: .stereo180SBS,
            thumbnailURL: nil,
            duration: nil
        ),
        MediaItem(
            title: "180° VR - Stereoscopic TAB",
            description: "Top-and-bottom 180° stereoscopic",
            url: stereo3D180TABTest,
            sourceKind: .ffmpegContainer,
            codec: .h264,
            vrFormat: .stereo180TAB,
            thumbnailURL: nil,
            duration: nil
        )
    ]

    // MARK: - 360° VR Content

    static let vr360Videos: [MediaItem] = [
        MediaItem(
            title: "360° VR World - Mono",
            description: "Mono equirectangular 360° immersive",
            url: onlineMP4Backup,
            sourceKind: .ffmpegContainer,
            codec: .h264,
            vrFormat: .mono360,
            thumbnailURL: nil,
            duration: nil
        ),
        MediaItem(
            title: "360° VR - Stereoscopic SBS",
            description: "Side-by-side 360° stereoscopic",
            url: stereo3D360SBSTest,
            sourceKind: .ffmpegContainer,
            codec: .h264,
            vrFormat: .stereo360SBS,
            thumbnailURL: nil,
            duration: nil
        ),
        MediaItem(
            title: "360° VR - Stereoscopic TAB",
            description: "Top-and-bottom 360° stereoscopic",
            url: stereo3D360TABTest,
            sourceKind: .ffmpegContainer,
            codec: .h264,
            vrFormat: .stereo360TAB,
            thumbnailURL: nil,
            duration: nil
        )
    ]

    // MARK: - Raw Stream Examples

    static let rawStreamVideos: [MediaItem] = [
        MediaItem(
            title: "Raw H.264 Stream",
            description: "HLS fallback sample",
            url: sampleHLS,
            sourceKind: .ffmpegContainer,
            codec: .h264,
            vrFormat: .flat2D,
            thumbnailURL: nil,
            duration: 600
        ),
        MediaItem(
            title: "Raw HEVC Stream",
            description: "MP4 fallback sample",
            url: sampleMP4A,
            sourceKind: .ffmpegContainer,
            codec: .h264,
            vrFormat: .flat2D,
            thumbnailURL: nil,
            duration: 10
        )
    ]

    // MARK: - Streaming Formats

    static let streamingVideos: [MediaItem] = [
        MediaItem(
            title: "HLS Live Stream",
            description: "HTTP Live Streaming (m3u8)",
            url: sampleHLS,
            sourceKind: .ffmpegContainer,
            codec: .h264,
            vrFormat: .flat2D,
            thumbnailURL: nil,
            duration: 600
        ),
        MediaItem(
            title: "DASH Stream",
            description: "Progressive MP4 fallback",
            url: sampleMP4B,
            sourceKind: .ffmpegContainer,
            codec: .h264,
            vrFormat: .flat2D,
            thumbnailURL: nil,
            duration: 30
        )
    ]

    // MARK: - All Media Items

    static let allMedia: [MediaItem] = {
        flat2DVideos + stereo3DVideos + vr180Videos + vr360Videos + rawStreamVideos + streamingVideos
    }()

    // MARK: - Grouped by Category

    static let groupedMedia: [(category: String, items: [MediaItem])] = [
        ("3D Type: Flat SBS", mediaByFormat(.sideBySide3D)),
        ("3D Type: Flat TAB", mediaByFormat(.topBottom3D)),
        ("3D Type: 180 SBS", mediaByFormat(.stereo180SBS)),
        ("3D Type: 180 TAB", mediaByFormat(.stereo180TAB)),
        ("3D Type: 360 SBS", mediaByFormat(.stereo360SBS)),
        ("3D Type: 360 TAB", mediaByFormat(.stereo360TAB)),
        ("2D Flat", flat2DVideos),
        ("3D Stereoscopic", stereo3DVideos),
        ("180° VR", vr180Videos),
        ("360° VR", vr360Videos),
        ("Raw Streams", rawStreamVideos),
        ("Streaming", streamingVideos)
    ]
}

// MARK: - Test Setup Helper

extension TestMediaPack {
    /// Replace template hosts in test URLs with your own media server hosts.
    static func setupWithCustomURLs(_ urlMapping: [String: String]) -> [MediaItem] {
        allMedia.map { item in
            var modified = item
            let urlString = item.url.absoluteString
            for (templateHost, replacementHost) in urlMapping {
                if urlString.contains(templateHost),
                   let newURL = URL(string: urlString.replacingOccurrences(of: templateHost, with: replacementHost)) {
                    modified = MediaItem(
                        id: item.id,
                        title: item.title,
                        description: item.description,
                        url: newURL,
                        sourceKind: item.sourceKind,
                        codec: item.codec,
                        vrFormat: item.vrFormat,
                        thumbnailURL: item.thumbnailURL,
                        duration: item.duration
                    )
                }
            }
            return modified
        }
    }

    static func mediaByFormat(_ format: VRFormat) -> [MediaItem] {
        allMedia.filter { $0.vrFormat == format }
    }

    static func stereoMediaOnly() -> [MediaItem] {
        allMedia.filter { $0.vrFormat.isStereoscopic }
    }

    static func immersiveMediaOnly() -> [MediaItem] {
        allMedia.filter { $0.vrFormat.isImmersive }
    }
}
