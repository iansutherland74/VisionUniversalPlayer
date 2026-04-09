import Foundation

struct IPTVChannel: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let streamURL: URL
    let logoURL: URL?
    let groupTitle: String
    let tvgID: String?
    let tvgName: String?
    let tvgShift: String?
    let countryCode: String?
    let languageCode: String?
    let hasArchive: Bool
    let archiveDays: Int?
    let catchupSource: String?
    let isXtream: Bool

    init(
        id: String = UUID().uuidString,
        name: String,
        streamURL: URL,
        logoURL: URL? = nil,
        groupTitle: String = "Ungrouped",
        tvgID: String? = nil,
        tvgName: String? = nil,
        tvgShift: String? = nil,
        countryCode: String? = nil,
        languageCode: String? = nil,
        hasArchive: Bool = false,
        archiveDays: Int? = nil,
        catchupSource: String? = nil,
        isXtream: Bool = false
    ) {
        self.id = id
        self.name = name
        self.streamURL = streamURL
        self.logoURL = logoURL
        self.groupTitle = groupTitle
        self.tvgID = tvgID
        self.tvgName = tvgName
        self.tvgShift = tvgShift
        self.countryCode = countryCode
        self.languageCode = languageCode
        self.hasArchive = hasArchive
        self.archiveDays = archiveDays
        self.catchupSource = catchupSource
        self.isXtream = isXtream
    }
}
