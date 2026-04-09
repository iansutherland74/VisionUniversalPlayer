import Foundation

actor IPTVXtreamAPI {
    struct Credentials: Codable {
        let serverURL: URL
        let username: String
        let password: String
    }

    struct Category: Identifiable, Codable, Hashable {
        let categoryId: String
        let categoryName: String

        var id: String { categoryId }
    }

    struct StreamItem: Codable {
        let streamId: Int
        let name: String
        let categoryId: String
        let streamIcon: String?
        let tvArchive: Int?
        let tvArchiveDuration: String?

        enum CodingKeys: String, CodingKey {
            case streamId = "stream_id"
            case name
            case categoryId = "category_id"
            case streamIcon = "stream_icon"
            case tvArchive = "tv_archive"
            case tvArchiveDuration = "tv_archive_duration"
        }
    }

    enum APIError: Error {
        case invalidResponse
    }

    private let credentials: Credentials
    private let session: URLSession
    private let userAgent: String?

    init(credentials: Credentials, session: URLSession = .shared, userAgent: String? = nil) {
        self.credentials = credentials
        self.session = session
        self.userAgent = userAgent
    }

    func fetchLiveCategories() async throws -> [Category] {
        let url = apiURL(action: "get_live_categories")
        await DebugCategory.xtream.traceLog("Fetching Xtream live categories", context: ["url": url.absoluteString])
        let (data, response) = try await session.data(for: request(url: url))
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            await DebugCategory.xtream.errorLog("Xtream categories request failed", context: ["url": url.absoluteString])
            throw APIError.invalidResponse
        }

        struct CategoryDTO: Codable {
            let categoryId: String
            let categoryName: String

            enum CodingKeys: String, CodingKey {
                case categoryId = "category_id"
                case categoryName = "category_name"
            }
        }

        let dto = try JSONDecoder().decode([CategoryDTO].self, from: data)
        await DebugCategory.xtream.infoLog(
            "Fetched Xtream categories",
            context: ["count": String(dto.count)]
        )
        return dto.map { Category(categoryId: $0.categoryId, categoryName: $0.categoryName) }
    }

    func fetchLiveStreams() async throws -> [IPTVChannel] {
        let url = apiURL(action: "get_live_streams")
        await DebugCategory.xtream.traceLog("Fetching Xtream live streams", context: ["url": url.absoluteString])
        let (data, response) = try await session.data(for: request(url: url))
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            await DebugCategory.xtream.errorLog("Xtream streams request failed", context: ["url": url.absoluteString])
            throw APIError.invalidResponse
        }

        let streams = try JSONDecoder().decode([StreamItem].self, from: data)
        let channels = streams.compactMap { stream in
            let liveURL = credentials.serverURL
                .appendingPathComponent("live")
                .appendingPathComponent(credentials.username)
                .appendingPathComponent(credentials.password)
                .appendingPathComponent("\(stream.streamId).ts")

            let normalizedName = IPTVTitleNormalizer.normalize(stream.name)

            return IPTVChannel(
                id: String(stream.streamId),
                name: normalizedName,
                streamURL: liveURL,
                logoURL: stream.streamIcon.flatMap(URL.init(string:)),
                groupTitle: stream.categoryId,
                tvgID: String(stream.streamId),
                tvgName: normalizedName,
                hasArchive: streamHasArchive(stream),
                archiveDays: streamArchiveDays(stream),
                catchupSource: nil,
                isXtream: true
            )
        }
        await DebugCategory.xtream.infoLog(
            "Fetched Xtream streams",
            context: ["streams": String(streams.count), "channels": String(channels.count)]
        )
        return channels
    }

    private func streamHasArchive(_ stream: StreamItem) -> Bool {
        if (stream.tvArchive ?? 0) > 0 {
            return true
        }

        if let days = streamArchiveDays(stream), days > 0 {
            return true
        }

        return false
    }

    private func streamArchiveDays(_ stream: StreamItem) -> Int? {
        guard let raw = stream.tvArchiveDuration?.trimmingCharacters(in: .whitespacesAndNewlines), raw.isEmpty == false else {
            return nil
        }
        return Int(raw)
    }

    private func apiURL(action: String) -> URL {
        var components = URLComponents(url: credentials.serverURL, resolvingAgainstBaseURL: false)
        components?.path = "/player_api.php"
        components?.queryItems = [
            URLQueryItem(name: "username", value: credentials.username),
            URLQueryItem(name: "password", value: credentials.password),
            URLQueryItem(name: "action", value: action)
        ]
        return components?.url ?? credentials.serverURL
    }

    private func request(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        if let userAgent, userAgent.isEmpty == false {
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }
        return request
    }
}
