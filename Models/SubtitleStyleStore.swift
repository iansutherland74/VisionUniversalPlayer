import Foundation

enum SubtitleStylePreset: String, CaseIterable, Identifiable {
    case cinema = "Cinema"
    case minimal = "Minimal"
    case broadcast = "Broadcast"
    case immersive = "Immersive"

    var id: String { rawValue }

    var fontScale: Double {
        switch self {
        case .cinema: return 1.2
        case .minimal: return 0.9
        case .broadcast: return 1.0
        case .immersive: return 1.3
        }
    }

    var backgroundOpacity: Double {
        switch self {
        case .cinema: return 0.62
        case .minimal: return 0.2
        case .broadcast: return 0.72
        case .immersive: return 0.45
        }
    }

    var position: String {
        switch self {
        case .cinema: return "low"
        case .minimal: return "mid"
        case .broadcast: return "low"
        case .immersive: return "high"
        }
    }
}

final class SubtitleStyleStore {
    static let shared = SubtitleStyleStore()

    private let defaults: UserDefaults
    private let key = "subtitles.style.defaults.by.language.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func preset(for languageKey: String) -> SubtitleStylePreset? {
        let map = loadMap()
        guard let raw = map[normalized(languageKey)], let preset = SubtitleStylePreset(rawValue: raw) else {
            return nil
        }
        return preset
    }

    func setPreset(_ preset: SubtitleStylePreset, for languageKey: String) {
        var map = loadMap()
        map[normalized(languageKey)] = preset.rawValue
        saveMap(map)
    }

    func clearPreset(for languageKey: String) {
        var map = loadMap()
        map.removeValue(forKey: normalized(languageKey))
        saveMap(map)
    }

    private func loadMap() -> [String: String] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func saveMap(_ map: [String: String]) {
        guard let data = try? JSONEncoder().encode(map) else { return }
        defaults.set(data, forKey: key)
    }

    private func normalized(_ languageKey: String) -> String {
        let cleaned = languageKey.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "default" : cleaned
    }
}
