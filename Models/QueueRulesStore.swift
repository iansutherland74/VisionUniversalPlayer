import Foundation

struct QueueRulesSnapshot: Codable {
    let autoRemoveWatched: Bool
    let pinFavoritesFirst: Bool
    let protectPinnedFromAutoRemove: Bool
}

final class QueueRulesStore {
    static let shared = QueueRulesStore()

    private let defaults: UserDefaults
    private let key = "queue.rules.snapshot.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> QueueRulesSnapshot {
        guard let data = defaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(QueueRulesSnapshot.self, from: data) else {
            return QueueRulesSnapshot(
                autoRemoveWatched: false,
                pinFavoritesFirst: false,
                protectPinnedFromAutoRemove: true
            )
        }
        return snapshot
    }

    func save(autoRemoveWatched: Bool, pinFavoritesFirst: Bool, protectPinnedFromAutoRemove: Bool) {
        let snapshot = QueueRulesSnapshot(
            autoRemoveWatched: autoRemoveWatched,
            pinFavoritesFirst: pinFavoritesFirst,
            protectPinnedFromAutoRemove: protectPinnedFromAutoRemove
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }
}
