import Foundation

struct IPTVGroup: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    var channels: [IPTVChannel]

    init(name: String, channels: [IPTVChannel]) {
        self.id = name.lowercased().replacingOccurrences(of: " ", with: "-")
        self.name = name
        self.channels = channels
    }
}
