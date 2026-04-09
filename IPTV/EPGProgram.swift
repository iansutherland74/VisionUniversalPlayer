import Foundation

struct EPGProgram: Identifiable, Codable, Hashable {
    let id: String
    let channelId: String
    let title: String
    let details: String
    let startDate: Date
    let endDate: Date

    init(
        id: String = UUID().uuidString,
        channelId: String,
        title: String,
        details: String,
        startDate: Date,
        endDate: Date
    ) {
        self.id = id
        self.channelId = channelId
        self.title = title
        self.details = details
        self.startDate = startDate
        self.endDate = endDate
    }
}
