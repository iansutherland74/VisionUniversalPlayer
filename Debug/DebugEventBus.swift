import Foundation
import Combine

/// Global singleton event bus for all debug diagnostics.
/// All subsystems must emit events through this bus; direct console logging is prohibited.
@MainActor
final class DebugEventBus: ObservableObject {
    static let shared = DebugEventBus()
    
    @Published private(set) var events: [DebugEvent] = []
    let eventPublisher = PassthroughSubject<DebugEvent, Never>()
    
    private let maxEvents = 10000  // Ring buffer max
    
    private var observers: [DebugObserver] = []
    
    #if DEBUG
    private let consoleLogger = DebugConsoleLogger()
    #endif
    
    private init() {
        #if DEBUG
        observers.append(consoleLogger)
        #endif
    }
    
    /// Post a debug event through the bus.
    /// Thread-safe, non-blocking.
    func post(_ event: DebugEvent) {
        // Add to event log
        events.append(event)
        
        // Ring buffer: keep last N events
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }
        
        // Publish to Combine subscribers
        eventPublisher.send(event)
        
        // Notify all observers
        for observer in observers {
            observer.onDebugEvent(event)
        }
    }
    
    /// Convenience method to post with category, severity, and message.
    func post(
        category: DebugCategory,
        severity: DebugSeverity,
        message: String,
        context: [String: String] = [:]
    ) {
        let event = DebugEvent(
            category: category,
            severity: severity,
            message: message,
            context: context
        )
        post(event)
    }
    
    /// Register an observer to receive all debug events.
    func addObserver(_ observer: DebugObserver) {
        observers.append(observer)
    }
    
    /// Unregister an observer.
    func removeObserver(_ observer: DebugObserver) {
        observers.removeAll { $0 === observer }
    }
    
    /// Clear all recorded events.
    @MainActor
    func clearEvents() {
        events.removeAll()
    }
    
    /// Export events as JSON lines (one JSON per line).
    @MainActor
    func exportAsNDJSON() -> String {
        events.map { $0.toJSON() }.joined(separator: "\n")
    }
}

// MARK: - Debug Observer Protocol

/// Protocol for objects that want to observe all debug events.
protocol DebugObserver: AnyObject {
    func onDebugEvent(_ event: DebugEvent)
}

// MARK: - Console Logger (DEBUG builds only)

#if DEBUG
final class DebugConsoleLogger: DebugObserver {
    func onDebugEvent(_ event: DebugEvent) {
        print(event.formatted)
    }
}
#endif

// MARK: - Convenience Extensions

extension DebugCategory {
    /// Post a trace-level event to the debug bus.
    func traceLog(_ message: String, context: [String: String] = [:]) {
        Task {
            await DebugEventBus.shared.post(category: self, severity: .trace, message: message, context: context)
        }
    }
    
    /// Post an info-level event to the debug bus.
    func infoLog(_ message: String, context: [String: String] = [:]) {
        Task {
            await DebugEventBus.shared.post(category: self, severity: .info, message: message, context: context)
        }
    }
    
    /// Post a warning-level event to the debug bus.
    func warningLog(_ message: String, context: [String: String] = [:]) {
        Task {
            await DebugEventBus.shared.post(category: self, severity: .warning, message: message, context: context)
        }
    }
    
    /// Post an error-level event to the debug bus.
    func errorLog(_ message: String, context: [String: String] = [:]) {
        Task {
            await DebugEventBus.shared.post(category: self, severity: .error, message: message, context: context)
        }
    }
    
    /// Post a critical-level event to the debug bus.
    func criticalLog(_ message: String, context: [String: String] = [:]) {
        Task {
            await DebugEventBus.shared.post(category: self, severity: .critical, message: message, context: context)
        }
    }
}
