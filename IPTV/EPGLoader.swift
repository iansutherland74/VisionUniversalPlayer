import Foundation

actor EPGLoader {
    enum LoaderError: Error {
        case invalidXML
    }

    func loadPrograms(from url: URL) async throws -> [EPGProgram] {
        await DebugCategory.epg.infoLog("Loading EPG", context: ["url": url.absoluteString])
        let (data, _) = try await URLSession.shared.data(from: url)
        let programs = try parseXMLTV(data: data)
        await DebugCategory.epg.infoLog(
            "Loaded EPG",
            context: ["programs": String(programs.count), "bytes": String(data.count)]
        )
        return programs
    }

    private func parseXMLTV(data: Data) throws -> [EPGProgram] {
        let parserDelegate = XMLTVParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = parserDelegate

        guard parser.parse() else {
            Task {
                await DebugCategory.epg.errorLog("Invalid XMLTV document")
            }
            throw LoaderError.invalidXML
        }

        return parserDelegate.programs
    }
}

private final class XMLTVParserDelegate: NSObject, XMLParserDelegate {
    private(set) var programs: [EPGProgram] = []

    private var currentElement = ""
    private var currentChannel = ""
    private var currentStart: Date?
    private var currentEnd: Date?
    private var currentTitle = ""
    private var currentDesc = ""
    private var textBuffer = ""

    private lazy var dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMddHHmmss Z"
        return f
    }()

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        textBuffer = ""

        if elementName == "programme" {
            currentChannel = attributeDict["channel"] ?? ""
            currentStart = parseDate(attributeDict["start"])
            currentEnd = parseDate(attributeDict["stop"])
            currentTitle = ""
            currentDesc = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        textBuffer += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let trimmed = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)

        if elementName == "title" {
            currentTitle = trimmed
        } else if elementName == "desc" {
            currentDesc = trimmed
        } else if elementName == "programme" {
            guard let start = currentStart, let end = currentEnd else { return }
            let program = EPGProgram(
                channelId: currentChannel,
                title: currentTitle.isEmpty ? "Program" : currentTitle,
                details: currentDesc,
                startDate: start,
                endDate: end
            )
            programs.append(program)
        }

        textBuffer = ""
    }

    private func parseDate(_ source: String?) -> Date? {
        guard let source else { return nil }
        return dateFormatter.date(from: source)
    }
}
