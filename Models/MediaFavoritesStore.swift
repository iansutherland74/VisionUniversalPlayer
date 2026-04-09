import Foundation
import Combine

@MainActor
final class MediaFavoritesStore: ObservableObject {
    @Published private(set) var favoriteURLs: Set<String> = []

    private let defaults: UserDefaults
    private let storageKey = "media.favorites.urls"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func isFavorite(_ item: MediaItem) -> Bool {
        favoriteURLs.contains(item.url.absoluteString)
    }

    func toggle(_ item: MediaItem) {
        let key = item.url.absoluteString
        if favoriteURLs.contains(key) {
            favoriteURLs.remove(key)
        } else {
            favoriteURLs.insert(key)
        }
        persist()
    }

    func setFavorite(_ item: MediaItem, isFavorite: Bool) {
        let key = item.url.absoluteString
        if isFavorite {
            favoriteURLs.insert(key)
        } else {
            favoriteURLs.remove(key)
        }
        persist()
    }

    func favorites(from items: [MediaItem]) -> [MediaItem] {
        items.filter { favoriteURLs.contains($0.url.absoluteString) }
    }

    private func load() {
        let values = defaults.stringArray(forKey: storageKey) ?? []
        favoriteURLs = Set(values)
    }

    private func persist() {
        defaults.set(Array(favoriteURLs).sorted(), forKey: storageKey)
    }
}
