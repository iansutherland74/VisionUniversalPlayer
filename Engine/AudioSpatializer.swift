import Foundation
import Combine

final class AudioSpatializer: ObservableObject {
    @Published private(set) var isEnabled = true
    @Published private(set) var headTrackingEnabled = true
    @Published private(set) var roomSize: Float = 0.58
    @Published private(set) var listenerAzimuth: Float = 0
    @Published private(set) var listenerElevation: Float = 0
    @Published private(set) var wideness: Float = 0.65

    var summary: String {
        if isEnabled == false {
            return "Stereo"
        }
        if headTrackingEnabled {
            return "Spatial + Head Tracking"
        }
        return "Static Spatial"
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        Task {
            await DebugCategory.spatialAudio.infoLog(
                "Spatial audio enabled changed",
                context: ["enabled": enabled ? "true" : "false"]
            )
        }
    }

    func setHeadTrackingEnabled(_ enabled: Bool) {
        headTrackingEnabled = enabled
        Task {
            await DebugCategory.spatialAudio.infoLog(
                "Head tracking changed",
                context: ["enabled": enabled ? "true" : "false"]
            )
        }
    }

    func setRoomSize(_ value: Float) {
        roomSize = max(0, min(value, 1))
        Task {
            await DebugCategory.spatialAudio.traceLog(
                "Room size changed",
                context: ["value": String(format: "%.3f", roomSize)]
            )
        }
    }

    func setListenerAzimuth(_ value: Float) {
        listenerAzimuth = max(-180, min(value, 180))
        Task {
            await DebugCategory.spatialAudio.traceLog(
                "Listener azimuth changed",
                context: ["degrees": String(format: "%.1f", listenerAzimuth)]
            )
        }
    }

    func setListenerElevation(_ value: Float) {
        listenerElevation = max(-90, min(value, 90))
        Task {
            await DebugCategory.spatialAudio.traceLog(
                "Listener elevation changed",
                context: ["degrees": String(format: "%.1f", listenerElevation)]
            )
        }
    }

    func setWideness(_ value: Float) {
        wideness = max(0, min(value, 1))
        Task {
            await DebugCategory.spatialAudio.traceLog(
                "Spatial wideness changed",
                context: ["value": String(format: "%.3f", wideness)]
            )
        }
    }

    func configureForImmersiveMode(_ isImmersive: Bool) {
        if isImmersive {
            isEnabled = true
            headTrackingEnabled = true
            Task {
                await DebugCategory.immersive.infoLog("Spatializer configured for immersive mode")
            }
        }
    }
}
