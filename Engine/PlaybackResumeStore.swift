import Foundation

struct PlaybackResumeEntry: Codable {
    let mediaID: UUID
    let mediaURL: String
    let positionSeconds: TimeInterval
    let updatedAt: Date
}

@MainActor
final class PlaybackResumeStore {
    static let shared = PlaybackResumeStore()

    private let defaults = UserDefaults.standard
    private let storageKey = "PlaybackResumeEntries"
    private var cache: [String: PlaybackResumeEntry] = [:]

    private init() {
        load()
    }

    func savePosition(for media: MediaItem, seconds: TimeInterval) {
        guard seconds.isFinite, seconds >= 0 else { return }

        let key = makeKey(for: media)
        cache[key] = PlaybackResumeEntry(
            mediaID: media.id,
            mediaURL: media.url.absoluteString,
            positionSeconds: seconds,
            updatedAt: Date()
        )
        persist()
    }

    func position(for media: MediaItem) -> TimeInterval? {
        let key = makeKey(for: media)
        return cache[key]?.positionSeconds
    }

    private func makeKey(for media: MediaItem) -> String {
        "\(media.id.uuidString)|\(media.url.absoluteString)"
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey) else { return }
        do {
            cache = try JSONDecoder().decode([String: PlaybackResumeEntry].self, from: data)
        } catch {
            cache = [:]
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(cache)
            defaults.set(data, forKey: storageKey)
        } catch {
            Task {
                await DebugCategory.settings.errorLog(
                    "Failed to persist playback resume entries",
                    context: ["error": error.localizedDescription]
                )
            }
        }
    }
}
