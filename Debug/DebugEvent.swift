import Foundation

/// Atomic debug event representing a single diagnostic message from any subsystem.
struct DebugEvent: Codable {
    let id: UUID
    let timestamp: Double                    // Unix timestamp
    let category: DebugCategory
    let severity: DebugSeverity
    let message: String
    let thread: String
    let context: [String: String]           // Optional key-value metadata
    
    init(
        category: DebugCategory,
        severity: DebugSeverity,
        message: String,
        context: [String: String] = [:]
    ) {
        self.id = UUID()
        self.timestamp = Date().timeIntervalSince1970
        self.category = category
        self.severity = severity
        self.message = message
        let threadName = Thread.current.name ?? ""
        self.thread = threadName.isEmpty ? "unknown" : threadName
        self.context = context
    }
    
    /// Serialize to JSON string for WebSocket transmission.
    func toJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = []
        
        if let data = try? encoder.encode(self),
           let jsonString = String(data: data, encoding: .utf8) {
            return jsonString
        }
        return "{}"
    }
    
    /// Formatted string for console output.
    var formatted: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"
        let timeString = dateFormatter.string(from: Date(timeIntervalSince1970: timestamp))
        
        let severityColor = severity.color
        let severityString = severity.displayName
        
        return "\(severityColor)[\(timeString)] [\(severityString)] [\(category.displayName)]\u{001B}[0m \(message)"
    }
}
