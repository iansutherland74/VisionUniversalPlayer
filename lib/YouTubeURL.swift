import Foundation

enum YouTubeURL {
    static func videoID(from url: URL) -> String? {
        guard let host = url.host()?.lowercased() else { return nil }

        if host == "youtu.be" {
            let id = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return sanitizeVideoID(id)
        }

        let isYouTubeHost = host.contains("youtube.com") || host.contains("youtube-nocookie.com")
        guard isYouTubeHost else { return nil }

        let pathParts = url.path
            .split(separator: "/")
            .map(String.init)

        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let v = components.queryItems?.first(where: { $0.name == "v" })?.value,
           let normalized = sanitizeVideoID(v) {
            return normalized
        }

        if pathParts.count >= 2 {
            let first = pathParts[0].lowercased()
            if ["embed", "shorts", "live", "v"].contains(first) {
                return sanitizeVideoID(pathParts[1])
            }
        }

        return nil
    }

    static func thumbnailURL(from url: URL, quality: Quality = .high) -> URL? {
        guard let videoID = videoID(from: url) else { return nil }
        return URL(string: "https://img.youtube.com/vi/\(videoID)/\(quality.fileName).jpg")
    }

    enum Quality {
        case `default`
        case medium
        case high
        case standard
        case maximum

        var fileName: String {
            switch self {
            case .default:
                return "default"
            case .medium:
                return "mqdefault"
            case .high:
                return "hqdefault"
            case .standard:
                return "sddefault"
            case .maximum:
                return "maxresdefault"
            }
        }
    }

    private static func sanitizeVideoID(_ raw: String) -> String? {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.isEmpty == false else { return nil }
        return cleaned
    }
}
