import Foundation

struct IPTVPlaylist: Identifiable, Codable {
    let id: UUID
    let title: String
    let sourceURL: URL
    let channels: [IPTVChannel]
    let loadedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        sourceURL: URL,
        channels: [IPTVChannel],
        loadedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.sourceURL = sourceURL
        self.channels = channels
        self.loadedAt = loadedAt
    }

    var groups: [IPTVGroup] {
        let grouped = Dictionary(grouping: channels) { $0.groupTitle.isEmpty ? "Ungrouped" : $0.groupTitle }
        return grouped
            .map { IPTVGroup(name: $0.key, channels: $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func search(_ query: String) -> [IPTVChannel] {
        guard query.isEmpty == false else { return channels }
        let q = query.lowercased()
        return channels.filter {
            $0.name.lowercased().contains(q)
            || ($0.tvgName?.lowercased().contains(q) ?? false)
            || ($0.groupTitle.lowercased().contains(q))
        }
    }
}
