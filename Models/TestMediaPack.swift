import Foundation

/// Test media pack with comprehensive VR and 3D format examples
struct TestMediaPack {
    
    // MARK: - Flat 2D Content
    
    static let flat2DVideos: [MediaItem] = [
        MediaItem(
            title: "Standard 2D Movie",
            description: "Classic flat 2D video - MP4 H.264",
            url: URL(string: "https://example.com/media/flat_2d_hd.mp4")!,
            sourceKind: .ffmpegContainer,
            codec: .h264,
            vrFormat: .flat2D,
            thumbnailURL: URL(string: "https://example.com/thumbs/flat_2d.jpg"),
            duration: 7200
        ),
        MediaItem(
            title: "2D Documentary",
            description: "Educational content - HEVC format",
            url: URL(string: "https://example.com/media/doc_2d_hevc.mkv")!,
            sourceKind: .ffmpegContainer,
            codec: .hevc,
            vrFormat: .flat2D,
            thumbnailURL: URL(string: "https://example.com/thumbs/doc_2d.jpg"),
            duration: 3600
        )
    ]
    
    // MARK: - 3D Stereoscopic Content
    
    static let stereo3DVideos: [MediaItem] = [
        MediaItem(
            title: "3D Movie - Side-by-Side",
            description: "Full 3D stereoscopic - SBS format",
            url: URL(string: "https://example.com/media/3d_sbs_movie.mp4")!,
            sourceKind: .ffmpegContainer,
            codec: .h264,
            vrFormat: .sideBySide3D,
            thumbnailURL: URL(string: "https://example.com/thumbs/3d_sbs.jpg"),
            duration: 7200
        ),
        MediaItem(
            title: "3D Action - Top-and-Bottom",
            description: "Stereoscopic 3D - TAB format",
            url: URL(string: "https://example.com/media/3d_tab_action.mp4")!,
            sourceKind: .ffmpegContainer,
            codec: .hevc,
            vrFormat: .topBottom3D,
            thumbnailURL: URL(string: "https://example.com/thumbs/3d_tab.jpg"),
            duration: 5400
        )
    ]
    
    // MARK: - 180° VR Content
    
    static let vr180Videos: [MediaItem] = [
        MediaItem(
            title: "180° VR Experience - Mono",
            description: "Immersive 180-degree monoscopic video",
            url: URL(string: "https://example.com/media/vr_180_mono.mp4")!,
            sourceKind: .ffmpegContainer,
            codec: .h264,
            vrFormat: .mono180,
            thumbnailURL: URL(string: "https://example.com/thumbs/vr_180_mono.jpg"),
            duration: 600
        ),
        MediaItem(
            title: "180° VR - Stereoscopic SBS",
            description: "Side-by-side stereoscopic 180° VR",
            url: URL(string: "https://example.com/media/vr_180_stereo_sbs.mp4")!,
            sourceKind: .ffmpegContainer,
            codec: .hevc,
            vrFormat: .stereo180SBS,
            thumbnailURL: URL(string: "https://example.com/thumbs/vr_180_sbs.jpg"),
            duration: 600
        ),
        MediaItem(
            title: "180° VR - Stereoscopic TAB",
            description: "Top-and-bottom 180° VR video",
            url: URL(string: "https://example.com/media/vr_180_stereo_tab.mp4")!,
            sourceKind: .ffmpegContainer,
            codec: .h264,
            vrFormat: .stereo180TAB,
            thumbnailURL: URL(string: "https://example.com/thumbs/vr_180_tab.jpg"),
            duration: 600
        )
    ]
    
    // MARK: - 360° VR Content
    
    static let vr360Videos: [MediaItem] = [
        MediaItem(
            title: "360° VR World - Mono",
            description: "Full 360-degree monoscopic panorama",
            url: URL(string: "https://example.com/media/vr_360_mono.mp4")!,
            sourceKind: .ffmpegContainer,
            codec: .h264,
            vrFormat: .mono360,
            thumbnailURL: URL(string: "https://example.com/thumbs/vr_360_mono.jpg"),
            duration: 300
        ),
        MediaItem(
            title: "360° VR - Stereoscopic SBS",
            description: "Immersive 360° side-by-side stereo",
            url: URL(string: "https://example.com/media/vr_360_stereo_sbs.mp4")!,
            sourceKind: .ffmpegContainer,
            codec: .hevc,
            vrFormat: .stereo360SBS,
            thumbnailURL: URL(string: "https://example.com/thumbs/vr_360_sbs.jpg"),
            duration: 300
        ),
        MediaItem(
            title: "360° VR - Stereoscopic TAB",
            description: "360° top-and-bottom stereoscopic",
            url: URL(string: "https://example.com/media/vr_360_stereo_tab.mp4")!,
            sourceKind: .ffmpegContainer,
            codec: .h264,
            vrFormat: .stereo360TAB,
            thumbnailURL: URL(string: "https://example.com/thumbs/vr_360_tab.jpg"),
            duration: 300
        )
    ]
    
    // MARK: - Raw Stream Examples
    
    static let rawStreamVideos: [MediaItem] = [
        MediaItem(
            title: "Raw H.264 Stream",
            description: "Raw Annex-B H.264 over HTTP",
            url: URL(string: "http://example.com/stream/raw_h264.h264")!,
            sourceKind: .rawAnnexB,
            codec: .h264,
            vrFormat: .flat2D,
            thumbnailURL: URL(string: "https://example.com/thumbs/raw_h264.jpg"),
            duration: 1800
        ),
        MediaItem(
            title: "Raw HEVC Stream",
            description: "Raw Annex-B HEVC over HTTPS",
            url: URL(string: "https://example.com/stream/raw_hevc.h265")!,
            sourceKind: .rawAnnexB,
            codec: .hevc,
            vrFormat: .flat2D,
            thumbnailURL: URL(string: "https://example.com/thumbs/raw_hevc.jpg"),
            duration: 1800
        )
    ]
    
    // MARK: - Streaming Formats
    
    static let streamingVideos: [MediaItem] = [
        MediaItem(
            title: "HLS Live Stream",
            description: "HTTP Live Streaming (m3u8)",
            url: URL(string: "https://example.com/hls/stream.m3u8")!,
            sourceKind: .ffmpegContainer,
            codec: .h264,
            vrFormat: .flat2D,
            thumbnailURL: URL(string: "https://example.com/thumbs/hls_stream.jpg"),
            duration: 14400
        ),
        MediaItem(
            title: "DASH Stream",
            description: "DASH MPD streaming",
            url: URL(string: "https://example.com/dash/manifest.mpd")!,
            sourceKind: .ffmpegContainer,
            codec: .hevc,
            vrFormat: .flat2D,
            thumbnailURL: URL(string: "https://example.com/thumbs/dash_stream.jpg"),
            duration: 14400
        )
    ]
    
    // MARK: - All Media Items
    
    static let allMedia: [MediaItem] = {
        return flat2DVideos + stereo3DVideos + vr180Videos + vr360Videos + rawStreamVideos + streamingVideos
    }()
    
    // MARK: - Grouped by Category
    
    static let groupedMedia: [(category: String, items: [MediaItem])] = [
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
        return allMedia.map { item in
            var modified = item
            
            // Replace URL scheme
            let urlString = item.url.absoluteString
            for (templateHost, replacementHost) in urlMapping {
                if urlString.contains(templateHost) {
                    if let newURL = URL(string: urlString.replacingOccurrences(of: templateHost, with: replacementHost)) {
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
            }
            
            return modified
        }
    }
    
    /// Get media items by VR format
    static func mediaByFormat(_ format: VRFormat) -> [MediaItem] {
        return allMedia.filter { $0.vrFormat == format }
    }
    
    /// Get stereoscopic media only
    static func stereoMediaOnly() -> [MediaItem] {
        return allMedia.filter { $0.vrFormat.isStereoscopic }
    }
    
    /// Get immersive (VR) media only
    static func immersiveMediaOnly() -> [MediaItem] {
        return allMedia.filter { $0.vrFormat.isImmersive }
    }
}
