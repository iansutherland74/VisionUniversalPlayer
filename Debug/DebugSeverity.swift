import Foundation

/// Severity level for debug events, used for filtering and visual indication.
enum DebugSeverity: String, CaseIterable, Comparable, Codable {
    case trace
    case info
    case warning
    case error
    case critical
    
    var displayName: String {
        switch self {
        case .trace:
            return "TRACE"
        case .info:
            return "INFO"
        case .warning:
            return "WARNING"
        case .error:
            return "ERROR"
        case .critical:
            return "CRITICAL"
        }
    }
    
    var color: String {
        // ANSI color codes for console output
        switch self {
        case .trace:
            return "\u{001B}[37m"      // White
        case .info:
            return "\u{001B}[36m"      // Cyan
        case .warning:
            return "\u{001B}[33m"      // Yellow
        case .error:
            return "\u{001B}[31m"      // Red
        case .critical:
            return "\u{001B}[35m"      // Magenta
        }
    }
    
    var hexColor: String {
        // Hex color for VS Code UI
        switch self {
        case .trace:
            return "#999999"           // Gray
        case .info:
            return "#00CCCC"           // Cyan
        case .warning:
            return "#FFCC00"           // Yellow
        case .error:
            return "#FF0000"           // Red
        case .critical:
            return "#FF00FF"           // Magenta
        }
    }
    
    static func < (lhs: DebugSeverity, rhs: DebugSeverity) -> Bool {
        let order: [DebugSeverity] = [.trace, .info, .warning, .error, .critical]
        return order.firstIndex(of: lhs) ?? 0 < order.firstIndex(of: rhs) ?? 0
    }
}
