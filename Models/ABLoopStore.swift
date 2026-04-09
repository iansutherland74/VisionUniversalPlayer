import Foundation

struct ABLoopSlot: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let startSeconds: TimeInterval
    let endSeconds: TimeInterval
}

final class ABLoopStore {
    static let shared = ABLoopStore()

    private let defaults: UserDefaults
    private let key = "ab.loop.slots.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func slots(for media: MediaItem) -> [ABLoopSlot] {
        loadMap()[stableKey(for: media)] ?? []
    }

    func add(_ slot: ABLoopSlot, for media: MediaItem) -> [ABLoopSlot] {
        var map = loadMap()
        var slots = map[stableKey(for: media)] ?? []
        slots.append(slot)
        if slots.count > 8 {
            slots = Array(slots.suffix(8))
        }
        map[stableKey(for: media)] = slots
        saveMap(map)
        return slots
    }

    func remove(slotID: UUID, for media: MediaItem) -> [ABLoopSlot] {
        var map = loadMap()
        var slots = map[stableKey(for: media)] ?? []
        slots.removeAll { $0.id == slotID }
        map[stableKey(for: media)] = slots
        saveMap(map)
        return slots
    }

    func clear(for media: MediaItem) {
        var map = loadMap()
        map.removeValue(forKey: stableKey(for: media))
        saveMap(map)
    }

    private func loadMap() -> [String: [ABLoopSlot]] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: [ABLoopSlot]].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func saveMap(_ map: [String: [ABLoopSlot]]) {
        guard let data = try? JSONEncoder().encode(map) else { return }
        defaults.set(data, forKey: key)
    }

    private func stableKey(for media: MediaItem) -> String {
        media.url.absoluteString
    }
}
