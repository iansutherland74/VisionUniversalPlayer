import Foundation
import Compression

#if canImport(ZIPFoundation)
import ZIPFoundation
#endif

#if canImport(UnrarKit)
import UnrarKit
#endif

struct SubtitleCue: Equatable, Sendable {
    let start: TimeInterval
    let end: TimeInterval
    let text: String

    func contains(time: TimeInterval) -> Bool {
        time >= start && time <= end
    }
}

struct SubtitleParsedPayload: Sendable {
    let cues: [SubtitleCue]
    let sourceLabel: String
}

enum SubtitleSidecarImportError: LocalizedError {
    case unsupportedEncoding
    case noCuesFound
    case malformedZIPArchive
    case unsupportedZIPCompression(UInt16)
    case unsupportedArchiveFormat(String)
    case archiveExtractionFailed(String)
    case missingArchiveDependency(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedEncoding:
            return "Unsupported subtitle text encoding"
        case .noCuesFound:
            return "No subtitle cues found"
        case .malformedZIPArchive:
            return "Invalid ZIP subtitle archive"
        case .unsupportedZIPCompression(let method):
            return "Unsupported ZIP compression method \(method)"
        case .unsupportedArchiveFormat(let format):
            return "\(format) archives are not supported yet"
        case .archiveExtractionFailed(let format):
            return "Unable to extract \(format) archive"
        case .missingArchiveDependency(let dependency):
            return "Archive support requires linking \(dependency) to the app target"
        }
    }
}

enum SubtitleSidecar {
    private static let supportedSubtitleExtensions: Set<String> = ["srt", "vtt", "ass", "ssa", "sub"]

    static func parse(contents: String) -> [SubtitleCue] {
        let trimmed = contents.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("-->"), trimmed.contains("WEBVTT") {
            return parseVTT(contents: trimmed)
        }
        if trimmed.contains("-->") {
            return parseSRT(contents: trimmed)
        }
        if trimmed.contains("[Script Info]") || trimmed.contains("Dialogue:") {
            return parseASS(contents: trimmed)
        }
        if trimmed.contains("{") && trimmed.contains("}") {
            let micro = parseMicroDVD(contents: trimmed)
            if !micro.isEmpty {
                return micro
            }
        }
        return []
    }

    static func parse(data: Data, sourceURL: URL? = nil) throws -> SubtitleParsedPayload {
        Task {
            DebugCategory.settings.infoLog(
                "Parsing subtitle sidecar",
                context: [
                    "source": sourceURL?.lastPathComponent ?? "in-memory",
                    "bytes": String(data.count)
                ]
            )
        }
        if isRARArchive(data: data, sourceURL: sourceURL) {
            return try parseRARArchive(data: data, sourceURL: sourceURL)
        }

        if isZIPArchive(data: data, sourceURL: sourceURL) {
            return try parseZIPArchive(data: data)
        }

        guard let text = decodeText(from: data) else {
            Task {
                DebugCategory.settings.errorLog("Subtitle sidecar decode failed")
            }
            throw SubtitleSidecarImportError.unsupportedEncoding
        }

        let cues = parse(contents: text)
        guard !cues.isEmpty else {
            Task {
                DebugCategory.settings.warningLog("Subtitle sidecar had no cues")
            }
            throw SubtitleSidecarImportError.noCuesFound
        }

        Task {
            DebugCategory.settings.infoLog(
                "Subtitle sidecar parsed",
                context: ["cues": String(cues.count)]
            )
        }

        return SubtitleParsedPayload(
            cues: cues,
            sourceLabel: sourceURL?.lastPathComponent ?? ""
        )
    }

    static func candidateURLs(for mediaURL: URL) -> [URL] {
        let base = mediaURL.deletingPathExtension()
        return [
            base.appendingPathExtension("vtt"),
            base.appendingPathExtension("srt"),
            base.appendingPathExtension("ass"),
            base.appendingPathExtension("ssa"),
            base.appendingPathExtension("sub"),
            base.appendingPathExtension("zip"),
            base.appendingPathExtension("rar")
        ]
    }

    private struct ZIPEntry {
        let filename: String
        let compressionMethod: UInt16
        let compressedSize: Int
        let uncompressedSize: Int
        let localHeaderOffset: Int
    }

    private static func parseZIPArchive(data: Data) throws -> SubtitleParsedPayload {
#if canImport(ZIPFoundation)
        Task {
            DebugCategory.settings.traceLog("Parsing ZIP subtitle archive")
        }
#endif
#if canImport(ZIPFoundation)
        if let payload = try parseZIPArchiveWithZIPFoundation(data: data) {
            return payload
        }
#endif

        let entries = try zipEntries(in: data)
        var archiveEntries: [(filename: String, data: Data)] = []

        for entry in entries {
            do {
                let entryData = try extractZIPEntry(entry, from: data)
                archiveEntries.append((filename: entry.filename, data: entryData))
            } catch let error as SubtitleSidecarImportError {
                if case .unsupportedZIPCompression = error {
                    continue
                }
            } catch {
                continue
            }
        }

        return try bestParsedPayload(from: archiveEntries, fallbackError: .noCuesFound)
    }

    private static func parseRARArchive(data: Data, sourceURL: URL?) throws -> SubtitleParsedPayload {
#if canImport(UnrarKit)
        Task {
            DebugCategory.settings.traceLog(
                "Parsing RAR subtitle archive",
                context: ["source": sourceURL?.lastPathComponent ?? "in-memory"]
            )
        }
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let archiveURL = rootURL.appendingPathComponent(sourceURL?.lastPathComponent ?? "subtitle.rar")

        defer {
            try? fileManager.removeItem(at: rootURL)
        }

        do {
            try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
            try data.write(to: archiveURL, options: .atomic)

            let archive = try URKArchive(url: archiveURL)
            let fileInfos = try archive.listFileInfo()
            var archiveEntries: [(filename: String, data: Data)] = []
            archiveEntries.reserveCapacity(fileInfos.count)

            for fileInfo in fileInfos {
                let filename = fileInfo.filename
                guard filename.hasSuffix("/") == false else { continue }
                let fileData = try archive.extractData(fromFile: filename)
                archiveEntries.append((filename: filename, data: fileData))
            }

            return try bestParsedPayload(from: archiveEntries, fallbackError: .noCuesFound)
        } catch let error as SubtitleSidecarImportError {
            throw error
        } catch {
            throw SubtitleSidecarImportError.archiveExtractionFailed("RAR")
        }
#else
        throw SubtitleSidecarImportError.missingArchiveDependency("UnrarKit")
#endif
    }

#if canImport(ZIPFoundation)
    private static func parseZIPArchiveWithZIPFoundation(data: Data) throws -> SubtitleParsedPayload? {
        let archive: Archive
        do {
            archive = try Archive(data: data, accessMode: .read)
        } catch {
            return nil
        }

        var archiveEntries: [(filename: String, data: Data)] = []

        for entry in archive {
            guard entry.type == .file else { continue }

            var entryData = Data()
            do {
                _ = try archive.extract(entry, consumer: { chunk in
                    entryData.append(chunk)
                })
                archiveEntries.append((filename: entry.path, data: entryData))
            } catch {
                continue
            }
        }

        return try bestParsedPayload(from: archiveEntries, fallbackError: .noCuesFound)
    }
#endif

    private static func bestParsedPayload(
        from archiveEntries: [(filename: String, data: Data)],
        fallbackError: SubtitleSidecarImportError
    ) throws -> SubtitleParsedPayload {
        var bestMatch: (payload: SubtitleParsedPayload, score: Int)?
        var lastError: SubtitleSidecarImportError?

        for entry in archiveEntries {
            let normalizedName = entry.filename.lowercased()
            guard normalizedName.hasSuffix("/") == false,
                  let fileExtension = normalizedName.split(separator: ".").last.map(String.init),
                  supportedSubtitleExtensions.contains(fileExtension)
            else {
                continue
            }

            guard let text = decodeText(from: entry.data) else {
                lastError = lastError ?? .unsupportedEncoding
                continue
            }

            let cues = parse(contents: text)
            guard !cues.isEmpty else {
                lastError = lastError ?? .noCuesFound
                continue
            }

            let score = (cues.count * 10) + subtitleExtensionPriority(fileExtension)
            let payload = SubtitleParsedPayload(cues: cues, sourceLabel: entry.filename)
            if let bestMatch, bestMatch.score >= score {
                continue
            }
            bestMatch = (payload, score)
        }

        if let bestMatch {
            return bestMatch.payload
        }

        throw lastError ?? fallbackError
    }

    private static func zipEntries(in data: Data) throws -> [ZIPEntry] {
        guard let endOfCentralDirectoryOffset = findEndOfCentralDirectory(in: data) else {
            throw SubtitleSidecarImportError.malformedZIPArchive
        }

        let entryCount = Int(data.readUInt16LE(at: endOfCentralDirectoryOffset + 10))
        let centralDirectoryOffset = Int(data.readUInt32LE(at: endOfCentralDirectoryOffset + 16))
        guard entryCount >= 0,
              centralDirectoryOffset >= 0,
              centralDirectoryOffset < data.count
        else {
            throw SubtitleSidecarImportError.malformedZIPArchive
        }

        var entries: [ZIPEntry] = []
        entries.reserveCapacity(entryCount)

        var cursor = centralDirectoryOffset
        for _ in 0..<entryCount {
            guard cursor + 46 <= data.count,
                  data.readUInt32LE(at: cursor) == 0x02014b50
            else {
                throw SubtitleSidecarImportError.malformedZIPArchive
            }

            let compressionMethod = data.readUInt16LE(at: cursor + 10)
            let compressedSize = Int(data.readUInt32LE(at: cursor + 20))
            let uncompressedSize = Int(data.readUInt32LE(at: cursor + 24))
            let fileNameLength = Int(data.readUInt16LE(at: cursor + 28))
            let extraFieldLength = Int(data.readUInt16LE(at: cursor + 30))
            let fileCommentLength = Int(data.readUInt16LE(at: cursor + 32))
            let localHeaderOffset = Int(data.readUInt32LE(at: cursor + 42))
            let fileNameStart = cursor + 46
            let fileNameEnd = fileNameStart + fileNameLength
            guard fileNameEnd <= data.count else {
                throw SubtitleSidecarImportError.malformedZIPArchive
            }

            let fileNameData = Data(data[fileNameStart..<fileNameEnd])
            let fileName = String(data: fileNameData, encoding: .utf8)
                ?? String(data: fileNameData, encoding: .isoLatin1)
                ?? ""

            entries.append(
                ZIPEntry(
                    filename: fileName,
                    compressionMethod: compressionMethod,
                    compressedSize: compressedSize,
                    uncompressedSize: uncompressedSize,
                    localHeaderOffset: localHeaderOffset
                )
            )

            cursor = fileNameEnd + extraFieldLength + fileCommentLength
        }

        return entries
    }

    private static func extractZIPEntry(_ entry: ZIPEntry, from archiveData: Data) throws -> Data {
        let localHeaderOffset = entry.localHeaderOffset
        guard localHeaderOffset + 30 <= archiveData.count,
              archiveData.readUInt32LE(at: localHeaderOffset) == 0x04034b50
        else {
            throw SubtitleSidecarImportError.malformedZIPArchive
        }

        let fileNameLength = Int(archiveData.readUInt16LE(at: localHeaderOffset + 26))
        let extraFieldLength = Int(archiveData.readUInt16LE(at: localHeaderOffset + 28))
        let payloadStart = localHeaderOffset + 30 + fileNameLength + extraFieldLength
        let payloadEnd = payloadStart + entry.compressedSize
        guard payloadStart >= 0, payloadEnd <= archiveData.count else {
            throw SubtitleSidecarImportError.malformedZIPArchive
        }

        let compressedPayload = Data(archiveData[payloadStart..<payloadEnd])
        switch entry.compressionMethod {
        case 0:
            return compressedPayload
        case 8:
            let inflated = try (compressedPayload as NSData).decompressed(using: .zlib) as Data
            if entry.uncompressedSize > 0, inflated.count != entry.uncompressedSize {
                throw SubtitleSidecarImportError.malformedZIPArchive
            }
            return inflated
        default:
            throw SubtitleSidecarImportError.unsupportedZIPCompression(entry.compressionMethod)
        }
    }

    private static func findEndOfCentralDirectory(in data: Data) -> Int? {
        guard data.count >= 22 else { return nil }

        let minimumOffset = max(0, data.count - 65_557)
        for offset in stride(from: data.count - 22, through: minimumOffset, by: -1) {
            if data.readUInt32LE(at: offset) == 0x06054b50 {
                return offset
            }
        }

        return nil
    }

    private static func subtitleExtensionPriority(_ fileExtension: String) -> Int {
        switch fileExtension {
        case "srt": return 5
        case "vtt": return 4
        case "ass": return 3
        case "ssa": return 2
        case "sub": return 1
        default: return 0
        }
    }

    private static func decodeText(from data: Data) -> String? {
        let encodings: [String.Encoding] = [
            .utf8,
            .utf16,
            .utf16LittleEndian,
            .utf16BigEndian,
            .unicode,
            .windowsCP1252,
            .isoLatin1
        ]

        for encoding in encodings {
            if let decoded = String(data: data, encoding: encoding),
               decoded.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                return decoded
            }
        }

        return nil
    }

    private static func isZIPArchive(data: Data, sourceURL: URL?) -> Bool {
        if sourceURL?.pathExtension.lowercased() == "zip" {
            return true
        }

        guard data.count >= 4 else { return false }
        let signature = data.readUInt32LE(at: 0)
        return signature == 0x04034b50 || signature == 0x06054b50 || signature == 0x08074b50
    }

    private static func isRARArchive(data: Data, sourceURL: URL?) -> Bool {
        if sourceURL?.pathExtension.lowercased() == "rar" {
            return true
        }

        let rar4Signature: [UInt8] = [0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x00]
        let rar5Signature: [UInt8] = [0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x01, 0x00]
        return data.hasPrefix(rar4Signature) || data.hasPrefix(rar5Signature)
    }

    private static func parseSRT(contents: String) -> [SubtitleCue] {
        let normalized = contents
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let blocks = normalized
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var cues: [SubtitleCue] = []
        for block in blocks {
            let lines = block.components(separatedBy: "\n")
            guard lines.count >= 2 else { continue }

            let timingLine: String
            let payloadStartIndex: Int
            if lines[0].contains("-->") {
                timingLine = lines[0]
                payloadStartIndex = 1
            } else if lines.count >= 3, lines[1].contains("-->") {
                timingLine = lines[1]
                payloadStartIndex = 2
            } else {
                continue
            }

            guard let (start, end) = parseTimingLine(timingLine, separator: "-->", usesCommaMs: true) else {
                continue
            }

            let text = lines[payloadStartIndex...]
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }

            cues.append(SubtitleCue(start: start, end: end, text: text))
        }

        return cues.sorted { $0.start < $1.start }
    }

    private static func parseVTT(contents: String) -> [SubtitleCue] {
        let normalized = contents
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let blocks = normalized
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("WEBVTT") }

        var cues: [SubtitleCue] = []
        for block in blocks {
            let lines = block.components(separatedBy: "\n")
            guard lines.count >= 2 else { continue }

            let timingLine: String
            let payloadStartIndex: Int
            if lines[0].contains("-->") {
                timingLine = lines[0]
                payloadStartIndex = 1
            } else if lines.count >= 3, lines[1].contains("-->") {
                timingLine = lines[1]
                payloadStartIndex = 2
            } else {
                continue
            }

            guard let (start, end) = parseTimingLine(timingLine, separator: "-->", usesCommaMs: false) else {
                continue
            }

            let text = lines[payloadStartIndex...]
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }

            cues.append(SubtitleCue(start: start, end: end, text: text))
        }

        return cues.sorted { $0.start < $1.start }
    }

    private static func parseTimingLine(
        _ line: String,
        separator: String,
        usesCommaMs: Bool
    ) -> (TimeInterval, TimeInterval)? {
        let parts = line.components(separatedBy: separator)
        guard parts.count >= 2 else { return nil }

        let left = parts[0].trimmingCharacters(in: .whitespaces)
        let right = parts[1]
            .trimmingCharacters(in: .whitespaces)
            .split(whereSeparator: { $0.isWhitespace })
            .first
            .map(String.init) ?? ""

        guard let start = parseTimestamp(left, usesCommaMs: usesCommaMs),
              let end = parseTimestamp(right, usesCommaMs: usesCommaMs),
              end >= start
        else {
            return nil
        }

        return (start, end)
    }

    private static func parseTimestamp(_ raw: String, usesCommaMs: Bool) -> TimeInterval? {
        let normalized = usesCommaMs
            ? raw.replacingOccurrences(of: ",", with: ".")
            : raw

        let parts = normalized.split(separator: ":")
        guard parts.count == 3 else { return nil }

        let hours = Double(parts[0]) ?? 0
        let minutes = Double(parts[1]) ?? 0
        let secMs = parts[2].split(separator: ".")
        guard let seconds = Double(secMs[0]) else { return nil }

        let millis: Double
        if secMs.count > 1 {
            let msString = String(secMs[1].prefix(3)).padding(toLength: 3, withPad: "0", startingAt: 0)
            millis = (Double(msString) ?? 0) / 1000.0
        } else {
            millis = 0
        }

        return (hours * 3600) + (minutes * 60) + seconds + millis
    }

    private static func parseASS(contents: String) -> [SubtitleCue] {
        let normalized = contents
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        var cues: [SubtitleCue] = []
        let lines = normalized.components(separatedBy: "\n")

        for line in lines {
            guard line.hasPrefix("Dialogue:") else { continue }
            let payload = line.dropFirst("Dialogue:".count).trimmingCharacters(in: .whitespaces)

            let fields = splitASSFields(String(payload), expectedFields: 10)
            guard fields.count >= 10 else { continue }

            let startRaw = fields[1]
            let endRaw = fields[2]
            let textRaw = fields[9]

            guard let start = parseASSTimestamp(startRaw),
                  let end = parseASSTimestamp(endRaw),
                  end >= start
            else {
                continue
            }

            let text = assToPlainText(textRaw)
            guard !text.isEmpty else { continue }
            cues.append(SubtitleCue(start: start, end: end, text: text))
        }

        return cues.sorted { $0.start < $1.start }
    }

    private static func splitASSFields(_ value: String, expectedFields: Int) -> [String] {
        var output: [String] = []
        output.reserveCapacity(expectedFields)

        var current = ""
        var commasSeen = 0

        for character in value {
            if character == ",", commasSeen < expectedFields - 1 {
                output.append(current)
                current = ""
                commasSeen += 1
            } else {
                current.append(character)
            }
        }

        output.append(current)
        return output.map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func parseASSTimestamp(_ raw: String) -> TimeInterval? {
        let parts = raw.trimmingCharacters(in: .whitespaces).split(separator: ":")
        guard parts.count == 3 else { return nil }

        let hours = Double(parts[0]) ?? 0
        let minutes = Double(parts[1]) ?? 0
        let secCs = parts[2].split(separator: ".")
        guard let seconds = Double(secCs[0]) else { return nil }

        let centiseconds: Double
        if secCs.count > 1 {
            let cs = String(secCs[1].prefix(2)).padding(toLength: 2, withPad: "0", startingAt: 0)
            centiseconds = (Double(cs) ?? 0) / 100.0
        } else {
            centiseconds = 0
        }

        return (hours * 3600) + (minutes * 60) + seconds + centiseconds
    }

    private static func assToPlainText(_ input: String) -> String {
        var text = input
            .replacingOccurrences(of: "\\N", with: "\n")
            .replacingOccurrences(of: "\\n", with: "\n")

        // Remove ASS override tags such as {\\an8}.
        while let start = text.firstIndex(of: "{"),
              let end = text[start...].firstIndex(of: "}") {
            text.removeSubrange(start...end)
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseMicroDVD(contents: String) -> [SubtitleCue] {
        let normalized = contents
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let fps: Double = 25
        var cues: [SubtitleCue] = []

        for rawLine in normalized.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.hasPrefix("{"),
                  let firstClose = line.firstIndex(of: "}"),
                  line.count > 2
            else { continue }

            let startFrameRaw = line[line.index(after: line.startIndex)..<firstClose]
            let restAfterFirst = line[line.index(after: firstClose)...]
            guard restAfterFirst.hasPrefix("{"),
                  let secondClose = restAfterFirst.firstIndex(of: "}")
            else { continue }

            let endFrameRaw = restAfterFirst[restAfterFirst.index(after: restAfterFirst.startIndex)..<secondClose]
            let textStart = restAfterFirst.index(after: secondClose)
            guard textStart < restAfterFirst.endIndex else { continue }

            let textRaw = String(restAfterFirst[textStart...])
            let text = textRaw.replacingOccurrences(of: "|", with: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty,
                  let startFrame = Double(startFrameRaw),
                  let endFrame = Double(endFrameRaw),
                  endFrame >= startFrame
            else { continue }

            cues.append(
                SubtitleCue(
                    start: startFrame / fps,
                    end: endFrame / fps,
                    text: text
                )
            )
        }

        return cues.sorted { $0.start < $1.start }
    }
}

private extension Data {
    func readUInt16LE(at offset: Int) -> UInt16 {
        guard offset + 1 < count else { return 0 }
        return UInt16(self[offset]) | (UInt16(self[offset + 1]) << 8)
    }

    func readUInt32LE(at offset: Int) -> UInt32 {
        guard offset + 3 < count else { return 0 }
        return UInt32(self[offset])
            | (UInt32(self[offset + 1]) << 8)
            | (UInt32(self[offset + 2]) << 16)
            | (UInt32(self[offset + 3]) << 24)
    }

    func hasPrefix(_ bytes: [UInt8]) -> Bool {
        guard count >= bytes.count else { return false }
        return bytes.indices.allSatisfy { self[$0] == bytes[$0] }
    }
}
