import Foundation

struct CinemaModeSettings: Codable, Equatable {
    var isEnabled: Bool = false
    var ambientLighting: Double = 0.48
    var seatDistance: Double = 0.62
    var screenScale: Double = 1.0
    var screenCurvature: Double = 0.18
    var environmentDimming: Double = 0.34

    static let `default` = CinemaModeSettings()
}
