import Foundation

struct PlaybackQueueSnapshot: Codable {
    let linearItems: [MediaItem]
    let queueItems: [MediaItem]
    let queueIndex: Int
    let shuffleEnabled: Bool
    let repeatAllEnabled: Bool
}

final class PlaybackQueueStore {
    static let shared = PlaybackQueueStore()

    private let defaults: UserDefaults
    private let snapshotKey = "playback.queue.snapshot"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func save(_ snapshot: PlaybackQueueSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
    }

    func load() -> PlaybackQueueSnapshot? {
        guard let data = defaults.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(PlaybackQueueSnapshot.self, from: data)
    }

    func clear() {
        defaults.removeObject(forKey: snapshotKey)
    }

    var hasSnapshot: Bool {
        defaults.data(forKey: snapshotKey) != nil
    }
}
