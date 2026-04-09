import Foundation

struct HLSBitrateRung: Identifiable, Hashable {
    let size: CGSize
    let averageBitrate: Int
    let peakBitrate: Int
    let url: URL

    var id: String { url.absoluteString }

    var resolutionString: String {
        "\(Int(size.width))x\(Int(size.height))"
    }

    var bitrateString: String {
        let mbps = Double(max(averageBitrate, peakBitrate)) / 1_000_000.0
        return String(format: "%.1f Mbps", mbps)
    }
}

struct HLSAudioOption: Identifiable, Hashable {
    let url: URL
    let groupId: String
    let name: String
    let language: String

    var id: String { url.absoluteString }

    var description: String {
        if !name.isEmpty { return name }
        if !language.isEmpty { return language.uppercased() }
        return groupId
    }
}

actor HLSManifestReader {
    enum ReaderError: Error {
        case invalidPlaylistEncoding
    }

    struct Result {
        let bitrateRungs: [HLSBitrateRung]
        let audioOptions: [HLSAudioOption]
        let rawText: String
    }

    func parseMasterPlaylist(url: URL) async throws -> Result {
        await DebugCategory.hls.infoLog("Parsing HLS master playlist", context: ["url": url.absoluteString])
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let text = String(data: data, encoding: .utf8) else {
            await DebugCategory.hls.errorLog("Invalid HLS playlist encoding", context: ["url": url.absoluteString])
            throw ReaderError.invalidPlaylistEncoding
        }

        let rungs = parseBitrateLadder(from: text, baseURL: url)
        let audioOptions = parseAudioOptions(from: text, baseURL: url)

        let result = Result(
            bitrateRungs: rungs.sorted { lhs, rhs in
                max(lhs.averageBitrate, lhs.peakBitrate) < max(rhs.averageBitrate, rhs.peakBitrate)
            },
            audioOptions: audioOptions.sorted { lhs, rhs in
                lhs.description.localizedCaseInsensitiveCompare(rhs.description) == .orderedAscending
            },
            rawText: text
        )
        await DebugCategory.hls.infoLog(
            "Parsed HLS master playlist",
            context: [
                "rungs": String(result.bitrateRungs.count),
                "audioOptions": String(result.audioOptions.count)
            ]
        )
        return result
    }

    private func parseBitrateLadder(from text: String, baseURL: URL) -> [HLSBitrateRung] {
        var bitrateRungs: [HLSBitrateRung] = []

        let lines = text.components(separatedBy: .newlines)
        for index in lines.indices {
            let line = lines[index]
            guard line.contains("#EXT-X-STREAM-INF:") else { continue }
            guard index + 1 < lines.count else { continue }

            let nextLine = lines[index + 1].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !nextLine.isEmpty, !nextLine.hasPrefix("#") else { continue }

            let resolution = parseResolution(line) ?? CGSize(width: 0, height: 0)
            let averageBitrate = parseInteger(after: "AVERAGE-BANDWIDTH=", in: line) ?? 0
            let peakBitrate = parseInteger(after: "BANDWIDTH=", in: line) ?? 0

            guard averageBitrate > 0 || peakBitrate > 0 else { continue }
            guard let variantURL = URL(string: nextLine, relativeTo: baseURL)?.absoluteURL else { continue }

            bitrateRungs.append(
                HLSBitrateRung(
                    size: resolution,
                    averageBitrate: averageBitrate,
                    peakBitrate: peakBitrate,
                    url: variantURL
                )
            )
        }

        return bitrateRungs
    }

    private func parseAudioOptions(from text: String, baseURL: URL) -> [HLSAudioOption] {
        var options: [HLSAudioOption] = []
        let lines = text.components(separatedBy: .newlines)

        for line in lines {
            guard line.contains("#EXT-X-MEDIA:"), line.contains("TYPE=AUDIO") else { continue }

            let groupId = parseQuoted(after: "GROUP-ID=", in: line) ?? ""
            let name = parseQuoted(after: "NAME=", in: line) ?? ""
            let language = parseQuoted(after: "LANGUAGE=", in: line) ?? ""
            guard let uri = parseQuoted(after: "URI=", in: line) else { continue }
            guard let optionURL = URL(string: uri, relativeTo: baseURL)?.absoluteURL else { continue }

            options.append(
                HLSAudioOption(url: optionURL, groupId: groupId, name: name, language: language)
            )
        }

        return options
    }

    private func parseResolution(_ line: String) -> CGSize? {
        guard let token = tokenValue(after: "RESOLUTION=", in: line) else { return nil }
        let parts = token.split(separator: "x")
        guard parts.count == 2,
              let width = Double(parts[0]),
              let height = Double(parts[1])
        else {
            return nil
        }
        return CGSize(width: width, height: height)
    }

    private func parseInteger(after key: String, in line: String) -> Int? {
        guard let token = tokenValue(after: key, in: line) else { return nil }
        return Int(token)
    }

    private func parseQuoted(after key: String, in line: String) -> String? {
        guard let range = line.range(of: key) else { return nil }
        let tail = line[range.upperBound...]
        guard let firstQuote = tail.firstIndex(of: "\"") else { return nil }
        let afterFirst = tail[tail.index(after: firstQuote)...]
        guard let secondQuote = afterFirst.firstIndex(of: "\"") else { return nil }
        return String(afterFirst[..<secondQuote])
    }

    private func tokenValue(after key: String, in line: String) -> String? {
        guard let range = line.range(of: key) else { return nil }
        let tail = line[range.upperBound...]
        let token = tail.prefix { $0 != "," }
        return token.isEmpty ? nil : String(token)
    }
}
