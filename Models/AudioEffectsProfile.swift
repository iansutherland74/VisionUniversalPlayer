import Foundation

struct AudioEffectsProfile: Equatable {
    // VLC-style 10-band EQ centers (Hz): 31, 63, 125, 250, 500, 1k, 2k, 4k, 8k, 16k
    static let bandFrequenciesHz: [Int] = [31, 63, 125, 250, 500, 1_000, 2_000, 4_000, 8_000, 16_000]

    var preampDB: Float
    var bandGainsDB: [Float]
    var normalizationEnabled: Bool
    var limiterEnabled: Bool

    init(
        preampDB: Float = 0,
        bandGainsDB: [Float]? = nil,
        normalizationEnabled: Bool = false,
        limiterEnabled: Bool = true
    ) {
        self.preampDB = max(-12, min(preampDB, 12))
        self.bandGainsDB = AudioEffectsProfile.clampBandArray(bandGainsDB ?? Array(repeating: 0, count: AudioEffectsProfile.bandFrequenciesHz.count))
        self.normalizationEnabled = normalizationEnabled
        self.limiterEnabled = limiterEnabled
    }

    static var flat: AudioEffectsProfile {
        AudioEffectsProfile()
    }

    mutating func setBandGain(at index: Int, db: Float) {
        guard bandGainsDB.indices.contains(index) else { return }
        bandGainsDB[index] = max(-12, min(db, 12))
    }

    mutating func resetEqualizer() {
        bandGainsDB = Array(repeating: 0, count: AudioEffectsProfile.bandFrequenciesHz.count)
    }

    func clamped() -> AudioEffectsProfile {
        AudioEffectsProfile(
            preampDB: max(-12, min(preampDB, 12)),
            bandGainsDB: AudioEffectsProfile.clampBandArray(bandGainsDB),
            normalizationEnabled: normalizationEnabled,
            limiterEnabled: limiterEnabled
        )
    }

    var displaySummary: String {
        let activeBands = bandGainsDB.filter { abs($0) >= 0.25 }.count
        if activeBands == 0 {
            return "Flat"
        }
        return "\(activeBands) bands"
    }

    private static func clampBandArray(_ source: [Float]) -> [Float] {
        var output = source
        if output.count < bandFrequenciesHz.count {
            output.append(contentsOf: Array(repeating: 0, count: bandFrequenciesHz.count - output.count))
        } else if output.count > bandFrequenciesHz.count {
            output = Array(output.prefix(bandFrequenciesHz.count))
        }
        return output.map { max(-12, min($0, 12)) }
    }
}

enum AudioEffectsPreset: String, CaseIterable, Identifiable {
    case flat = "Flat"
    case vocalBoost = "Vocal Boost"
    case bassBoost = "Bass Boost"
    case trebleBoost = "Treble Boost"
    case cinematic = "Cinematic"

    var id: String { rawValue }

    var profile: AudioEffectsProfile {
        switch self {
        case .flat:
            return .flat
        case .vocalBoost:
            return AudioEffectsProfile(preampDB: 1.0, bandGainsDB: [-2, -1, 0, 1.5, 2.5, 3.0, 2.0, 1.0, -0.5, -1.0], normalizationEnabled: false, limiterEnabled: true)
        case .bassBoost:
            return AudioEffectsProfile(preampDB: 1.5, bandGainsDB: [4.0, 3.0, 2.0, 1.0, 0.5, 0, -0.5, -1.0, -1.5, -2.0], normalizationEnabled: false, limiterEnabled: true)
        case .trebleBoost:
            return AudioEffectsProfile(preampDB: 0.5, bandGainsDB: [-2.0, -1.5, -1.0, -0.5, 0, 0.5, 1.5, 2.5, 3.0, 3.5], normalizationEnabled: false, limiterEnabled: true)
        case .cinematic:
            return AudioEffectsProfile(preampDB: 1.0, bandGainsDB: [2.5, 2.0, 1.0, 0.5, 0, -0.5, 0, 0.8, 1.6, 2.0], normalizationEnabled: true, limiterEnabled: true)
        }
    }
}
