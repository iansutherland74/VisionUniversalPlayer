import Foundation
import Combine

@MainActor
final class AudioEngine: ObservableObject {
    let mixer = AudioMixer()
    let spatializer = AudioSpatializer()

    @Published private(set) var audioSyncOffsetMS: Double = 0
    @Published private(set) var lipSyncCalibrationMS: Double = 0

    func refresh(volume: Float, isMuted: Bool, profile: AudioEffectsProfile, isImmersive: Bool) {
        mixer.configure(volume: volume, isMuted: isMuted, profile: profile)
        spatializer.configureForImmersiveMode(isImmersive)
        
        Task {
            await DebugEventBus.shared.post(
                category: .audioEngine,
                severity: .info,
                message: "Audio engine refresh",
                context: [
                    "volume": String(format: "%.2f", volume),
                    "muted": isMuted ? "true" : "false",
                    "profile": profile.displaySummary,
                    "immersive": isImmersive ? "true" : "false"
                ]
            )
        }
    }

    func setAudioSyncOffsetMS(_ value: Double) {
        audioSyncOffsetMS = max(-250, min(value, 250))
        
        Task {
            await DebugEventBus.shared.post(
                category: .sync,
                severity: .info,
                message: "Audio sync offset changed",
                context: ["offsetMS": String(format: "%.1f", audioSyncOffsetMS)]
            )
        }
    }

    func setLipSyncCalibrationMS(_ value: Double) {
        lipSyncCalibrationMS = max(-250, min(value, 250))
        
        Task {
            await DebugEventBus.shared.post(
                category: .lipSync,
                severity: .info,
                message: "Lip-sync calibration changed",
                context: ["calibrationMS": String(format: "%.1f", lipSyncCalibrationMS)]
            )
        }
    }
}
