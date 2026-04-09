import Foundation

actor IPTVPlaylistLoader {
    enum LoaderError: Error, LocalizedError {
        case invalidData
        case unsupportedScheme
        case emptyPlaylist

        var errorDescription: String? {
            switch self {
            case .invalidData:
                return "The playlist could not be parsed as text."
            case .unsupportedScheme:
                return "Playlist URL must be HTTP, HTTPS, FTP, or WebDAV-compatible HTTP(S)."
            case .emptyPlaylist:
                return "No channels were found in this playlist."
            }
        }
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func load(from url: URL, title: String? = nil, userAgent: String? = nil) async throws -> IPTVPlaylist {
        guard let scheme = url.scheme?.lowercased(), ["http", "https", "ftp"].contains(scheme) else {
            Task {
                await DebugCategory.iptv.errorLog(
                    "Unsupported playlist scheme",
                    context: ["url": url.absoluteString, "scheme": url.scheme ?? "nil"]
                )
            }
            throw LoaderError.unsupportedScheme
        }

        Task {
            await DebugCategory.playlist.infoLog(
                "Loading IPTV playlist",
                context: ["url": url.absoluteString]
            )
        }

        var request = URLRequest(url: url)
        if let userAgent, userAgent.isEmpty == false {
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }

        let (data, _) = try await session.data(for: request)
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            Task {
                await DebugCategory.playlist.errorLog(
                    "Playlist text decode failed",
                    context: ["url": url.absoluteString, "bytes": String(data.count)]
                )
            }
            throw LoaderError.invalidData
        }

        let channels = parseM3U(text)
        guard channels.isEmpty == false else {
            Task {
                await DebugCategory.playlist.warningLog(
                    "Playlist contained no channels",
                    context: ["url": url.absoluteString]
                )
            }
            throw LoaderError.emptyPlaylist
        }

        Task {
            await DebugCategory.playlist.infoLog(
                "Loaded IPTV playlist",
                context: [
                    "title": title ?? inferredPlaylistTitle(from: url),
                    "channels": String(channels.count)
                ]
            )
        }

        return IPTVPlaylist(
            title: title ?? inferredPlaylistTitle(from: url),
            sourceURL: url,
            channels: channels
        )
    }

    func load(
        fromContent content: String,
        title: String = "Pasted Playlist",
        sourceURL: URL = URL(string: "memory://pasted-playlist.m3u8")!
    ) throws -> IPTVPlaylist {
        let channels = parseM3U(content)
        guard channels.isEmpty == false else {
            Task {
                await DebugCategory.playlist.warningLog(
                    "Pasted playlist contained no channels",
                    context: ["title": title]
                )
            }
            throw LoaderError.emptyPlaylist
        }

        Task {
            await DebugCategory.playlist.infoLog(
                "Loaded pasted playlist",
                context: ["title": title, "channels": String(channels.count)]
            )
        }

        return IPTVPlaylist(
            title: title,
            sourceURL: sourceURL,
            channels: channels
        )
    }

    private func inferredPlaylistTitle(from url: URL) -> String {
        let name = url.deletingPathExtension().lastPathComponent
        return name.isEmpty ? "IPTV Playlist" : name
    }

    private func parseM3U(_ content: String) -> [IPTVChannel] {
        let lines = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")

        var channels: [IPTVChannel] = []
        var pendingInfo: [String: String] = [:]
        var pendingName = "Unknown Channel"

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.isEmpty == false else { continue }

            if line.hasPrefix("#EXTINF:") {
                let (attributes, displayName) = parseExtInf(line)
                pendingInfo = attributes
                pendingName = displayName
                continue
            }

            if line.hasPrefix("#") {
                continue
            }

            guard let streamURL = URL(string: line) else {
                continue
            }

            let group = pendingInfo["group-title"] ?? "Ungrouped"
            let logoURL = pendingInfo["tvg-logo"].flatMap(URL.init(string:))
            let catchupSource = pendingInfo["catchup-source"]
            let archiveDays = parseArchiveDays(info: pendingInfo)
            let hasArchive = inferHasArchive(info: pendingInfo, archiveDays: archiveDays)
            let rawChannelName = pendingInfo["tvg-name"] ?? pendingName
            let normalizedChannelName = IPTVTitleNormalizer.normalize(rawChannelName)
            let effectiveLogoURL = logoURL ?? YouTubeURL.thumbnailURL(from: streamURL)

            let channel = IPTVChannel(
                id: pendingInfo["tvg-id"] ?? UUID().uuidString,
                name: normalizedChannelName,
                streamURL: streamURL,
                logoURL: effectiveLogoURL,
                groupTitle: group,
                tvgID: pendingInfo["tvg-id"],
                tvgName: pendingInfo["tvg-name"],
                tvgShift: pendingInfo["tvg-shift"],
                countryCode: pendingInfo["tvg-country"],
                languageCode: pendingInfo["tvg-language"],
                hasArchive: hasArchive,
                archiveDays: archiveDays,
                catchupSource: catchupSource,
                isXtream: false
            )
            channels.append(channel)

            pendingInfo = [:]
            pendingName = "Unknown Channel"
        }

        return channels
    }

    private func parseExtInf(_ line: String) -> ([String: String], String) {
        let extinf = line.replacingOccurrences(of: "#EXTINF:", with: "")
        let split = extinf.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
        let attrPart = split.first.map(String.init) ?? ""
        let displayName = split.count > 1 ? String(split[1]).trimmingCharacters(in: .whitespacesAndNewlines) : "Unknown Channel"

        var attributes: [String: String] = [:]

        let pattern = "([a-zA-Z0-9\\-]+)=\"([^\"]*)\""
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(attrPart.startIndex..<attrPart.endIndex, in: attrPart)
        regex?.enumerateMatches(in: attrPart, options: [], range: range) { match, _, _ in
            guard
                let match,
                let keyRange = Range(match.range(at: 1), in: attrPart),
                let valueRange = Range(match.range(at: 2), in: attrPart)
            else {
                return
            }
            attributes[String(attrPart[keyRange])] = String(attrPart[valueRange])
        }

        return (attributes, displayName)
    }

    private func parseArchiveDays(info: [String: String]) -> Int? {
        if let rawCatchupDays = info["catchup-days"], let days = Int(rawCatchupDays), days > 0 {
            return days
        }

        if let rawTVGRec = info["tvg-rec"], let days = Int(rawTVGRec), days > 0 {
            return days
        }

        return nil
    }

    private func inferHasArchive(info: [String: String], archiveDays: Int?) -> Bool {
        if let archiveDays, archiveDays > 0 {
            return true
        }

        if let catchupSource = info["catchup-source"], catchupSource.isEmpty == false {
            return true
        }

        if let rawCatchup = info["catchup"] {
            let value = rawCatchup.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if value.isEmpty == false, value != "0", value != "false", value != "none", value != "off" {
                return true
            }
        }

        return false
    }
}
