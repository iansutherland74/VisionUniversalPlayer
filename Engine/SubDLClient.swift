import Foundation

struct SubDLSearchResult: Identifiable, Hashable, Sendable {
    let id: String
    let type: String
    let name: String
    let year: Int?
    let linkPath: String
    let originalName: String?

    var titleDisplay: String {
        if let year {
            return "\(name) (\(year))"
        }
        return name
    }
}

struct SubDLSubtitleCandidate: Identifiable, Hashable, Sendable {
    let id: String
    let language: String
    let quality: String
    let title: String
    let comment: String?
    let downloadURL: URL
}

enum SubtitleProviderKind: String, Hashable, Sendable {
    case subdl = "SubDL"
    case openSubtitles = "OpenSubtitles"
    case podnapisi = "Podnapisi"
    case subtitleCat = "Subtitle Cat"
}

struct SubtitleProviderResult: Identifiable, Hashable, Sendable {
    enum ActionKind: Hashable, Sendable {
        case directDownload(URL)
        case externalLink(URL)
    }

    let id: String
    let provider: SubtitleProviderKind
    let title: String
    let subtitleLanguage: String
    let quality: String
    let score: Int
    let action: ActionKind
}

enum SubDLClientError: LocalizedError {
    case invalidSearchURL
    case invalidPageURL
    case invalidResponse
    case parseFailure

    var errorDescription: String? {
        switch self {
        case .invalidSearchURL:
            return "Invalid SubDL search URL"
        case .invalidPageURL:
            return "Invalid SubDL page URL"
        case .invalidResponse:
            return "Unexpected response from SubDL"
        case .parseFailure:
            return "Unable to parse SubDL response"
        }
    }
}

final class SubDLClient {
    private struct AutoResponse: Decodable {
        struct AutoResult: Decodable {
            let type: String
            let name: String
            let year: Int?
            let link: String
            let original_name: String?
        }

        let results: [AutoResult]
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func searchTitles(query: String) async throws -> [SubDLSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        await DebugCategory.network.traceLog("SubDL title search", context: ["query": trimmed])

        guard var components = URLComponents(string: "https://api.subdl.com/auto") else {
            throw SubDLClientError.invalidSearchURL
        }
        components.queryItems = [
            URLQueryItem(name: "query", value: trimmed)
        ]
        guard let url = components.url else {
            throw SubDLClientError.invalidSearchURL
        }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode)
        else {
            throw SubDLClientError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(AutoResponse.self, from: data)
        let results = decoded.results.map {
            SubDLSearchResult(
                id: $0.link,
                type: $0.type,
                name: $0.name,
                year: $0.year,
                linkPath: $0.link,
                originalName: $0.original_name
            )
        }
        await DebugCategory.network.infoLog("SubDL title search completed", context: ["count": String(results.count)])
        return results
    }

    func fetchSubtitleCandidates(detailPath: String, preferredLanguageKey: String?) async throws -> [SubDLSubtitleCandidate] {
        guard let url = URL(string: "https://subdl.com\(detailPath)") else {
            throw SubDLClientError.invalidPageURL
        }
        await DebugCategory.network.traceLog("Fetching SubDL subtitle candidates", context: ["url": url.absoluteString])

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              let html = String(data: data, encoding: .utf8)
        else {
            throw SubDLClientError.invalidResponse
        }

        guard let nextDataJSON = extractNextDataJSON(from: html),
              let nextData = nextDataJSON.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: nextData)
        else {
            throw SubDLClientError.parseFailure
        }

        var rawSubtitleDictionaries: [[String: Any]] = []
        collectSubtitleDictionaries(from: jsonObject, output: &rawSubtitleDictionaries)

        let preferred = normalizedLanguageHints(for: preferredLanguageKey)

        let mapped: [SubDLSubtitleCandidate] = rawSubtitleDictionaries.compactMap { dict in
            guard let language = dict["language"] as? String,
                  let quality = dict["quality"] as? String,
                  let title = dict["title"] as? String
            else {
                return nil
            }

            let directLink = dict["link"] as? String
            let bucketLink = dict["bucketLink"] as? String
            guard let downloadURL = makeDownloadURL(link: directLink, bucketLink: bucketLink) else {
                return nil
            }

            let id = (dict["id"] as? Int).map(String.init) ?? "\(language)-\(title)-\(quality)-\(downloadURL.lastPathComponent)"
            let comment = dict["comment"] as? String

            return SubDLSubtitleCandidate(
                id: id,
                language: language,
                quality: quality,
                title: title,
                comment: comment,
                downloadURL: downloadURL
            )
        }

        let deduped = Array(Dictionary(grouping: mapped, by: { $0.downloadURL.absoluteString }).values.compactMap { $0.first })
        await DebugCategory.network.infoLog("Fetched SubDL subtitle candidates", context: ["count": String(deduped.count)])

        if preferred.isEmpty {
            return deduped
        }

        let sorted = deduped.sorted { lhs, rhs in
            let l = languageScore(lhs.language, preferredHints: preferred)
            let r = languageScore(rhs.language, preferredHints: preferred)
            if l != r { return l > r }
            return lhs.title < rhs.title
        }

        return sorted
    }

    private func extractNextDataJSON(from html: String) -> String? {
        guard let scriptStartRange = html.range(of: "<script id=\"__NEXT_DATA__\"", options: .caseInsensitive),
              let contentStartRange = html.range(of: ">", range: scriptStartRange.upperBound..<html.endIndex),
              let scriptEndRange = html.range(of: "</script>", range: contentStartRange.upperBound..<html.endIndex)
        else {
            return nil
        }

        return String(html[contentStartRange.upperBound..<scriptEndRange.lowerBound])
    }

    private func collectSubtitleDictionaries(from node: Any, output: inout [[String: Any]]) {
        if let dict = node as? [String: Any] {
            if dict["language"] != nil,
               dict["quality"] != nil,
               dict["title"] != nil,
               (dict["link"] != nil || dict["bucketLink"] != nil) {
                output.append(dict)
            }

            for value in dict.values {
                collectSubtitleDictionaries(from: value, output: &output)
            }
        } else if let array = node as? [Any] {
            for item in array {
                collectSubtitleDictionaries(from: item, output: &output)
            }
        }
    }

    private func makeDownloadURL(link: String?, bucketLink: String?) -> URL? {
        if let link, !link.isEmpty {
            return URL(string: "https://dl.subdl.com/subtitle/\(link)")
        }

        if let bucketLink, !bucketLink.isEmpty {
            let normalized = bucketLink.replacingOccurrences(of: "/", with: "-")
            return URL(string: "https://dl.subdl.com/subtitle/\(normalized)")
        }

        return nil
    }

    private func normalizedLanguageHints(for preferredLanguageKey: String?) -> [String] {
        guard let key = preferredLanguageKey?.lowercased(), !key.isEmpty else {
            return []
        }

        var hints = [key]
        switch key {
        case "en": hints.append("english")
        case "es": hints.append("spanish")
        case "fr": hints.append("french")
        case "de": hints.append("german")
        case "it": hints.append("italian")
        case "pt": hints.append("portuguese")
        case "pt-br": hints.append("brazillian portuguese")
        case "ja": hints.append("japanese")
        case "ko": hints.append("korean")
        case "zh": hints.append("chinese")
        case "zh-tw": hints.append("traditional chinese")
        case "ru": hints.append("russian")
        case "tr": hints.append("turkish")
        case "ar": hints.append("arabic")
        default: break
        }
        return hints
    }

    private func languageScore(_ language: String, preferredHints: [String]) -> Int {
        let lowered = language.lowercased()
        for hint in preferredHints {
            if lowered == hint { return 3 }
        }
        for hint in preferredHints {
            if lowered.contains(hint) { return 2 }
        }
        return 0
    }
}
