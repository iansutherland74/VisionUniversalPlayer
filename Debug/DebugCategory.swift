import Foundation

/// Categories for debug events, used for organizing and filtering logs.
/// Each subsystem should log to its appropriate category.
enum DebugCategory: String, CaseIterable, Codable {
    // Core app lifecycle
    case appLifecycle
    case navigation
    case system
    
    // Media demuxing and source handling
    case demuxer
    case iptv
    case playlist
    case epg
    case xtream
    case network
    case hls
    
    // Video decoding and rendering
    case decoder
    case renderer
    case metal
    case vr
    case depth3D
    
    // Audio processing
    case audioEngine
    case spatialAudio
    case atmos
    case vuMeters
    case sync
    case lipSync
    
    // UI and interaction
    case hud
    case settings
    case gestures
    case voice
    case cinemaMode
    case immersive
    case visionUIMetal
    
    var displayName: String {
        switch self {
        case .appLifecycle:
            return "App Lifecycle"
        case .navigation:
            return "Navigation"
        case .system:
            return "System"
        case .demuxer:
            return "Demuxer"
        case .iptv:
            return "IPTV"
        case .playlist:
            return "Playlist"
        case .epg:
            return "EPG"
        case .xtream:
            return "Xtream API"
        case .network:
            return "Network"
        case .hls:
            return "HLS"
        case .decoder:
            return "Decoder"
        case .renderer:
            return "Renderer"
        case .metal:
            return "Metal"
        case .vr:
            return "VR"
        case .depth3D:
            return "2D→3D Conversion"
        case .audioEngine:
            return "Audio Engine"
        case .spatialAudio:
            return "Spatial Audio"
        case .atmos:
            return "Dolby Atmos"
        case .vuMeters:
            return "VU Meters"
        case .sync:
            return "Audio Sync"
        case .lipSync:
            return "Lip Sync"
        case .hud:
            return "HUD"
        case .settings:
            return "Settings"
        case .gestures:
            return "Gestures"
        case .voice:
            return "Voice Commands"
        case .cinemaMode:
            return "Cinema Mode"
        case .immersive:
            return "Immersive"
        case .visionUIMetal:
            return "Vision UI Metal"
        }
    }
    
    var groupName: String {
        switch self {
        case .appLifecycle, .navigation, .system:
            return "App"
        case .demuxer, .iptv, .playlist, .epg, .xtream, .network, .hls:
            return "Media Source"
        case .decoder, .renderer, .metal, .vr, .depth3D:
            return "Video"
        case .audioEngine, .spatialAudio, .atmos, .vuMeters, .sync, .lipSync:
            return "Audio"
        case .hud, .settings, .gestures, .voice, .cinemaMode, .immersive, .visionUIMetal:
            return "UI"
        }
    }
}
