import Foundation
import Combine

final class AudioMixer: ObservableObject {
    struct MeterSample {
        let leftRMS: Double
        let rightRMS: Double
        let leftPeak: Double
        let rightPeak: Double
        let centerRMS: Double
        let surroundRMS: Double
    }

    struct DolbyAtmosMetadata {
        let isAtmos: Bool
        let objectCount: Int?
        let bedChannels: String
        let channelLayoutDescription: String
    }

    enum DolbyAtmosMode: String, CaseIterable, Identifiable {
        case auto = "Auto"
        case native = "Native"
        case multichannelPCM = "Multichannel PCM"
        case stereoDownmix = "Stereo Downmix"

        var id: String { rawValue }
    }

    @Published private(set) var prefersDolbyAtmos = true
    @Published private(set) var downmixMode: DolbyAtmosMode = .auto
    @Published private(set) var dialogEnhancementEnabled = false
    @Published private(set) var atmosMetadata: DolbyAtmosMetadata = .init(
        isAtmos: false,
        objectCount: nil,
        bedChannels: "5.1",
        channelLayoutDescription: "Stereo"
    )

    private var volume: Float = 1.0
    private var isMuted = false
    private var preampDB: Float = 0
    private var spectralTilt: Double = 0.2

    func setAtmosMetadata(_ isAtmos: Bool, objectCount: Int?, bedChannels: String, channelLayout: String) {
        atmosMetadata = DolbyAtmosMetadata(
            isAtmos: isAtmos,
            objectCount: objectCount,
            bedChannels: bedChannels,
            channelLayoutDescription: channelLayout
        )
        Task {
            await DebugCategory.atmos.infoLog(
                "Atmos metadata updated",
                context: [
                    "isAtmos": isAtmos ? "true" : "false",
                    "objectCount": objectCount.map(String.init) ?? "nil",
                    "bedChannels": bedChannels,
                    "layout": channelLayout
                ]
            )
        }
    }

    func configure(volume: Float, isMuted: Bool, profile: AudioEffectsProfile) {
        self.volume = max(0, min(volume, 1))
        self.isMuted = isMuted
        preampDB = profile.preampDB
        let lowBand = profile.bandGainsDB.prefix(4).reduce(0, +)
        let highBand = profile.bandGainsDB.suffix(4).reduce(0, +)
        spectralTilt = Double((highBand - lowBand) / 48)
        Task {
            await DebugCategory.audioEngine.infoLog(
                "Audio mixer configured",
                context: [
                    "volume": String(format: "%.3f", self.volume),
                    "muted": self.isMuted ? "true" : "false",
                    "preampDB": String(format: "%.2f", self.preampDB)
                ]
            )
        }
    }

    func setPrefersDolbyAtmos(_ enabled: Bool) {
        prefersDolbyAtmos = enabled
        Task {
            await DebugCategory.atmos.infoLog(
                "Dolby Atmos preference changed",
                context: ["enabled": enabled ? "true" : "false"]
            )
        }
    }

    func setDownmixMode(_ mode: DolbyAtmosMode) {
        downmixMode = mode
        Task {
            await DebugCategory.audioEngine.infoLog(
                "Downmix mode changed",
                context: ["mode": mode.rawValue]
            )
        }
    }

    func setDialogEnhancementEnabled(_ enabled: Bool) {
        dialogEnhancementEnabled = enabled
        Task {
            await DebugCategory.audioEngine.infoLog(
                "Dialog enhancement changed",
                context: ["enabled": enabled ? "true" : "false"]
            )
        }
    }

    func sample(at date: Date = Date()) -> MeterSample {
        let t = date.timeIntervalSinceReferenceDate
        let envelope = isMuted ? 0.0 : Double(max(0.05, volume))
        let gain = envelope * Double(1.0 + (preampDB / 18.0))
        let leftBase = 0.36 + (sin(t * 2.1) * 0.18)
        let rightBase = 0.33 + (cos(t * 1.7) * 0.2)
        let centerBase = 0.42 + (sin(t * 1.9) * 0.15)
        let surroundBase = 0.28 + (cos(t * 2.3) * 0.12)
        let spectralBias = spectralTilt * 0.12
        let leftRMS = max(0.0, min(1.0, (leftBase + spectralBias) * gain))
        let rightRMS = max(0.0, min(1.0, (rightBase - spectralBias) * gain))
        let centerRMS = max(0.0, min(1.0, (centerBase) * gain))
        let surroundRMS = max(0.0, min(1.0, (surroundBase) * gain))
        let headroomLift = dialogEnhancementEnabled ? 0.1 : 0.0
        let leftPeak = max(leftRMS, min(1.0, leftRMS + 0.16 + headroomLift))
        let rightPeak = max(rightRMS, min(1.0, rightRMS + 0.14 + headroomLift))
        return MeterSample(
            leftRMS: leftRMS,
            rightRMS: rightRMS,
            leftPeak: leftPeak,
            rightPeak: rightPeak,
            centerRMS: centerRMS,
            surroundRMS: surroundRMS
        )
    }
}
