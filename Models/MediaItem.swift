import Foundation

enum CodecType: String, Codable, CaseIterable, Hashable {
    case h264 = "h264"
    case hevc = "hevc"
    case av1 = "av1"
    case vp9 = "vp9"
    case vp8 = "vp8"
    case mpeg2 = "mpeg2"
    
    var ffmpegCodecName: String {
        switch self {
        case .h264:
            return "h264"
        case .hevc:
            return "hevc"
        case .av1:
            return "av1"
        case .vp9:
            return "vp9"
        case .vp8:
            return "vp8"
        case .mpeg2:
            return "mpeg2video"
        }
    }
    
    var filmstripFilterName: String {
        switch self {
        case .h264:
            return "h264_mp4toannexb"
        case .hevc:
            return "hevc_mp4toannexb"
        case .av1:
            return ""
        case .vp9:
            return ""
        case .vp8:
            return ""
        case .mpeg2:
            return ""
        }
    }
}

enum SourceKind: Codable, Hashable {
    case rawAnnexB
    case ffmpegContainer
    /// Local MV-HEVC file decoded via MVHEVCLocalEngine (SpatialMediaKit port).
    case mvhevcLocal
}

enum VRFormat: String, Codable, CaseIterable, Hashable {
    case flat2D = "flat2D"
    case sideBySide3D = "sbs3D"
    case topBottom3D = "tab3D"
    case mono180 = "mono180"
    case stereo180SBS = "stereo180_sbs"
    case stereo180TAB = "stereo180_tab"
    case mono360 = "mono360"
    case stereo360SBS = "stereo360_sbs"
    case stereo360TAB = "stereo360_tab"
    
    var description: String {
        switch self {
        case .flat2D:
            return "2D Flat"
        case .sideBySide3D:
            return "3D Side-by-Side"
        case .topBottom3D:
            return "3D Top-and-Bottom"
        case .mono180:
            return "180° Mono"
        case .stereo180SBS:
            return "180° Stereo (SBS)"
        case .stereo180TAB:
            return "180° Stereo (TAB)"
        case .mono360:
            return "360° Mono"
        case .stereo360SBS:
            return "360° Stereo (SBS)"
        case .stereo360TAB:
            return "360° Stereo (TAB)"
        }
    }
    
    var isStereoscopic: Bool {
        switch self {
        case .flat2D, .mono180, .mono360:
            return false
        default:
            return true
        }
    }
    
    var isImmersive: Bool {
        switch self {
        case .mono180, .stereo180SBS, .stereo180TAB, .mono360, .stereo360SBS, .stereo360TAB:
            return true
        default:
            return false
        }
    }
}

enum VideoProjection: Codable, Hashable {
    case equirectangular(fieldOfView: Float, force: Bool = false)
    case rectangular
    case appleImmersive
}

enum FramePacking: Codable, Hashable {
    case none
    case sideBySide(baseline: Float? = nil, horizontalDisparity: Float? = nil)
    case overUnder(baseline: Float? = nil, horizontalDisparity: Float? = nil)

    static let sideBySide: FramePacking = .sideBySide()
    static let overUnder: FramePacking = .overUnder()

    var baseline: Float? {
        switch self {
        case .none:
            return nil
        case .sideBySide(let baseline, _), .overUnder(let baseline, _):
            return baseline
        }
    }

    var horizontalDisparity: Float? {
        switch self {
        case .none:
            return nil
        case .sideBySide(_, let horizontalDisparity), .overUnder(_, let horizontalDisparity):
            return horizontalDisparity
        }
    }
}

struct MediaItem: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let description: String
    let url: URL
    let sourceKind: SourceKind
    let codec: CodecType
    let vrFormat: VRFormat
    let projection: VideoProjection?
    let framePacking: FramePacking
    let thumbnailURL: URL?
    let duration: TimeInterval?
    
    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        url: URL,
        sourceKind: SourceKind,
        codec: CodecType,
        vrFormat: VRFormat = .flat2D,
        projection: VideoProjection? = nil,
        framePacking: FramePacking? = nil,
        thumbnailURL: URL? = nil,
        duration: TimeInterval? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.url = url
        self.sourceKind = sourceKind
        self.codec = codec
        self.vrFormat = vrFormat
        self.projection = projection ?? vrFormat.defaultProjection
        self.framePacking = framePacking ?? vrFormat.defaultFramePacking
        self.thumbnailURL = thumbnailURL ?? YouTubeURL.thumbnailURL(from: url)
        self.duration = duration
    }
}

extension MediaItem {
    var resolvedProjection: VideoProjection {
        projection ?? vrFormat.defaultProjection
    }

    var resolvedFramePacking: FramePacking {
        framePacking
    }

    var stereoBaseline: Float {
        framePacking.baseline ?? 60.0
    }

    var stereoHorizontalDisparity: Float {
        framePacking.horizontalDisparity ?? 0.0
    }
}

private extension VRFormat {
    var defaultProjection: VideoProjection {
        switch self {
        case .mono180, .stereo180SBS, .stereo180TAB:
            return .equirectangular(fieldOfView: 180.0)
        case .mono360, .stereo360SBS, .stereo360TAB:
            return .equirectangular(fieldOfView: 360.0)
        case .flat2D, .sideBySide3D, .topBottom3D:
            return .rectangular
        }
    }

    var defaultFramePacking: FramePacking {
        switch self {
        case .sideBySide3D, .stereo180SBS, .stereo360SBS:
            return .sideBySide()
        case .topBottom3D, .stereo180TAB, .stereo360TAB:
            return .overUnder()
        case .flat2D, .mono180, .mono360:
            return .none
        }
    }
}

// MARK: - Sample Media for Demo

extension MediaItem {
    static let samples: [MediaItem] = [
        MediaItem(
            title: "Sample H.264 Stream",
            description: "HTTP-based H.264 Annex-B stream",
            url: URL(string: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8")!,
            sourceKind: .rawAnnexB,
            codec: .h264,
            vrFormat: .flat2D,
            thumbnailURL: URL(string: "https://storage.googleapis.com/gtv-videos-bucket/sample/images/BigBuckBunny.jpg"),
            duration: 3600
        ),
        MediaItem(
            title: "HLS Video",
            description: "HTTP Live Streaming (m3u8) with H.264",
            url: URL(string: "https://bitdash-a.akamaihd.net/content/sintel/hls/playlist.m3u8")!,
            sourceKind: .ffmpegContainer,
            codec: .h264,
            vrFormat: .flat2D,
            thumbnailURL: URL(string: "https://storage.googleapis.com/gtv-videos-bucket/sample/images/Sintel.jpg"),
            duration: 7200
        ),
        MediaItem(
            title: "HEVC MP4",
            description: "MP4 container with HEVC codec",
            url: URL(string: "https://storage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")!,
            sourceKind: .ffmpegContainer,
            codec: .hevc,
            vrFormat: .flat2D,
            thumbnailURL: URL(string: "https://storage.googleapis.com/gtv-videos-bucket/sample/images/BigBuckBunny.jpg"),
            duration: 5400
        ),
        MediaItem(
            title: "3D SBS Video",
            description: "Side-by-side 3D stereoscopic",
            url: URL(string: "https://storage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4")!,
            sourceKind: .ffmpegContainer,
            codec: .h264,
            vrFormat: .sideBySide3D,
            thumbnailURL: URL(string: "https://storage.googleapis.com/gtv-videos-bucket/sample/images/ElephantsDream.jpg"),
            duration: 4800
        ),
        MediaItem(
            title: "360° Video",
            description: "Immersive panoramic video",
            url: URL(string: "https://storage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4")!,
            sourceKind: .ffmpegContainer,
            codec: .hevc,
            vrFormat: .mono360,
            thumbnailURL: URL(string: "https://storage.googleapis.com/gtv-videos-bucket/sample/images/TearsOfSteel.jpg"),
            duration: 6000
        )
    ]
}
