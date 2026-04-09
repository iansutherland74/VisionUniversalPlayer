import Foundation

final class MediaLoudnessStore {
    static let shared = MediaLoudnessStore()

    private let defaults: UserDefaults
    private let key = "media.loudness.compensation.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func compensationDB(for media: MediaItem) -> Float {
        let map = loadMap()
        return max(-12, min(map[stableKey(for: media)] ?? 0, 12))
    }

    func setCompensationDB(_ value: Float, for media: MediaItem) {
        var map = loadMap()
        map[stableKey(for: media)] = max(-12, min(value, 12))
        saveMap(map)
    }

    func clearCompensation(for media: MediaItem) {
        var map = loadMap()
        map.removeValue(forKey: stableKey(for: media))
        saveMap(map)
    }

    func clearAll() {
        defaults.removeObject(forKey: key)
    }

    private func loadMap() -> [String: Float] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: Float].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func saveMap(_ map: [String: Float]) {
        guard let data = try? JSONEncoder().encode(map) else { return }
        defaults.set(data, forKey: key)
    }

    private func stableKey(for media: MediaItem) -> String {
        // Prefer URL-based key so imported libraries can keep loudness memory across app relaunches.
        media.url.absoluteString
    }
}
