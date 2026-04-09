import Foundation

enum IPTVTitleNormalizer {
    // Mirrors Streamity's title cleanup approach for noisy IPTV labels.
    static func normalize(_ raw: String) -> String {
        let strippedCarriageReturns = raw.replacingOccurrences(of: "\r", with: "")

        let cleanupPattern = #"(-\s*\d{2,4})|vod|fhd|hd|360p|4k|h264|h265|24fps|60fps|720p|1080p|x264|x265|\.avi|\.mp4|\.mkv|\[[^\]]*\]|\([^\)]*\)|\{[^\}]*\}|-|_|\."#
        let withoutNoise = strippedCarriageReturns.replacingRegexMatches(
            pattern: cleanupPattern,
            with: " ",
            options: [.caseInsensitive]
        )

        let withoutTrailingYearDash = withoutNoise.replacingRegexMatches(
            pattern: #"-\s\d{4}$"#,
            with: "",
            options: [.caseInsensitive]
        )

        let collapsedWhitespace = withoutTrailingYearDash.replacingRegexMatches(
            pattern: #"\s+"#,
            with: " "
        )

        let normalized = collapsedWhitespace.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? raw.trimmingCharacters(in: .whitespacesAndNewlines) : normalized
    }
}

private extension String {
    func replacingRegexMatches(
        pattern: String,
        with replacement: String,
        options: NSRegularExpression.Options = []
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return self
        }

        let range = NSRange(startIndex..<endIndex, in: self)
        return regex.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: replacement)
    }
}
