import Foundation

@main
struct SubtitleSidecarRegression {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard arguments.count >= 2 else {
            fputs("usage: subtitle-sidecar-regression <plain-srt> <zip-archive> [rar-archive]\n", stderr)
            exit(64)
        }

        let plainURL = URL(fileURLWithPath: arguments[0])
        let zipURL = URL(fileURLWithPath: arguments[1])
        let rarURL = arguments.count > 2 ? URL(fileURLWithPath: arguments[2]) : nil

        try assertPlainImport(at: plainURL)
        try assertZIPImport(at: zipURL)

        if let rarURL {
            try assertRARImport(at: rarURL)
        }

        print("subtitle-sidecar-regression: ok")
    }

    private static func assertPlainImport(at url: URL) throws {
        let payload = try SubtitleSidecar.parse(data: Data(contentsOf: url), sourceURL: url)
        guard payload.cues.count == 2 else {
            throw RegressionError("plain subtitle cue count mismatch: \(payload.cues.count)")
        }
        guard payload.sourceLabel == url.lastPathComponent else {
            throw RegressionError("plain subtitle source label mismatch: \(payload.sourceLabel)")
        }
    }

    private static func assertZIPImport(at url: URL) throws {
        let payload = try SubtitleSidecar.parse(data: Data(contentsOf: url), sourceURL: url)
        guard payload.cues.count == 2 else {
            throw RegressionError("zip subtitle cue count mismatch: \(payload.cues.count)")
        }
        guard payload.sourceLabel.lowercased().hasSuffix("sample.srt") else {
            throw RegressionError("zip subtitle source label mismatch: \(payload.sourceLabel)")
        }
    }

    private static func assertRARImport(at url: URL) throws {
        do {
            let payload = try SubtitleSidecar.parse(data: Data(contentsOf: url), sourceURL: url)
            guard payload.cues.isEmpty == false else {
                throw RegressionError("rar subtitle import returned no cues")
            }
        } catch let error as SubtitleSidecarImportError {
            switch error {
            case .missingArchiveDependency:
                print("subtitle-sidecar-regression: rar skipped (UnrarKit not linked)")
            default:
                throw error
            }
        }
    }
}

private struct RegressionError: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? {
        message
    }
}