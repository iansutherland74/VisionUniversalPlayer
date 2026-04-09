import Foundation

struct ImmersiveSceneSnapshot {
    let timestamp: Date
    let mode: String
    let renderSurface: String
    let modeEntityChildren: Int
    let controlsEntityChildren: Int
    let boundsGuidesEnabled: Bool

    let contentX: Double
    let contentY: Double
    let contentZ: Double

    let controlsX: Double
    let controlsY: Double
    let controlsZ: Double

    let headX: Double?
    let headY: Double?
    let headZ: Double?
}
