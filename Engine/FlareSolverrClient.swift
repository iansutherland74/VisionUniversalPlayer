import Foundation

struct SubtitleProviderAccessReport: Identifiable, Hashable {
    let id: String
    let providerName: String
    let endpointLabel: String
    let searchURL: URL
    let directSummary: String
    let directMarkers: [String]
    let flareSolverrSummary: String?
    let canAttemptNativeFetch: Bool
}

enum FlareSolverrClientError: LocalizedError {
    case invalidEndpoint
    case invalidResponse
    case serverError(String)
    case missingSolution

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return "Invalid FlareSolverr endpoint"
        case .invalidResponse:
            return "Unexpected FlareSolverr response"
        case .serverError(let message):
            return message
        case .missingSolution:
            return "FlareSolverr did not return a solved page"
        }
    }
}

struct FlareSolverrFetchResult {
    let statusCode: Int
    let responseHTML: String
    let userAgent: String?
}

final class FlareSolverrClient {
    private struct RequestBody: Encodable {
        let cmd: String
        let url: String
        let maxTimeout: Int
        let session: String?
        let waitInSeconds: Int?
        let returnOnlyCookies: Bool
        let disableMedia: Bool
    }

    private struct ResponseBody: Decodable {
        struct Solution: Decodable {
            let status: Int?
            let response: String?
            let userAgent: String?
        }

        let status: String
        let message: String
        let solution: Solution?
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchHTML(
        url: URL,
        endpoint: URL,
        maxTimeoutMS: Int = 60_000,
        sessionID: String? = nil,
        waitInSeconds: Int? = nil
    ) async throws -> FlareSolverrFetchResult {
        guard endpoint.scheme?.hasPrefix("http") == true else {
            throw FlareSolverrClientError.invalidEndpoint
        }
        await DebugCategory.network.infoLog(
            "FlareSolverr request started",
            context: ["url": url.absoluteString, "endpoint": endpoint.absoluteString]
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = TimeInterval(max(30, maxTimeoutMS / 1000 + 10))
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            RequestBody(
                cmd: "request.get",
                url: url.absoluteString,
                maxTimeout: maxTimeoutMS,
                session: sessionID,
                waitInSeconds: waitInSeconds,
                returnOnlyCookies: false,
                disableMedia: true
            )
        )

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode)
        else {
            await DebugCategory.network.errorLog("FlareSolverr invalid HTTP response")
            throw FlareSolverrClientError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        guard decoded.status.lowercased() == "ok" else {
            let message = decoded.message.isEmpty ? "FlareSolverr request failed" : decoded.message
            await DebugCategory.network.errorLog("FlareSolverr server error", context: ["message": message])
            throw FlareSolverrClientError.serverError(message)
        }

        guard let solution = decoded.solution,
              let responseHTML = solution.response
        else {
            await DebugCategory.network.errorLog("FlareSolverr missing solution")
            throw FlareSolverrClientError.missingSolution
        }

        await DebugCategory.network.infoLog(
            "FlareSolverr request completed",
            context: ["statusCode": String(solution.status ?? 0), "htmlBytes": String(responseHTML.utf8.count)]
        )

        return FlareSolverrFetchResult(
            statusCode: solution.status ?? 0,
            responseHTML: responseHTML,
            userAgent: solution.userAgent
        )
    }
}