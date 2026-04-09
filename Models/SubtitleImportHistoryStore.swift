import Foundation

struct SubtitleImportHistory: Codable {
    let recentURLs: [String]
}

final class SubtitleImportHistoryStore {
    static let shared = SubtitleImportHistoryStore()

    private let defaults: UserDefaults
    private let key = "subtitle.import.history.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadRecentURLs() -> [String] {
        guard let data = defaults.data(forKey: key),
              let history = try? JSONDecoder().decode(SubtitleImportHistory.self, from: data) else {
            return []
        }
        return history.recentURLs
    }

    func add(url: String) {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var current = loadRecentURLs()
        current.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        current.insert(trimmed, at: 0)
        if current.count > 12 {
            current = Array(current.prefix(12))
        }
        save(current)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }

    private func save(_ urls: [String]) {
        let history = SubtitleImportHistory(recentURLs: urls)
        guard let data = try? JSONEncoder().encode(history) else { return }
        defaults.set(data, forKey: key)
    }
}
