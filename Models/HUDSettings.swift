import Foundation

struct HUDSettings: Codable, Equatable {
    var showVideoStats: Bool = true
    var showPlaybackDiagnosis: Bool = true
    var showAudioMeters: Bool = true
    var showSpatialDetails: Bool = true
    var showPipelineStatus: Bool = true
    var showRecommendations: Bool = true
    var opacity: Double = 0.92
    var autoHideInterval: Double = 4.0

    static let `default` = HUDSettings()
}
